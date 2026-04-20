
package opsrepo

import (
	"context"
	"fmt"
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

// RotateRealmKey mints a new realm key, retires every other active key
// with retired_at = now+overlap, and prunes rows past their retired_at.
// Returns the newly minted version.
func (r *Repo) RotateRealmKey(ctx context.Context, keyBytes []byte, overlap time.Duration) (int32, error) {
	var newVersion int32
	err := r.tx(ctx, func(q *sqlcgen.Queries) error {
		v, err := q.NextRealmKeyVersion(ctx)
		if err != nil {
			return fmt.Errorf("next version: %w", err)
		}
		now := time.Now().UTC()
		if _, err := q.CreateRealmKey(ctx, sqlcgen.CreateRealmKeyParams{
			Version:    v,
			KeyEnc:     keyBytes,
			ActiveFrom: ts(now),
		}); err != nil {
			return fmt.Errorf("insert new key: %w", err)
		}
		retiredAt := now.Add(overlap)
		if err := q.RetireOtherRealmKeys(ctx, sqlcgen.RetireOtherRealmKeysParams{
			Version:   v,
			RetiredAt: ts(retiredAt),
		}); err != nil {
			return fmt.Errorf("retire old keys: %w", err)
		}
		if err := q.DeleteRetiredRealmKeysBefore(ctx, ts(now)); err != nil {
			return fmt.Errorf("prune expired keys: %w", err)
		}
		newVersion = v
		return nil
	})
	return newVersion, err
}

// RotateBankKey inserts a fresh bank_signing_keys row and optionally
// retires every currently-active key in the same tx.
func (r *Repo) RotateBankKey(ctx context.Context, keyID string, pub, priv []byte, retirePrev bool) error {
	return r.tx(ctx, func(q *sqlcgen.Queries) error {
		now := time.Now().UTC()
		if retirePrev {
			if err := q.RetireAllActiveBankSigningKeys(ctx, ts(now)); err != nil {
				return fmt.Errorf("retire previous: %w", err)
			}
		}
		if _, err := q.CreateBankSigningKey(ctx, sqlcgen.CreateBankSigningKeyParams{
			KeyID:      keyID,
			Pubkey:     pub,
			PrivkeyEnc: priv,
			ActiveFrom: ts(now),
		}); err != nil {
			return fmt.Errorf("insert key: %w", err)
		}
		return nil
	})
}

// ForceExpireActiveCeiling flips one ACTIVE ceiling to EXPIRED. Returns
// true when a row was updated, false when the id is unknown or already
// non-active so callers can distinguish a no-op.
func (r *Repo) ForceExpireActiveCeiling(ctx context.Context, id string) (bool, error) {
	n, err := r.q.ForceExpireActiveCeiling(ctx, id)
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

// FreezeUser inserts a CRITICAL SIGNATURE_INVALID fraud signal against
// the user. The ceiling_token_id / transaction_id fields are left null;
// the decayed fraud score is what actually drives the SUSPENDED tier.
func (r *Repo) FreezeUser(ctx context.Context, signalID, userID, reason string) error {
	_, err := r.q.InsertFraudSignal(ctx, sqlcgen.InsertFraudSignalParams{
		ID:         signalID,
		UserID:     userID,
		SignalType: sqlcgen.FraudSignalTypeSIGNATUREINVALID,
		Details:    reason,
		Severity:   "CRITICAL",
		Weight:     5.0,
	})
	return err
}

func (r *Repo) tx(ctx context.Context, fn func(*sqlcgen.Queries) error) error {
	tx, err := r.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("opsrepo: begin tx: %w", err)
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

func ts(t time.Time) pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: t, Valid: true}
}
