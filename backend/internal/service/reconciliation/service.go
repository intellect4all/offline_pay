// Package reconciliation implements the three reconciliation loops:
// SyncUser (client diff against server truth), BatchReceipt (merchant
// receipt lookup by settlement_batch_id), and NightlyLedgerReconcile
// (cron double-entry check).
//
// FraudRecorder is redeclared here (same shape as settlement.FraudRecorder)
// to avoid a settlement import. Go interfaces are structural, so one
// concrete impl satisfies both.
package reconciliation

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

var (
	// ErrNoSuchBatch means BatchReceipt found no payments referencing the
	// supplied settlement_batch_id.
	ErrNoSuchBatch = errors.New("reconciliation: no such batch")
	// ErrNoRows mirrors the settlement sentinel so fake repos can match
	// via isNoRows.
	ErrNoRows = errors.New("no rows in result set")
)

type Clock interface{ Now() time.Time }

type SystemClock struct{}

func (SystemClock) Now() time.Time { return time.Now().UTC() }

type FraudRecorder interface {
	Record(ctx context.Context, ev domain.FraudEvent)
}

type NoopFraudRecorder struct{}

func (NoopFraudRecorder) Record(context.Context, domain.FraudEvent) {}

// ClientTxnEntry is what the device reports from its local transaction log
// during SyncUser. The service compares each entry against authoritative
// server data and records any mismatch as a Discrepancy.
type ClientTxnEntry struct {
	// TransactionID is the server-assigned payment id. For offline-only
	// entries the client may not know this yet — use SequenceNumber in that
	// case and leave ID empty; the server resolves by (payer, sequence).
	TransactionID string
	// PayerID is the paying user's id.
	PayerID string
	// PayeeID is the receiving user's id.
	PayeeID string
	// Amount is the kobo amount the client recorded.
	Amount int64
	// SequenceNumber is the monotonic sequence for this ceiling.
	SequenceNumber int64
	// Status is the client's last-known status for this txn.
	Status domain.TransactionStatus
}

// SyncResult is the payload returned to a reconciling client.
type SyncResult struct {
	// PayerSide is every SETTLED / PARTIALLY_SETTLED txn where user is payer.
	PayerSide []domain.Transaction
	// ReceiverSide is every SETTLED / PARTIALLY_SETTLED txn where user is payee.
	ReceiverSide []domain.Transaction
	// Discrepancies are mismatches between clientLog and server truth.
	Discrepancies []domain.Discrepancy
}

// Repository is the narrow repo subset the reconciliation service needs.
// *pgrepo.Repo (via the adapter) satisfies this interface.
type Repository interface {
	ListSettledTxnsForPayer(ctx context.Context, userID string) ([]domain.Transaction, error)
	ListSettledTxnsForReceiver(ctx context.Context, userID string) ([]domain.Transaction, error)
	GetPayment(ctx context.Context, id string) (domain.Transaction, error)

	ListPaymentsByBatch(ctx context.Context, batchID string) ([]domain.Transaction, error)

	ListAllAccounts(ctx context.Context) ([]pgrepo.AccountSnapshot, error)
	ListAllCeilings(ctx context.Context) ([]pgrepo.CeilingSnapshot, error)
	AccountLedgerSum(ctx context.Context, accountID string) (debit int64, credit int64, err error)
	SettledTotalForCeiling(ctx context.Context, ceilingID string) (int64, error)

	InsertReconciliationRun(ctx context.Context, rec domain.ReconciliationRecord) (domain.ReconciliationRecord, error)
}

// Service is the stateless reconciliation engine.
type Service struct {
	Repo  Repository
	Clock Clock
	Fraud FraudRecorder
	NewID func() string
}

// New constructs a Service with production defaults.
func New(repo Repository) *Service {
	return &Service{
		Repo:  repo,
		Clock: SystemClock{},
		Fraud: NoopFraudRecorder{},
		NewID: pgrepo.NewID,
	}
}

// SyncUser diffs a client-reported txn log against server truth and returns
// the authoritative settled-txn view plus any detected discrepancies. The
// caller may also pass a list of txn ids the user explicitly disputes;
// those are recorded as FraudGeographicAnomaly signals (per spec — a
// geographic/identity claim that the user did not perform a transaction).
func (s *Service) SyncUser(ctx context.Context, userID string, clientLog []ClientTxnEntry, disputed []string) (SyncResult, error) {
	if userID == "" {
		return SyncResult{}, errors.New("reconciliation: userID required")
	}
	payerSide, err := s.Repo.ListSettledTxnsForPayer(ctx, userID)
	if err != nil {
		return SyncResult{}, fmt.Errorf("reconciliation: list payer-side: %w", err)
	}
	receiverSide, err := s.Repo.ListSettledTxnsForReceiver(ctx, userID)
	if err != nil {
		return SyncResult{}, fmt.Errorf("reconciliation: list receiver-side: %w", err)
	}

	discrepancies := diffClientLog(userID, clientLog, payerSide, receiverSide)

	// Record each disputed txn id as a FraudGeographicAnomaly signal.
	now := s.Clock.Now().UTC()
	for _, d := range disputed {
		d := d
		ev := domain.FraudEvent{
			UserID:        userID,
			SignalType:    domain.FraudGeographicAnomaly,
			TransactionID: &d,
			Severity:      "MEDIUM",
			Details:       "user-disputed transaction during reconciliation sync",
			CreatedAt:     now,
		}
		s.Fraud.Record(ctx, ev)
	}

	return SyncResult{
		PayerSide:     payerSide,
		ReceiverSide:  receiverSide,
		Discrepancies: discrepancies,
	}, nil
}

// diffClientLog returns every mismatch between clientLog and server truth.
// Missing client-side = MISSING. Present but wrong amount/status = MISMATCH.
func diffClientLog(userID string, clientLog []ClientTxnEntry, payerSide, receiverSide []domain.Transaction) []domain.Discrepancy {
	// Build index of server-side txns relevant to this user keyed by id and
	// by (payer, sequence). A txn can appear on both sides only when payer ==
	// payee, which the settlement service forbids; dedupe by id anyway.
	byID := map[string]domain.Transaction{}
	bySeq := map[string]domain.Transaction{}
	for _, t := range payerSide {
		byID[t.ID] = t
		bySeq[seqKey(t.PayerID, t.SequenceNumber)] = t
	}
	for _, t := range receiverSide {
		if _, ok := byID[t.ID]; !ok {
			byID[t.ID] = t
			bySeq[seqKey(t.PayerID, t.SequenceNumber)] = t
		}
	}

	var discrepancies []domain.Discrepancy
	seen := map[string]bool{}
	// Pass 1: entries the client reports.
	for _, entry := range clientLog {
		var server domain.Transaction
		var found bool
		if entry.TransactionID != "" {
			server, found = byID[entry.TransactionID]
		}
		if !found {
			server, found = bySeq[seqKey(entry.PayerID, entry.SequenceNumber)]
		}
		if !found {
			// Client thinks a txn exists that the server has no record of.
			// Record as MISMATCH on existence — server shows nothing.
			discrepancies = append(discrepancies, domain.Discrepancy{
				TransactionID: entry.TransactionID,
				Field:         "existence",
				Expected:      "present on server",
				Actual:        "absent",
				Severity:      "WARNING",
			})
			continue
		}
		seen[server.ID] = true
		if entry.Amount != server.Amount {
			discrepancies = append(discrepancies, domain.Discrepancy{
				TransactionID: server.ID,
				Field:         "amount",
				Expected:      strconv.FormatInt(server.Amount, 10),
				Actual:        strconv.FormatInt(entry.Amount, 10),
				Severity:      "CRITICAL",
			})
		}
		if entry.Status != "" && entry.Status != server.Status {
			discrepancies = append(discrepancies, domain.Discrepancy{
				TransactionID: server.ID,
				Field:         "status",
				Expected:      string(server.Status),
				Actual:        string(entry.Status),
				Severity:      "WARNING",
			})
		}
	}
	// Pass 2: server-side txns the client didn't mention.
	for id, server := range byID {
		if seen[id] {
			continue
		}
		discrepancies = append(discrepancies, domain.Discrepancy{
			TransactionID: id,
			Field:         "existence",
			Expected:      "present on client log",
			Actual:        "missing",
			Severity:      "WARNING",
		})
		_ = server // keep the reference, could extend fields later
	}
	return discrepancies
}

func seqKey(payer string, seq int64) string {
	return payer + "|" + strconv.FormatInt(seq, 10)
}

// BatchReceipt rebuilds a settlement batch descriptor and per-item results
// from the payment_tokens table. The batch_id is the same value settlement
// sets on UpdatePaymentState during Phase 4a submit.
func (s *Service) BatchReceipt(ctx context.Context, batchID string) (domain.SettlementBatch, []domain.SettlementResult, error) {
	if batchID == "" {
		return domain.SettlementBatch{}, nil, errors.New("reconciliation: batchID required")
	}
	rows, err := s.Repo.ListPaymentsByBatch(ctx, batchID)
	if err != nil {
		return domain.SettlementBatch{}, nil, fmt.Errorf("reconciliation: list batch payments: %w", err)
	}
	if len(rows) == 0 {
		return domain.SettlementBatch{}, nil, ErrNoSuchBatch
	}
	batch := domain.SettlementBatch{
		ID:             batchID,
		TotalSubmitted: len(rows),
		Status:         domain.BatchCompleted,
	}
	results := make([]domain.SettlementResult, 0, len(rows))
	var firstSubmitted, lastSettled time.Time
	for _, t := range rows {
		// All rows in a submit batch share a single receiver (see
		// settlement.SubmitClaim).
		if batch.ReceiverID == "" {
			batch.ReceiverID = t.PayeeID
		}
		switch t.Status {
		case domain.TxSettled:
			batch.TotalSettled++
			batch.TotalAmount += t.SettledAmount
		case domain.TxPartiallySettled:
			batch.TotalPartial++
			batch.TotalAmount += t.SettledAmount
		case domain.TxRejected:
			batch.TotalRejected++
		}
		if t.SubmittedAt != nil && (firstSubmitted.IsZero() || t.SubmittedAt.Before(firstSubmitted)) {
			firstSubmitted = *t.SubmittedAt
		}
		if t.SettledAt != nil && t.SettledAt.After(lastSettled) {
			lastSettled = *t.SettledAt
		}
		reason := ""
		if t.RejectionReason != nil {
			reason = *t.RejectionReason
		}
		results = append(results, domain.SettlementResult{
			TransactionID:   t.ID,
			SequenceNumber:  t.SequenceNumber,
			SubmittedAmount: t.Amount,
			SettledAmount:   t.SettledAmount,
			Status:          t.Status,
			Reason:          reason,
		})
	}
	batch.SubmittedAt = firstSubmitted
	if !lastSettled.IsZero() {
		t := lastSettled
		batch.ProcessedAt = &t
	}
	batch.CreatedAt = firstSubmitted
	// Any non-terminal payments → still processing. Otherwise COMPLETED.
	for _, t := range rows {
		if !t.Status.IsTerminal() && t.Status != domain.TxPending && t.Status != domain.TxSubmitted {
			// defensive
			batch.Status = domain.BatchProcessing
			break
		}
		if t.Status == domain.TxPending || t.Status == domain.TxSubmitted {
			batch.Status = domain.BatchProcessing
			break
		}
	}
	return batch, results, nil
}

// NightlyLedgerReconcile iterates every account and every ceiling, verifying
// that stored balances agree with the ledger and that no ceiling has been
// over-drawn. The result is persisted to reconciliation_runs.
func (s *Service) NightlyLedgerReconcile(ctx context.Context) (domain.ReconciliationRecord, error) {
	accounts, err := s.Repo.ListAllAccounts(ctx)
	if err != nil {
		return domain.ReconciliationRecord{}, fmt.Errorf("reconciliation: list accounts: %w", err)
	}
	ceilings, err := s.Repo.ListAllCeilings(ctx)
	if err != nil {
		return domain.ReconciliationRecord{}, fmt.Errorf("reconciliation: list ceilings: %w", err)
	}

	var discrepancies []domain.Discrepancy

	for _, a := range accounts {
		deb, cred, err := s.Repo.AccountLedgerSum(ctx, a.ID)
		if err != nil {
			return domain.ReconciliationRecord{}, fmt.Errorf("reconciliation: ledger sum %s: %w", a.ID, err)
		}
		// Asset convention in this system: accounts are incremented on
		// CREDIT, decremented on DEBIT (see repo.IncrementAccountBalance
		// mirrors Credit). Expected balance = credit - debit. Suspense is
		// allowed to sit at any value (spends life at <=0 between 4a/4b).
		expected := cred - deb
		if expected != a.Balance {
			discrepancies = append(discrepancies, domain.Discrepancy{
				TransactionID: "",
				Field:         "account_balance:" + a.ID + ":" + string(a.Kind),
				Expected:      strconv.FormatInt(expected, 10),
				Actual:        strconv.FormatInt(a.Balance, 10),
				Severity:      "CRITICAL",
			})
		}
	}

	for _, c := range ceilings {
		settled, err := s.Repo.SettledTotalForCeiling(ctx, c.ID)
		if err != nil {
			return domain.ReconciliationRecord{}, fmt.Errorf("reconciliation: ceiling sum %s: %w", c.ID, err)
		}
		if settled > c.CeilingAmount {
			discrepancies = append(discrepancies, domain.Discrepancy{
				TransactionID: "",
				Field:         "ceiling_overdraw:" + c.ID,
				Expected:      "<= " + strconv.FormatInt(c.CeilingAmount, 10),
				Actual:        strconv.FormatInt(settled, 10),
				Severity:      "CRITICAL",
			})
		}
	}

	rec := domain.ReconciliationRecord{
		Type:          domain.ReconLedger,
		EntityID:      "system",
		RunAt:         s.Clock.Now().UTC(),
		Discrepancies: discrepancies,
	}
	if len(discrepancies) == 0 {
		rec.Status = domain.ReconClean
	} else {
		rec.Status = domain.ReconDiscrepancy
	}
	if s.NewID != nil {
		rec.ID = s.NewID()
	}
	saved, err := s.Repo.InsertReconciliationRun(ctx, rec)
	if err != nil {
		return domain.ReconciliationRecord{}, fmt.Errorf("reconciliation: persist run: %w", err)
	}
	// Preserve the discrepancy slice we computed; the DB round-trip may or
	// may not hydrate the full JSON back.
	saved.Discrepancies = rec.Discrepancies
	return saved, nil
}

// _ ensures sqlcgen is referenced in case we later need its enums at service
// level. Keeps the import list stable without forcing callers to add one.
var _ = sqlcgen.AccountKindMain
