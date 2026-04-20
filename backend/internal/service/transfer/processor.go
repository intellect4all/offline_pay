package transfer

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strconv"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/nats-io/nats.go"
	"github.com/prometheus/client_golang/prometheus"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/logging"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
	"github.com/intellect/offlinepay/internal/repository/transferrepo"
	"github.com/intellect/offlinepay/internal/service/notification"
)

// StreamName is the JetStream stream the dispatcher publishes to and the
// processor reads from. Created idempotently by EnsureStream below.
const StreamName = "PAYMENTS"

// Processor consumes outbox envelopes from JetStream, mutates the ledger
// atomically, and records processed_events so redeliveries become no-ops.
//
// NotifyConcurrency bounds in-flight notification goroutines (default 32).
// Run drains them before returning.
type Processor struct {
	Pool    *pgxpool.Pool
	Repo    *transferrepo.Repo
	JS      nats.JetStreamContext
	Subject string
	Durable string
	Logger  *slog.Logger

	ProcessedTotal *prometheus.CounterVec // terminal SETTLED/FAILED count; nil-safe
	Notifier       notification.Sender    // optional; nil disables notifications

	NotifyConcurrency int

	notifyOnce sync.Once
	notifySem  chan struct{}
	notifyWG   sync.WaitGroup
}

// recordOutcome increments the processed counter if wired. Safe to call with a
// nil receiver field.
func (p *Processor) recordOutcome(status string) {
	if p.ProcessedTotal == nil {
		return
	}
	p.ProcessedTotal.WithLabelValues(status).Inc()
}

// EnsureStream creates or updates the PAYMENTS JetStream stream (File storage,
// WorkQueue retention). Safe to call at every worker boot.
func EnsureStream(js nats.JetStreamContext) error {
	cfg := &nats.StreamConfig{
		Name:      StreamName,
		Subjects:  []string{"payments.>"},
		Storage:   nats.FileStorage,
		Retention: nats.WorkQueuePolicy,
		Discard:   nats.DiscardOld,
		MaxAge:    7 * 24 * time.Hour,
	}
	if _, err := js.StreamInfo(StreamName); err != nil {
		if errors.Is(err, nats.ErrStreamNotFound) {
			_, err := js.AddStream(cfg)
			return err
		}
		return err
	}
	_, err := js.UpdateStream(cfg)
	return err
}

func (p *Processor) subject() string {
	if p.Subject == "" {
		return "payments.transfer.v1"
	}
	return p.Subject
}

func (p *Processor) durable() string {
	if p.Durable == "" {
		return "payments-transfer-processor"
	}
	return p.Durable
}

// repo returns the Repo the processor should use. Falls back to
// constructing one from Pool when Repo isn't wired — keeps existing
// tests that only set Pool working.
func (p *Processor) repo() *transferrepo.Repo {
	if p.Repo != nil {
		return p.Repo
	}
	p.Repo = transferrepo.New(p.Pool, cache.Noop{})
	return p.Repo
}

// Run blocks until ctx is cancelled.
func (p *Processor) Run(ctx context.Context) error {
	log := logging.Or(p.Logger)
	sub, err := p.JS.PullSubscribe(p.subject(), p.durable(),
		nats.BindStream(StreamName),
		nats.ManualAck(),
		nats.AckWait(30*time.Second),
	)
	if err != nil {
		return fmt.Errorf("pull subscribe: %w", err)
	}
	defer func() { _ = sub.Unsubscribe() }()
	defer p.notifyWG.Wait()

	for {
		if err := ctx.Err(); err != nil {
			return nil
		}
		msgs, err := sub.Fetch(16, nats.MaxWait(2*time.Second))
		if err != nil {
			if errors.Is(err, nats.ErrTimeout) || errors.Is(err, context.DeadlineExceeded) {
				continue
			}
			if errors.Is(err, context.Canceled) || errors.Is(err, nats.ErrConnectionClosed) {
				return nil
			}
			log.Warn("fetch", "err", err)
			time.Sleep(500 * time.Millisecond)
			continue
		}
		for _, m := range msgs {
			if err := p.process(ctx, m); err != nil {
				log.Error("process failed; naking for redelivery", "err", err)
				_ = m.NakWithDelay(5 * time.Second)
				continue
			}
			_ = m.Ack()
		}
	}
}

func (p *Processor) process(ctx context.Context, m *nats.Msg) error {
	var env domain.OutboxEnvelope
	if err := json.Unmarshal(m.Data, &env); err != nil {
		// Malformed: don't redeliver forever. Terminate.
		_ = m.Term()
		return nil
	}

	repo := p.repo()

	// Idempotency check against processed_events. A re-delivery after a
	// successful commit-but-before-ack crash lands here and we skip.
	already, err := repo.IsEventProcessed(ctx, env.ID)
	if err != nil {
		return err
	}
	if already {
		return nil
	}

	if env.Aggregate != "transfer" {
		// Unknown aggregate — mark processed so we don't loop forever.
		return repo.MarkEventProcessedSkipped(ctx, env.ID)
	}

	var tp domain.TransferPayload
	if err := json.Unmarshal(env.Payload, &tp); err != nil {
		if e := repo.MarkEventProcessedFailed(ctx, env.ID); e != nil {
			return e
		}
		_ = repo.MarkTransferFailedOutOfTx(ctx, tp.TransferID, "malformed payload")
		p.recordOutcome("FAILED")
		return nil
	}

	var outcome string
	err = repo.WithProcessTx(ctx, func(q transferrepo.ProcessQueries) error {
		// Deterministic lock order to avoid deadlocks: alphabetical by user_id.
		uidA, uidB := tp.SenderUserID, tp.ReceiverUserID
		if uidA > uidB {
			uidA, uidB = uidB, uidA
		}
		accs := map[string]string{}
		for _, uid := range []string{uidA, uidB} {
			accID, err := q.LockMainAccount(ctx, uid)
			if err != nil {
				if errors.Is(err, pgx.ErrNoRows) {
					if ferr := finalizeFailed(ctx, q, env.ID, tp.TransferID, tp.AmountKobo, "account not provisioned"); ferr != nil {
						return ferr
					}
					outcome = "FAILED"
					return nil
				}
				return err
			}
			accs[uid] = accID
		}

		senderID := accs[tp.SenderUserID]
		receiverID := accs[tp.ReceiverUserID]

		if err := q.DecrementBalanceGuarded(ctx, senderID, tp.AmountKobo); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				if ferr := finalizeFailed(ctx, q, env.ID, tp.TransferID, tp.AmountKobo, "insufficient funds"); ferr != nil {
					return ferr
				}
				outcome = "FAILED"
				return nil
			}
			return err
		}
		if err := q.IncrementBalance(ctx, receiverID, tp.AmountKobo); err != nil {
			return err
		}
		if err := q.MarkTransferSettled(ctx, tp.TransferID); err != nil {
			return err
		}
		settled := tp.AmountKobo
		if err := q.FinalizeTransactionsForTransfer(ctx, tp.TransferID, sqlcgen.TransactionLifecycleStatusCOMPLETED, &settled, nil); err != nil {
			return err
		}
		if err := q.MarkEventSettled(ctx, env.ID); err != nil {
			return err
		}
		outcome = "SETTLED"
		return nil
	})
	if err != nil {
		return err
	}
	if outcome != "" {
		p.recordOutcome(outcome)
		p.emitNotifications(ctx, outcome, tp)
	}
	return nil
}

// defaultNotifyConcurrency caps in-flight notification goroutines. Tuned
// for a soft upper bound rather than throughput — each send is expected
// to be a short HTTP or log write.
const defaultNotifyConcurrency = 32

// notifySlot lazily sizes the semaphore on first emit. Not thread-safe
// against concurrent callers before Run starts, but all emits happen from
// a single fetcher goroutine inside Run.
func (p *Processor) notifySlot() chan struct{} {
	p.notifyOnce.Do(func() {
		n := p.NotifyConcurrency
		if n <= 0 {
			n = defaultNotifyConcurrency
		}
		p.notifySem = make(chan struct{}, n)
	})
	return p.notifySem
}

func (p *Processor) emitNotifications(ctx context.Context, outcome string, tp domain.TransferPayload) {
	if p.Notifier == nil {
		return
	}
	log := logging.Or(p.Logger)

	amountNaira := strconv.FormatFloat(float64(tp.AmountKobo)/100, 'f', 2, 64)
	meta := map[string]string{
		"transfer_id":  tp.TransferID,
		"amount_kobo":  strconv.FormatInt(tp.AmountKobo, 10),
		"amount_naira": amountNaira,
	}

	// Detach from ctx so cancellation doesn't kill an in-flight send.
	// Shutdown is coordinated via notifyWG + notifySem instead.
	sem := p.notifySlot()
	select {
	case sem <- struct{}{}:
	case <-ctx.Done():
		log.Warn("notification dropped; shutting down", "outcome", outcome, "transfer_id", tp.TransferID)
		return
	}

	p.notifyWG.Go(func() {
		defer func() { <-sem }()

		sendCtx := context.WithoutCancel(ctx)
		send := func(e notification.Event) {
			if err := p.Notifier.Send(sendCtx, e); err != nil {
				log.Warn("notification send failed", "type", e.Type, "user_id", e.UserID, "err", err)
			}
		}

		switch outcome {
		case "SETTLED":
			send(notification.Event{
				UserID:   tp.SenderUserID,
				Type:     "transfer_settled",
				Title:    "Transfer successful",
				Body:     fmt.Sprintf("You sent \u20a6%s to account %s.", amountNaira, tp.ReceiverAccountNumber),
				Metadata: meta,
			})
			send(notification.Event{
				UserID:   tp.ReceiverUserID,
				Type:     "transfer_received",
				Title:    "Money received",
				Body:     fmt.Sprintf("You received \u20a6%s from a transfer.", amountNaira),
				Metadata: meta,
			})
		case "FAILED":
			send(notification.Event{
				UserID:   tp.SenderUserID,
				Type:     "transfer_failed",
				Title:    "Transfer failed",
				Body:     fmt.Sprintf("Your transfer of \u20a6%s could not be completed.", amountNaira),
				Metadata: meta,
			})
		}
	})
}

// finalizeFailed records a terminal failure for the transfer, flips
// both paired transactions rows to FAILED with the same reason, and
// marks the event processed so redelivery won't loop. Called inside
// the tx.
func finalizeFailed(ctx context.Context, q transferrepo.ProcessQueries, outboxID, transferID string, amountKobo int64, reason string) error {
	if err := q.MarkTransferFailed(ctx, transferID, reason); err != nil {
		return err
	}
	r := reason
	if err := q.FinalizeTransactionsForTransfer(ctx, transferID, sqlcgen.TransactionLifecycleStatusFAILED, nil, &r); err != nil {
		return err
	}
	return q.MarkEventFailed(ctx, outboxID)
}
