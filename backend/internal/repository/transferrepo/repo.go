// Package transferrepo is the sqlc-backed repository for the transfer
// worker: dispatcher (outbox polling + publish-confirm) and processor
// (ledger mutation + processed_events). Both surfaces take a caller
// tx so they can own the BeginFunc / rollback lifecycle they need.
package transferrepo

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

// ErrNotFound is returned by single-row lookups that found nothing.
// Callers that care about "not registered yet" translate this into
// their own domain error (e.g. service.ErrReceiverNotFound).
var ErrNotFound = errors.New("transferrepo: not found")

type Repo struct {
	pool  *pgxpool.Pool
	q     *sqlcgen.Queries
	cache cache.Cache
}

// New constructs a Repo. c may be nil → cache.Noop.
func New(pool *pgxpool.Pool, c cache.Cache) *Repo {
	if c == nil {
		c = cache.Noop{}
	}
	return &Repo{pool: pool, q: sqlcgen.New(pool), cache: c}
}

// Pre-tx cached lookups: these two reads used to live inside AcceptTx.
// Lifting them out lets every transfer serve from Redis on the hot path
// and keeps the tx narrow. Staleness is bounded: the only mutation
// paths that matter (KYC promotion; account-number rotation — not
// currently supported) call the Invalidate* helpers on commit.

const (
	userTierCacheKeyPrefix = "user:tier:"
	userTierCacheTTL       = time.Hour

	receiverCacheKeyPrefix = "acct:uid:"
	receiverCacheTTL       = 24 * time.Hour
)

// ResolveReceiverUserID returns the user_id that owns accountNumber.
// Cache-aside on acct:uid:<account_number>. Returns ErrNotFound when
// the account number isn't registered.
func (r *Repo) ResolveReceiverUserID(ctx context.Context, accountNumber string) (string, error) {
	key := receiverCacheKeyPrefix + accountNumber
	var cached string
	if hit, _ := cache.GetJSON(ctx, r.cache, key, &cached); hit {
		return cached, nil
	}
	uid, err := r.q.GetUserIDByAccountNumber(ctx, accountNumber)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", ErrNotFound
		}
		return "", err
	}
	_ = cache.SetJSON(ctx, r.cache, key, uid, receiverCacheTTL)
	return uid, nil
}

// GetSenderKYCTier returns the sender's kyc_tier. Cache-aside on
// user:tier:<user_id>. Safe to cache because PromoteUserToTier is
// strictly monotone upward and invalidates via InvalidateUserTier.
func (r *Repo) GetSenderKYCTier(ctx context.Context, userID string) (string, error) {
	key := userTierCacheKeyPrefix + userID
	var cached string
	if hit, _ := cache.GetJSON(ctx, r.cache, key, &cached); hit {
		return cached, nil
	}
	tier, err := r.q.GetUserKYCTier(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", ErrNotFound
		}
		return "", err
	}
	_ = cache.SetJSON(ctx, r.cache, key, tier, userTierCacheTTL)
	return tier, nil
}

// InvalidateUserTier is called by writers that move a user's tier
// (e.g. kycrepo.Submit after PromoteUserToTier). Safe to call with a
// cache.Noop backing — it becomes a no-op.
func (r *Repo) InvalidateUserTier(ctx context.Context, userID string) {
	_ = r.cache.Del(ctx, userTierCacheKeyPrefix+userID)
}

// OutboxClaim is one row returned from the dispatcher's FOR UPDATE
// SKIP LOCKED claim. Field set is exactly what the dispatcher needs.
type OutboxClaim struct {
	ID          string
	Aggregate   string
	AggregateID string
	Payload     []byte
	Attempts    int
}

// WithDispatchTx runs fn inside a tx suited for an outbox dispatch
// cycle (default isolation — no need for Serializable here; SKIP LOCKED
// plus row-level writes are sufficient).
func (r *Repo) WithDispatchTx(ctx context.Context, fn func(DispatchQueries) error) error {
	return pgx.BeginFunc(ctx, r.pool, func(tx pgx.Tx) error {
		return fn(DispatchQueries{q: r.q.WithTx(tx)})
	})
}

// DispatchQueries is the per-tx handle the dispatcher uses. All three
// methods take only the fields the dispatcher cares about.
type DispatchQueries struct {
	q *sqlcgen.Queries
}

func (d DispatchQueries) ClaimBatch(ctx context.Context, batchSize int32) ([]OutboxClaim, error) {
	rows, err := d.q.ClaimOutboxBatch(ctx, batchSize)
	if err != nil {
		return nil, err
	}
	out := make([]OutboxClaim, 0, len(rows))
	for _, r := range rows {
		out = append(out, OutboxClaim{
			ID:          r.ID,
			Aggregate:   r.Aggregate,
			AggregateID: r.AggregateID,
			Payload:     r.Payload,
			Attempts:    int(r.Attempts),
		})
	}
	return out, nil
}

func (d DispatchQueries) MarkDispatched(ctx context.Context, id string) error {
	return d.q.MarkOutboxDispatched(ctx, id)
}

func (d DispatchQueries) BumpAttempt(ctx context.Context, id string, nextAttemptAt time.Time) error {
	return d.q.BumpOutboxAttempt(ctx, sqlcgen.BumpOutboxAttemptParams{
		ID:            id,
		NextAttemptAt: ts(nextAttemptAt),
	})
}

// IsEventProcessed is a pool-scoped read used before opening a tx so
// duplicate deliveries become a cheap round-trip.
func (r *Repo) IsEventProcessed(ctx context.Context, outboxID string) (bool, error) {
	return r.q.IsEventProcessed(ctx, outboxID)
}

// MarkEventProcessedSkipped records "SKIPPED" for non-transfer
// aggregates so JetStream doesn't redeliver forever.
func (r *Repo) MarkEventProcessedSkipped(ctx context.Context, outboxID string) error {
	return r.q.MarkEventProcessed(ctx, sqlcgen.MarkEventProcessedParams{
		OutboxID: outboxID,
		Status:   "SKIPPED",
	})
}

// MarkTransferFailedOutOfTx + MarkEventProcessedFailed run when the
// payload can't even be unmarshalled. Pool-scoped because there's no
// tx context.
func (r *Repo) MarkTransferFailedOutOfTx(ctx context.Context, transferID, reason string) error {
	return r.q.MarkTransferFailed(ctx, sqlcgen.MarkTransferFailedParams{
		ID:            transferID,
		FailureReason: &reason,
	})
}

func (r *Repo) MarkEventProcessedFailed(ctx context.Context, outboxID string) error {
	return r.q.MarkEventProcessed(ctx, sqlcgen.MarkEventProcessedParams{
		OutboxID: outboxID,
		Status:   "FAILED",
	})
}

// MarkEventProcessedOK is the out-of-tx "this event finished its work"
// marker. Used by aggregates (e.g. settlement-finalize) whose business
// work runs in its own tx — they record success in processed_events
// afterwards rather than alongside the business write.
func (r *Repo) MarkEventProcessedOK(ctx context.Context, outboxID string) error {
	return r.q.MarkEventProcessed(ctx, sqlcgen.MarkEventProcessedParams{
		OutboxID: outboxID,
		Status:   "SETTLED",
	})
}

// WithProcessTx runs the per-message tx: lock accounts, debit/credit,
// mark transfer + event. The tx handle exposes the minimum set the
// processor touches.
func (r *Repo) WithProcessTx(ctx context.Context, fn func(ProcessQueries) error) error {
	return pgx.BeginFunc(ctx, r.pool, func(tx pgx.Tx) error {
		return fn(ProcessQueries{q: r.q.WithTx(tx)})
	})
}

// ProcessQueries is the per-tx handle the processor uses.
type ProcessQueries struct {
	q *sqlcgen.Queries
}

// LockMainAccount grabs the user's 'main' account row with FOR UPDATE.
// Returns ErrNoRows if the user hasn't been provisioned yet.
func (p ProcessQueries) LockMainAccount(ctx context.Context, userID string) (accountID string, err error) {
	row, err := p.q.LockMainAccountForUser(ctx, userID)
	if err != nil {
		return "", err
	}
	return row.ID, nil
}

// DecrementBalanceGuarded debits the account iff the balance covers the
// amount. Returns pgx.ErrNoRows when the guard fails.
func (p ProcessQueries) DecrementBalanceGuarded(ctx context.Context, accountID string, amountKobo int64) error {
	_, err := p.q.DecrementAccountBalance(ctx, sqlcgen.DecrementAccountBalanceParams{
		ID:          accountID,
		BalanceKobo: amountKobo,
	})
	return err
}

func (p ProcessQueries) IncrementBalance(ctx context.Context, accountID string, amountKobo int64) error {
	_, err := p.q.IncrementAccountBalance(ctx, sqlcgen.IncrementAccountBalanceParams{
		ID:          accountID,
		BalanceKobo: amountKobo,
	})
	return err
}

func (p ProcessQueries) MarkTransferSettled(ctx context.Context, transferID string) error {
	return p.q.MarkTransferSettled(ctx, transferID)
}

func (p ProcessQueries) MarkTransferFailed(ctx context.Context, transferID, reason string) error {
	return p.q.MarkTransferFailed(ctx, sqlcgen.MarkTransferFailedParams{
		ID:            transferID,
		FailureReason: &reason,
	})
}

func (p ProcessQueries) MarkEventSettled(ctx context.Context, outboxID string) error {
	return p.q.MarkEventProcessed(ctx, sqlcgen.MarkEventProcessedParams{
		OutboxID: outboxID,
		Status:   "SETTLED",
	})
}

func (p ProcessQueries) MarkEventFailed(ctx context.Context, outboxID string) error {
	return p.q.MarkEventProcessed(ctx, sqlcgen.MarkEventProcessedParams{
		OutboxID: outboxID,
		Status:   "FAILED",
	})
}

// AcceptTx runs the initiate-transfer tx. The caller drives it with its
// own lookups + writes because the accept path interleaves domain
// checks, fraud scoring, and the final insert+outbox pair.
func (r *Repo) AcceptTx(ctx context.Context, fn func(AcceptQueries) error) error {
	return pgx.BeginFunc(ctx, r.pool, func(tx pgx.Tx) error {
		return fn(AcceptQueries{q: r.q.WithTx(tx), Tx: tx})
	})
}

// AcceptQueries exposes the minimum set of operations the transfer
// accept path performs inside its tx. Tx is surfaced so the fraud
// scorer — which takes a pgx.Tx — can share the same transaction.
type AcceptQueries struct {
	q  *sqlcgen.Queries
	Tx pgx.Tx
}

// TransferProjection is the accept-side snapshot of a transfer row
// (excludes the flagged column, which is write-only at accept time).
type TransferProjection struct {
	ID                    string
	SenderUserID          string
	ReceiverUserID        string
	ReceiverAccountNumber string
	AmountKobo            int64
	Status                string
	Reference             string
	FailureReason         *string
	CreatedAt             time.Time
	SettledAt             *time.Time
}

func (p TransferProjection) ToDomain() *domain.Transfer {
	return &domain.Transfer{
		ID:                    p.ID,
		SenderUserID:          p.SenderUserID,
		ReceiverUserID:        p.ReceiverUserID,
		ReceiverAccountNumber: p.ReceiverAccountNumber,
		AmountKobo:            p.AmountKobo,
		Status:                domain.TransferStatus(p.Status),
		Reference:             p.Reference,
		FailureReason:         p.FailureReason,
		CreatedAt:             p.CreatedAt,
		SettledAt:             p.SettledAt,
	}
}

// GetByRef is the idempotency lookup — returns the prior transfer if
// (sender, reference) is already accepted, ErrNotFound otherwise.
func (a AcceptQueries) GetByRef(ctx context.Context, senderUserID, reference string) (TransferProjection, error) {
	row, err := a.q.GetTransferByRefProjection(ctx, sqlcgen.GetTransferByRefProjectionParams{
		SenderUserID: senderUserID,
		Reference:    reference,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return TransferProjection{}, ErrNotFound
		}
		return TransferProjection{}, err
	}
	return transferProjection(row), nil
}

// GetUserIDByAccountNumber resolves the receiver.
func (a AcceptQueries) GetUserIDByAccountNumber(ctx context.Context, accountNumber string) (string, error) {
	s, err := a.q.GetUserIDByAccountNumber(ctx, accountNumber)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", ErrNotFound
		}
		return "", err
	}
	return s, nil
}

// GetUserKYCTier is the tier check used for limit enforcement.
func (a AcceptQueries) GetUserKYCTier(ctx context.Context, userID string) (string, error) {
	return a.q.GetUserKYCTier(ctx, userID)
}

// GetUserAccountAgeHours is used by the fraud scorer's new-account
// rule.
func (a AcceptQueries) GetUserAccountAgeHours(ctx context.Context, userID string) (float64, error) {
	return a.q.GetUserAccountAgeHours(ctx, userID)
}

// SumTodaySenderTransfers totals today's in-flight/settled kobo for
// one sender (Africa/Lagos day boundary).
func (a AcceptQueries) SumTodaySenderTransfers(ctx context.Context, senderUserID string) (int64, error) {
	return a.q.SumSenderTransfersToday(ctx, senderUserID)
}

// InsertAccepted inserts a fresh transfer row with the fraud-flag set
// and returns the pre-flagged projection.
func (a AcceptQueries) InsertAccepted(ctx context.Context, p InsertAcceptedParams) (TransferProjection, error) {
	row, err := a.q.CreateTransferAcceptedFlagged(ctx, sqlcgen.CreateTransferAcceptedFlaggedParams{
		ID:                    p.ID,
		SenderUserID:          p.SenderUserID,
		ReceiverUserID:        p.ReceiverUserID,
		ReceiverAccountNumber: p.ReceiverAccountNumber,
		AmountKobo:            p.AmountKobo,
		Reference:             p.Reference,
		Flagged:               p.Flagged,
	})
	if err != nil {
		return TransferProjection{}, err
	}
	return transferProjection(createTransferFlaggedRow(row)), nil
}

// InsertAcceptedParams bundles the accept-side write. The row id is
// caller-assigned (ulid) so the service controls id allocation.
type InsertAcceptedParams struct {
	ID                    string
	SenderUserID          string
	ReceiverUserID        string
	ReceiverAccountNumber string
	AmountKobo            int64
	Reference             string
	Flagged               bool
}

// InsertOutbox writes the outbox row that the dispatcher will pick up.
func (a AcceptQueries) InsertOutbox(ctx context.Context, id, aggregateID string, payload []byte) error {
	return a.q.InsertOutboxEntry(ctx, sqlcgen.InsertOutboxEntryParams{
		ID:          id,
		Aggregate:   "transfer",
		AggregateID: aggregateID,
		Payload:     payload,
	})
}

// RecordTransaction writes one row to the business-event transactions
// table. Two-party transfers call this twice (sender + receiver) inside
// the same AcceptTx so the paired rows commit atomically with the
// transfer + outbox.
func (a AcceptQueries) RecordTransaction(ctx context.Context, p sqlcgen.RecordTransactionParams) error {
	return a.q.RecordTransaction(ctx, p)
}

// RecordTransaction is the per-tx process-side analogue, used by the
// processor to write any required rows alongside the settle/fail
// updates.
func (p ProcessQueries) RecordTransaction(ctx context.Context, params sqlcgen.RecordTransactionParams) error {
	return p.q.RecordTransaction(ctx, params)
}

// FinalizeTransactionsForTransfer flips every transactions row tied to
// transferID to the given status, optionally stamping
// settled_amount_kobo / failure_reason. Used by the processor to
// advance both paired rows in lockstep with MarkTransferSettled /
// MarkTransferFailed.
func (p ProcessQueries) FinalizeTransactionsForTransfer(ctx context.Context, transferID string, status sqlcgen.TransactionLifecycleStatus, settled *int64, failureReason *string) error {
	anchor, err := p.q.GetTransactionAnchorForTransfer(ctx, &transferID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// No paired rows recorded — nothing to flip. Stay
			// permissive so transfers initiated before this feature
			// landed don't error out.
			return nil
		}
		return err
	}
	rows, err := p.q.ListTransactionsByGroup(ctx, anchor.GroupID)
	if err != nil {
		return err
	}
	for _, row := range rows {
		if err := p.q.UpdateTransactionStatus(ctx, sqlcgen.UpdateTransactionStatusParams{
			ID:                row.ID,
			Status:            status,
			SettledAmountKobo: settled,
			FailureReason:     failureReason,
		}); err != nil {
			return err
		}
	}
	return nil
}

func (r *Repo) GetTransfer(ctx context.Context, id string) (*domain.Transfer, error) {
	row, err := r.q.GetTransferProjection(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	p := transferProjection(sqlcgen.GetTransferByRefProjectionRow(row))
	return p.ToDomain(), nil
}

func (r *Repo) ListTransfersForUser(ctx context.Context, userID string, limit, offset int32) ([]domain.Transfer, error) {
	rows, err := r.q.ListTransfersForUser(ctx, sqlcgen.ListTransfersForUserParams{
		SenderUserID: userID,
		Limit:        limit,
		Offset:       offset,
	})
	if err != nil {
		return nil, err
	}
	out := make([]domain.Transfer, 0, len(rows))
	for _, row := range rows {
		p := transferProjection(sqlcgen.GetTransferByRefProjectionRow(row))
		out = append(out, *p.ToDomain())
	}
	return out, nil
}

// LookupDisplayNames resolves a deduped set of user ids to "First Last"
// strings. Missing ids are simply omitted from the map — the caller
// renders the raw id when no name is available. Safe with an empty
// input (returns an empty map without a round-trip).
func (r *Repo) LookupDisplayNames(ctx context.Context, userIDs []string) (map[string]string, error) {
	if len(userIDs) == 0 {
		return map[string]string{}, nil
	}
	rows, err := r.q.GetUserDisplayNamesByIDs(ctx, userIDs)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string, len(rows))
	for _, row := range rows {
		name := strings.TrimSpace(row.FirstName + " " + row.LastName)
		if name == "" {
			continue
		}
		out[row.ID] = name
	}
	return out, nil
}

func transferProjection(row sqlcgen.GetTransferByRefProjectionRow) TransferProjection {
	return TransferProjection{
		ID:                    row.ID,
		SenderUserID:          row.SenderUserID,
		ReceiverUserID:        row.ReceiverUserID,
		ReceiverAccountNumber: row.ReceiverAccountNumber,
		AmountKobo:            row.AmountKobo,
		Status:                row.Status,
		Reference:             row.Reference,
		FailureReason:         row.FailureReason,
		CreatedAt:             row.CreatedAt.Time,
		SettledAt:             tsPtr(row.SettledAt),
	}
}

// createTransferFlaggedRow coerces the CreateTransferAcceptedFlagged
// return row — which has the same columns in the same order — into the
// shared GetTransferByRefProjectionRow type so transferProjection can
// consume both.
func createTransferFlaggedRow(r sqlcgen.CreateTransferAcceptedFlaggedRow) sqlcgen.GetTransferByRefProjectionRow {
	return sqlcgen.GetTransferByRefProjectionRow(r)
}

func tsPtr(t pgtype.Timestamptz) *time.Time {
	if !t.Valid {
		return nil
	}
	v := t.Time
	return &v
}

func ts(t time.Time) pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: t, Valid: true}
}
