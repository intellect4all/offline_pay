// Package fraudrepo exposes the sqlc-backed reads + writes the fraud
// scoring layer needs. Velocity + novelty rules read through here
// during a caller-owned transaction; BLOCK outcomes write
// out-of-band through the pool.
package fraudrepo

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

type Repo struct {
	pool *pgxpool.Pool
	q    *sqlcgen.Queries
}

func New(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool, q: sqlcgen.New(pool)}
}

// CountRecentTransfersBySender is the velocity primitive — counts the
// sender's transfers in the trailing window, capped at limit so the
// scan stops short.
func (r *Repo) CountRecentTransfersBySender(ctx context.Context, tx pgx.Tx, senderUserID string, window time.Duration, limit int32) (int64, error) {
	return r.queriesFor(tx).CountRecentTransfersBySender(ctx, sqlcgen.CountRecentTransfersBySenderParams{
		SenderUserID: senderUserID,
		Column2:      interval(window),
		Limit:        limit,
	})
}

// ExistsTransferBetween returns whether the sender has ever transferred
// to the given receiver.
func (r *Repo) ExistsTransferBetween(ctx context.Context, tx pgx.Tx, senderUserID, receiverUserID string) (bool, error) {
	return r.queriesFor(tx).ExistsTransferBetween(ctx, sqlcgen.ExistsTransferBetweenParams{
		SenderUserID:   senderUserID,
		ReceiverUserID: receiverUserID,
	})
}

// SumSenderTransfersToday totals today's (Africa/Lagos) accepted /
// processing / settled transfer kobo for one sender.
func (r *Repo) SumSenderTransfersToday(ctx context.Context, tx pgx.Tx, senderUserID string) (int64, error) {
	return r.queriesFor(tx).SumSenderTransfersToday(ctx, senderUserID)
}

// InsertFraudScoreParams mirrors the sqlc params struct but takes
// nullable fields as plain `*string` so callers don't import pgtype.
type InsertFraudScoreParams struct {
	ID         string
	TransferID string
	SenderID   string
	Decision   string
	Rule       *string
	Reason     *string
	RuleHits   []byte
	AmountKobo int64
}

// InsertFraudScoreInTx records a FLAG outcome inside the caller's tx so
// the score commits atomically with the transfer acceptance.
func (r *Repo) InsertFraudScoreInTx(ctx context.Context, tx pgx.Tx, p InsertFraudScoreParams) error {
	return r.queriesFor(tx).InsertFraudScore(ctx, p.toSQLC())
}

// InsertFraudScore records a BLOCK outcome through the pool. The
// transfer tx is being rolled back so we cannot piggyback on it.
func (r *Repo) InsertFraudScore(ctx context.Context, p InsertFraudScoreParams) error {
	return r.q.InsertFraudScore(ctx, p.toSQLC())
}

func (p InsertFraudScoreParams) toSQLC() sqlcgen.InsertFraudScoreParams {
	return sqlcgen.InsertFraudScoreParams{
		ID:         p.ID,
		TransferID: p.TransferID,
		SenderID:   p.SenderID,
		Decision:   p.Decision,
		Rule:       p.Rule,
		Reason:     p.Reason,
		RuleHits:   p.RuleHits,
		AmountKobo: p.AmountKobo,
	}
}

// queriesFor returns a Queries scoped to tx when tx is non-nil, else
// the pool-scoped Queries. Scoring rules run inside the caller's tx;
// out-of-band writes (BLOCK) pass a nil tx.
func (r *Repo) queriesFor(tx pgx.Tx) *sqlcgen.Queries {
	if tx == nil {
		return r.q
	}
	return r.q.WithTx(tx)
}

// interval converts a time.Duration to a pgtype.Interval so callers
// don't touch pgx types. Microseconds is wide enough for any window the
// scorer uses (hours, not months).
func interval(d time.Duration) pgtype.Interval {
	return pgtype.Interval{Microseconds: d.Microseconds(), Valid: true}
}
