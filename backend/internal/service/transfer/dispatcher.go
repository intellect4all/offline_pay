package transfer

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/nats-io/nats.go"
	"github.com/prometheus/client_golang/prometheus"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/logging"
	"github.com/intellect/offlinepay/internal/repository/transferrepo"
)

// Dispatcher polls the outbox and publishes pending envelopes to JetStream.
// Publish-confirmed rows are marked dispatched; failures bump attempts +
// schedule an exponential retry.
//
// Subject routing: if `SubjectByAggregate` is set, the dispatcher looks
// the row's `aggregate` up in that map and publishes to the matching
// NATS subject. Rows whose aggregate is missing from the map fall back
// to the legacy `Subject` field. The map lets a single dispatcher serve
// multiple aggregates (transfer + settlement-finalize + …) without a
// per-aggregate dispatcher instance.
type Dispatcher struct {
	Pool               *pgxpool.Pool
	Repo               *transferrepo.Repo
	Nats               *nats.Conn
	JS                 nats.JetStreamContext
	Subject            string
	SubjectByAggregate map[string]string
	Logger             *slog.Logger
	BatchSize          int
	Interval           time.Duration

	// DispatchedTotal is incremented on every successful JetStream publish.
	// Optional — nil-safe.
	DispatchedTotal prometheus.Counter
	// DispatchFailuresTotal is incremented on every publish error.
	// Optional — nil-safe.
	DispatchFailuresTotal prometheus.Counter
}

func (d *Dispatcher) batch() int {
	if d.BatchSize <= 0 {
		return 16
	}
	return d.BatchSize
}

func (d *Dispatcher) interval() time.Duration {
	if d.Interval <= 0 {
		return 500 * time.Millisecond
	}
	return d.Interval
}

func (d *Dispatcher) subject() string {
	if d.Subject == "" {
		return "payments.transfer.v1"
	}
	return d.Subject
}

// subjectFor resolves the NATS subject a row should publish to. The
// per-aggregate map wins when present; otherwise fall back to the
// single-subject default so existing single-aggregate deployments keep
// working.
func (d *Dispatcher) subjectFor(aggregate string) string {
	if s, ok := d.SubjectByAggregate[aggregate]; ok && s != "" {
		return s
	}
	return d.subject()
}

// repo returns the Repo the dispatcher should use. Falls back to
// constructing one from Pool when Repo isn't wired — keeps existing
// tests that only set Pool working.
func (d *Dispatcher) repo() *transferrepo.Repo {
	if d.Repo != nil {
		return d.Repo
	}
	d.Repo = transferrepo.New(d.Pool, cache.Noop{})
	return d.Repo
}

// Run blocks until ctx is cancelled.
func (d *Dispatcher) Run(ctx context.Context) error {
	log := logging.Or(d.Logger)
	t := time.NewTicker(d.interval())
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-t.C:
			if err := d.tick(ctx); err != nil && !errors.Is(err, context.Canceled) {
				log.Error("dispatcher tick", "err", err)
			}
		}
	}
}

func (d *Dispatcher) tick(ctx context.Context) error {
	log := logging.Or(d.Logger)
	return d.repo().WithDispatchTx(ctx, func(q transferrepo.DispatchQueries) error {
		claims, err := q.ClaimBatch(ctx, int32(d.batch()))
		if err != nil {
			return err
		}
		if len(claims) == 0 {
			return nil
		}
		for _, c := range claims {
			env := domain.OutboxEnvelope{
				ID:          c.ID,
				Aggregate:   c.Aggregate,
				AggregateID: c.AggregateID,
				Payload:     json.RawMessage(c.Payload),
			}
			body, err := json.Marshal(env)
			if err != nil {
				log.Error("marshal envelope", "id", c.ID, "err", err)
				continue
			}
			_, pubErr := d.JS.Publish(d.subjectFor(c.Aggregate), body, nats.MsgId(c.ID))
			if pubErr != nil {
				next := time.Now().Add(backoff(c.Attempts))
				if err := q.BumpAttempt(ctx, c.ID, next); err != nil {
					return err
				}
				if d.DispatchFailuresTotal != nil {
					d.DispatchFailuresTotal.Inc()
				}
				log.Warn("publish failed", "id", c.ID, "attempts", c.Attempts+1, "next", next, "err", pubErr)
				continue
			}
			if err := q.MarkDispatched(ctx, c.ID); err != nil {
				return err
			}
			if d.DispatchedTotal != nil {
				d.DispatchedTotal.Inc()
			}
		}
		return nil
	})
}

// backoff is an exponential schedule: 1s, 2s, 4s, ... capped at 60s.
func backoff(attempts int) time.Duration {
	d := time.Second
	for i := 0; i < attempts && d < 60*time.Second; i++ {
		d *= 2
	}
	if d > 60*time.Second {
		d = 60 * time.Second
	}
	return d
}
