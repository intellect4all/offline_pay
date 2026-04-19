package kycrepo

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

var ErrNotFound = errors.New("kycrepo: not found")

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

// UserContext is the minimum pair the submit flow needs: the phone (to
// compute the expected mock id in dev) and the current tier (so we only
// promote when the new tier strictly exceeds it).
type UserContext struct {
	Phone   string
	KYCTier string
}

func (r *Repo) GetUserContext(ctx context.Context, userID string) (UserContext, error) {
	row, err := r.q.GetUserPhoneAndTier(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return UserContext{}, ErrNotFound
		}
		return UserContext{}, err
	}
	return UserContext{Phone: row.Phone, KYCTier: row.KycTier}, nil
}

// SubmissionInput is the field set SubmitKYC persists.
type SubmissionInput struct {
	ID              string
	UserID          string
	IDType          string
	IDNumber        string
	Status          string
	RejectionReason *string
	TierGranted     *string
	SubmittedBy     *string
	VerifiedAt      *time.Time
}

// Submit persists one submission and, when VERIFIED and the granted
// tier is strictly higher than the user's current tier, promotes the
// user in the same tx. Returns the server-assigned submitted_at.
//
// Post-commit, if the tx succeeded AND a tier was granted, invalidates
// the transfer service's cached tier for this user so the next transfer
// sees the new tier. The Del runs outside the tx so a cache failure
// cannot roll back a committed promotion.
func (r *Repo) Submit(ctx context.Context, in SubmissionInput) (time.Time, error) {
	var submittedAt time.Time
	err := r.tx(ctx, func(q *sqlcgen.Queries) error {
		if err := q.InsertKYCSubmission(ctx, sqlcgen.InsertKYCSubmissionParams{
			ID:              in.ID,
			UserID:          in.UserID,
			IDType:          in.IDType,
			IDNumber:        in.IDNumber,
			Status:          in.Status,
			RejectionReason: in.RejectionReason,
			TierGranted:     in.TierGranted,
			SubmittedBy:     in.SubmittedBy,
			VerifiedAt:      optTs(in.VerifiedAt),
		}); err != nil {
			return err
		}
		if in.TierGranted != nil && *in.TierGranted != "" {
			if err := q.PromoteUserToTier(ctx, sqlcgen.PromoteUserToTierParams{
				ID:      in.UserID,
				KycTier: *in.TierGranted,
			}); err != nil {
				return fmt.Errorf("promote tier: %w", err)
			}
		}
		ts, err := q.GetKYCSubmissionSubmittedAt(ctx, in.ID)
		if err != nil {
			return err
		}
		submittedAt = ts.Time
		return nil
	})
	if err == nil && in.TierGranted != nil && *in.TierGranted != "" {
		// Invalidate every cached projection that surfaces kyc_tier:
		//   - user:tier:<id> — transferrepo's narrow tier cache.
		//   - user:me:<id>   — userauthrepo's /v1/me projection.
		// Key prefixes are string literals to avoid importing sibling
		// repo packages; both owners depend only on cache.Cache, so
		// there's no cycle to worry about.
		_ = r.cache.Del(ctx, "user:tier:"+in.UserID, "user:me:"+in.UserID)
	}
	return submittedAt, err
}

// SubmissionRow is the read projection for the user-facing list.
type SubmissionRow struct {
	ID              string
	UserID          string
	IDType          string
	IDNumber        string
	Status          string
	RejectionReason *string
	TierGranted     *string
	SubmittedBy     *string
	SubmittedAt     time.Time
	VerifiedAt      *time.Time
}

func (r *Repo) ListByUser(ctx context.Context, userID string) ([]SubmissionRow, error) {
	rows, err := r.q.ListKYCSubmissionsByUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]SubmissionRow, 0, len(rows))
	for _, row := range rows {
		out = append(out, SubmissionRow{
			ID:              row.ID,
			UserID:          row.UserID,
			IDType:          row.IDType,
			IDNumber:        row.IDNumber,
			Status:          row.Status,
			RejectionReason: row.RejectionReason,
			TierGranted:     row.TierGranted,
			SubmittedBy:     row.SubmittedBy,
			SubmittedAt:     row.SubmittedAt.Time,
			VerifiedAt:      tsPtr(row.VerifiedAt),
		})
	}
	return out, nil
}

// GetUserPhone powers the hint helper: derives the mock expected ids
// deterministically from the user's phone.
func (r *Repo) GetUserPhone(ctx context.Context, userID string) (string, error) {
	s, err := r.q.GetUserPhoneByID(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", ErrNotFound
		}
		return "", err
	}
	return s, nil
}

func (r *Repo) tx(ctx context.Context, fn func(*sqlcgen.Queries) error) error {
	tx, err := r.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("kycrepo: begin tx: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback(context.Background())
		}
	}()
	if err := fn(r.q.WithTx(tx)); err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return err
	}
	committed = true
	return nil
}

func optTs(t *time.Time) pgtype.Timestamptz {
	if t == nil {
		return pgtype.Timestamptz{}
	}
	return pgtype.Timestamptz{Time: *t, Valid: true}
}

func tsPtr(t pgtype.Timestamptz) *time.Time {
	if !t.Valid {
		return nil
	}
	v := t.Time
	return &v
}
