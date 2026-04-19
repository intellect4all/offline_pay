package settlement

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strconv"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/nats-io/nats.go"
	"github.com/prometheus/client_golang/prometheus"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/logging"
	"github.com/intellect/offlinepay/internal/repository/transferrepo"
	"github.com/intellect/offlinepay/internal/service/notification"
)

// FinalizeProcessor consumes payments.settlement.v1 events from JetStream
// and drives Phase 4b (lien_holding → receiver.receiving_available) for
// the named payer by delegating to [Service.FinalizeForPayer].
//
// Idempotency is layered:
//  1. Pool-scoped processed_events check short-circuits redeliveries.
//  2. FinalizeForPayer itself is a no-op on payers with no PENDING rows
//     (a commit-before-ack crash replays safely).
//
// Notifications fan out after the finalize tx commits. Concurrency is
// bounded by NotifyConcurrency so a backlog of events can't starve the
// rest of the worker.
type FinalizeProcessor struct {
	Pool *pgxpool.Pool
	// Events tracks processed_events idempotency. The table is aggregate-
	// neutral so the transfer repo's methods are reusable; keeping the
	// dependency through an interface lets tests swap it.
	Events EventTracker
	// Service is the finalize engine; in production it's a *settlement.Service.
	Service FinalizerService
	JS      nats.JetStreamContext
	Subject string
	Durable string
	Logger  *slog.Logger

	ProcessedTotal *prometheus.CounterVec // labelled by outcome (settled/failed/skipped)
	Notifier       notification.Sender    // optional; nil disables pushes

	NotifyConcurrency int

	notifyOnce sync.Once
	notifySem  chan struct{}
	notifyWG   sync.WaitGroup
}

// EventTracker is the subset of transferrepo.Repo the processor needs for
// idempotency marking. Pulled out so tests can substitute a fake without
// standing up the full transfer repo.
type EventTracker interface {
	IsEventProcessed(ctx context.Context, outboxID string) (bool, error)
	MarkEventProcessedSkipped(ctx context.Context, outboxID string) error
	MarkEventProcessedFailed(ctx context.Context, outboxID string) error
	MarkEventProcessedOK(ctx context.Context, outboxID string) error
}

// FinalizerService is what the processor needs from settlement.Service —
// just the Phase 4b driver. Tests pass a recording fake.
type FinalizerService interface {
	FinalizeForPayer(ctx context.Context, payerUserID string) ([]domain.SettlementResult, error)
}

func (p *FinalizeProcessor) subject() string {
	if p.Subject == "" {
		return domain.OutboxSubjectSettlementFinalize
	}
	return p.Subject
}

func (p *FinalizeProcessor) durable() string {
	if p.Durable == "" {
		return "payments-settlement-finalize"
	}
	return p.Durable
}

func (p *FinalizeProcessor) events() EventTracker {
	if p.Events != nil {
		return p.Events
	}
	// Fallback for production wiring — borrow the transfer repo's
	// aggregate-neutral processed_events surface.
	p.Events = &transferRepoEventTracker{r: transferrepo.New(p.Pool, cache.Noop{})}
	return p.Events
}

// transferRepoEventTracker adapts *transferrepo.Repo to EventTracker. The
// method names on the repo are transfer-flavoured but the underlying SQL
// is aggregate-neutral.
type transferRepoEventTracker struct{ r *transferrepo.Repo }

func (t *transferRepoEventTracker) IsEventProcessed(ctx context.Context, id string) (bool, error) {
	return t.r.IsEventProcessed(ctx, id)
}
func (t *transferRepoEventTracker) MarkEventProcessedSkipped(ctx context.Context, id string) error {
	return t.r.MarkEventProcessedSkipped(ctx, id)
}
func (t *transferRepoEventTracker) MarkEventProcessedFailed(ctx context.Context, id string) error {
	return t.r.MarkEventProcessedFailed(ctx, id)
}
func (t *transferRepoEventTracker) MarkEventProcessedOK(ctx context.Context, id string) error {
	return t.r.MarkEventProcessedOK(ctx, id)
}

// Run blocks until ctx is cancelled.
func (p *FinalizeProcessor) Run(ctx context.Context) error {
	log := logging.Or(p.Logger)
	sub, err := p.JS.PullSubscribe(p.subject(), p.durable(),
		nats.BindStream("PAYMENTS"),
		nats.ManualAck(),
		nats.AckWait(30*time.Second),
	)
	if err != nil {
		return fmt.Errorf("pull subscribe %s: %w", p.subject(), err)
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
			log.Warn("settlement fetch", "err", err)
			time.Sleep(500 * time.Millisecond)
			continue
		}
		for _, m := range msgs {
			if err := p.process(ctx, m); err != nil {
				log.Error("settlement process failed; naking for redelivery", "err", err)
				_ = m.NakWithDelay(5 * time.Second)
				continue
			}
			_ = m.Ack()
		}
	}
}

func (p *FinalizeProcessor) process(ctx context.Context, m *nats.Msg) error {
	var env domain.OutboxEnvelope
	if err := json.Unmarshal(m.Data, &env); err != nil {
		// Malformed envelope: never redeliver.
		_ = m.Term()
		return nil
	}

	ev := p.events()
	already, err := ev.IsEventProcessed(ctx, env.ID)
	if err != nil {
		return err
	}
	if already {
		return nil
	}

	if env.Aggregate != domain.OutboxAggregateSettlementFinalize {
		// Unknown aggregate — mark SKIPPED so we don't loop forever. The
		// transfer processor owns `transfer` events.
		p.recordOutcome("skipped")
		return ev.MarkEventProcessedSkipped(ctx, env.ID)
	}

	var fp domain.FinalizePayerPayload
	if err := json.Unmarshal(env.Payload, &fp); err != nil {
		p.recordOutcome("failed")
		if e := ev.MarkEventProcessedFailed(ctx, env.ID); e != nil {
			return e
		}
		return nil
	}
	if fp.PayerUserID == "" {
		p.recordOutcome("failed")
		return ev.MarkEventProcessedFailed(ctx, env.ID)
	}

	// FinalizeForPayer runs its own tx. A crash between its commit and
	// our MarkEventProcessedOK below redelivers; the next call finds no
	// PENDING rows and no-ops — duplicate pushes are acceptable for the
	// POC; ledger integrity is preserved.
	results, err := p.Service.FinalizeForPayer(ctx, fp.PayerUserID)
	if err != nil {
		// Transient — nak for redelivery (returning an error bubbles up
		// to Run which issues NakWithDelay).
		return err
	}

	if err := ev.MarkEventProcessedOK(ctx, env.ID); err != nil {
		return err
	}
	p.recordOutcome("settled")
	p.emitNotifications(ctx, fp, results)
	return nil
}

func (p *FinalizeProcessor) recordOutcome(status string) {
	if p.ProcessedTotal == nil {
		return
	}
	p.ProcessedTotal.WithLabelValues(status).Inc()
}

const defaultNotifyConcurrency = 32

func (p *FinalizeProcessor) notifySlot() chan struct{} {
	p.notifyOnce.Do(func() {
		n := p.NotifyConcurrency
		if n <= 0 {
			n = defaultNotifyConcurrency
		}
		p.notifySem = make(chan struct{}, n)
	})
	return p.notifySem
}

// emitNotifications fans out a push to the payer (one per finalize call)
// plus one push per distinct receiver in the settled rows. Failures are
// logged but never surface back to the processor — a missing push
// shouldn't cause a ledger-reverting redelivery.
func (p *FinalizeProcessor) emitNotifications(ctx context.Context, fp domain.FinalizePayerPayload, results []domain.SettlementResult) {
	if p.Notifier == nil || len(results) == 0 {
		return
	}
	log := logging.Or(p.Logger)

	// Aggregate per-receiver totals so each merchant gets a single push
	// regardless of how many sequence numbers landed in this batch.
	type recvTotal struct{ settled int64 }
	byReceiver := map[string]*recvTotal{}
	var payerTotalSettled int64
	for _, r := range results {
		if r.Status != domain.TxSettled && r.Status != domain.TxPartiallySettled {
			continue
		}
		payerTotalSettled += r.SettledAmount
		if r.ReceiverUserID == "" {
			continue
		}
		if _, ok := byReceiver[r.ReceiverUserID]; !ok {
			byReceiver[r.ReceiverUserID] = &recvTotal{}
		}
		byReceiver[r.ReceiverUserID].settled += r.SettledAmount
	}
	if payerTotalSettled == 0 && len(byReceiver) == 0 {
		return
	}

	sem := p.notifySlot()
	select {
	case sem <- struct{}{}:
	case <-ctx.Done():
		log.Warn("settlement notify dropped; shutting down",
			"payer_user_id", fp.PayerUserID)
		return
	}
	p.notifyWG.Add(1)
	go func() {
		defer p.notifyWG.Done()
		defer func() { <-sem }()

		sendCtx := context.WithoutCancel(ctx)
		send := func(e notification.Event) {
			if err := p.Notifier.Send(sendCtx, e); err != nil {
				log.Warn("settlement notification send failed",
					"type", e.Type, "user_id", e.UserID, "err", err)
			}
		}

		if payerTotalSettled > 0 {
			naira := strconv.FormatFloat(float64(payerTotalSettled)/100, 'f', 2, 64)
			send(notification.Event{
				UserID: fp.PayerUserID,
				Type:   "offline_payment_settled",
				Title:  "Offline payment settled",
				Body:   fmt.Sprintf("\u20a6%s debited from your offline wallet.", naira),
				Metadata: map[string]string{
					"reason":            fp.Reason,
					"settled_amount":    strconv.FormatInt(payerTotalSettled, 10),
					"result_count":      strconv.Itoa(len(results)),
				},
			})
		}
		for uid, tot := range byReceiver {
			naira := strconv.FormatFloat(float64(tot.settled)/100, 'f', 2, 64)
			send(notification.Event{
				UserID: uid,
				Type:   "offline_payment_received",
				Title:  "Offline payment received",
				Body:   fmt.Sprintf("\u20a6%s is now available in your wallet.", naira),
				Metadata: map[string]string{
					"payer_user_id":  fp.PayerUserID,
					"settled_amount": strconv.FormatInt(tot.settled, 10),
				},
			})
		}
	}()
}
