package pgrepo

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

type AccountSnapshot struct {
	ID      string
	UserID  string
	Kind    sqlcgen.AccountKind
	Balance int64
}

// CeilingSnapshot is a lightweight ceiling row used by nightly reconcile.
type CeilingSnapshot struct {
	ID            string
	PayerUserID   string
	CeilingAmount int64
	Status        domain.CeilingStatus
}

// ListSettledTxnsForPayer returns all SETTLED/PARTIALLY_SETTLED payments
// where user is the payer, ordered by sequence_number.
func (r *Repo) ListSettledTxnsForPayer(ctx context.Context, userID string) ([]domain.Transaction, error) {
	rows, err := r.q.ListSettledTxnsForPayer(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]domain.Transaction, len(rows))
	for i, row := range rows {
		out[i] = paymentToDomainTxn(row)
	}
	return out, nil
}

// ListSettledTxnsForReceiver returns all SETTLED/PARTIALLY_SETTLED payments
// where user is the payee, ordered by created_at.
func (r *Repo) ListSettledTxnsForReceiver(ctx context.Context, userID string) ([]domain.Transaction, error) {
	rows, err := r.q.ListSettledTxnsForReceiver(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]domain.Transaction, len(rows))
	for i, row := range rows {
		out[i] = paymentToDomainTxn(row)
	}
	return out, nil
}

// AccountLedgerSum returns (sumDebit, sumCredit) across ledger_entries for
// the given account.
func (r *Repo) AccountLedgerSum(ctx context.Context, accountID string) (int64, int64, error) {
	row, err := r.q.AccountLedgerSum(ctx, accountID)
	if err != nil {
		return 0, 0, err
	}
	return row.DebitTotal, row.CreditTotal, nil
}

// ListAllAccounts returns every accounts row (including system suspense).
func (r *Repo) ListAllAccounts(ctx context.Context) ([]AccountSnapshot, error) {
	rows, err := r.q.ListAllAccounts(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]AccountSnapshot, len(rows))
	for i, row := range rows {
		out[i] = AccountSnapshot{
			ID: row.ID, UserID: row.UserID, Kind: row.Kind, Balance: row.BalanceKobo,
		}
	}
	return out, nil
}

// ListAllCeilings returns every ceiling (for nightly ledger reconcile).
func (r *Repo) ListAllCeilings(ctx context.Context) ([]CeilingSnapshot, error) {
	rows, err := r.q.ListAllCeilings(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]CeilingSnapshot, len(rows))
	for i, row := range rows {
		out[i] = CeilingSnapshot{
			ID: row.ID, PayerUserID: row.PayerUserID,
			CeilingAmount: row.CeilingKobo, Status: domain.CeilingStatus(row.Status),
		}
	}
	return out, nil
}

// SettledTotalForCeiling returns the sum of settled_amount_kobo across
// SETTLED/PARTIALLY_SETTLED payments for the given ceiling.
func (r *Repo) SettledTotalForCeiling(ctx context.Context, ceilingID string) (int64, error) {
	return r.q.SettledTotalForCeiling(ctx, ceilingID)
}

// ListPaymentsByBatch returns every payment row recorded under the given
// settlement_batch_id.
func (r *Repo) ListPaymentsByBatch(ctx context.Context, batchID string) ([]domain.Transaction, error) {
	rows, err := r.q.ListPaymentsByBatch(ctx, &batchID)
	if err != nil {
		return nil, err
	}
	out := make([]domain.Transaction, len(rows))
	for i, row := range rows {
		out[i] = paymentToDomainTxn(row)
	}
	return out, nil
}

// InsertReconciliationRun persists a domain.ReconciliationRecord.
func (r *Repo) InsertReconciliationRun(ctx context.Context, rec domain.ReconciliationRecord) (domain.ReconciliationRecord, error) {
	if rec.ID == "" {
		rec.ID = NewID()
	}
	disc := rec.Discrepancies
	if disc == nil {
		disc = []domain.Discrepancy{}
	}
	b, err := json.Marshal(disc)
	if err != nil {
		return domain.ReconciliationRecord{}, fmt.Errorf("pgrepo: marshal discrepancies: %w", err)
	}
	row, err := r.q.CreateReconciliationRun(ctx, sqlcgen.CreateReconciliationRunParams{
		ID:            rec.ID,
		Type:          sqlcgen.ReconciliationType(rec.Type),
		EntityID:      rec.EntityID,
		Status:        sqlcgen.ReconciliationStatus(rec.Status),
		Discrepancies: b,
	})
	if err != nil {
		return domain.ReconciliationRecord{}, err
	}
	out := domain.ReconciliationRecord{
		ID:            row.ID,
		Type:          domain.ReconciliationType(row.Type),
		EntityID:      row.EntityID,
		RunAt:         fromTSZ(row.RunAt),
		Status:        domain.ReconciliationStatus(row.Status),
		Discrepancies: rec.Discrepancies,
		CreatedAt:     fromTSZ(row.CreatedAt),
	}
	return out, nil
}
