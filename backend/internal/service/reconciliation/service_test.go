package reconciliation

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

type fakeLedgerSum struct{ debit, credit int64 }

type fakeRepo struct {
	payments  map[string]domain.Transaction
	accounts  map[string]pgrepo.AccountSnapshot
	ceilings  map[string]pgrepo.CeilingSnapshot
	ledger    map[string]fakeLedgerSum       // by account_id
	ceilSum   map[string]int64               // by ceiling_id
	runs      []domain.ReconciliationRecord
}

func newFakeRepo() *fakeRepo {
	return &fakeRepo{
		payments: map[string]domain.Transaction{},
		accounts: map[string]pgrepo.AccountSnapshot{},
		ceilings: map[string]pgrepo.CeilingSnapshot{},
		ledger:   map[string]fakeLedgerSum{},
		ceilSum:  map[string]int64{},
	}
}

func (f *fakeRepo) ListSettledTxnsForPayer(_ context.Context, userID string) ([]domain.Transaction, error) {
	var out []domain.Transaction
	for _, t := range f.payments {
		if t.PayerID == userID && (t.Status == domain.TxSettled || t.Status == domain.TxPartiallySettled) {
			out = append(out, t)
		}
	}
	return out, nil
}

func (f *fakeRepo) ListSettledTxnsForReceiver(_ context.Context, userID string) ([]domain.Transaction, error) {
	var out []domain.Transaction
	for _, t := range f.payments {
		if t.PayeeID == userID && (t.Status == domain.TxSettled || t.Status == domain.TxPartiallySettled) {
			out = append(out, t)
		}
	}
	return out, nil
}

func (f *fakeRepo) GetPayment(_ context.Context, id string) (domain.Transaction, error) {
	t, ok := f.payments[id]
	if !ok {
		return domain.Transaction{}, ErrNoRows
	}
	return t, nil
}

func (f *fakeRepo) ListPaymentsByBatch(_ context.Context, batchID string) ([]domain.Transaction, error) {
	var out []domain.Transaction
	for _, t := range f.payments {
		if t.SettlementBatchID != nil && *t.SettlementBatchID == batchID {
			out = append(out, t)
		}
	}
	return out, nil
}

func (f *fakeRepo) ListAllAccounts(_ context.Context) ([]pgrepo.AccountSnapshot, error) {
	out := make([]pgrepo.AccountSnapshot, 0, len(f.accounts))
	for _, a := range f.accounts {
		out = append(out, a)
	}
	return out, nil
}

func (f *fakeRepo) ListAllCeilings(_ context.Context) ([]pgrepo.CeilingSnapshot, error) {
	out := make([]pgrepo.CeilingSnapshot, 0, len(f.ceilings))
	for _, c := range f.ceilings {
		out = append(out, c)
	}
	return out, nil
}

func (f *fakeRepo) AccountLedgerSum(_ context.Context, accountID string) (int64, int64, error) {
	s := f.ledger[accountID]
	return s.debit, s.credit, nil
}

func (f *fakeRepo) SettledTotalForCeiling(_ context.Context, ceilingID string) (int64, error) {
	return f.ceilSum[ceilingID], nil
}

func (f *fakeRepo) InsertReconciliationRun(_ context.Context, rec domain.ReconciliationRecord) (domain.ReconciliationRecord, error) {
	if rec.ID == "" {
		rec.ID = fmt.Sprintf("run-%d", len(f.runs)+1)
	}
	rec.CreatedAt = time.Now().UTC()
	f.runs = append(f.runs, rec)
	return rec, nil
}

type recFraud struct{ events []domain.FraudEvent }

func (r *recFraud) Record(_ context.Context, ev domain.FraudEvent) {
	r.events = append(r.events, ev)
}

type fixedClock struct{ t time.Time }

func (c fixedClock) Now() time.Time { return c.t }

func newSvc(t *testing.T) (*Service, *fakeRepo, *recFraud) {
	t.Helper()
	r := newFakeRepo()
	fr := &recFraud{}
	svc := &Service{
		Repo:  r,
		Clock: fixedClock{t: time.Date(2026, 4, 13, 0, 0, 0, 0, time.UTC)},
		Fraud: fr,
		NewID: func() string { return "rec-1" },
	}
	return svc, r, fr
}

func seedTxn(r *fakeRepo, id, payer, payee string, amount, settled int64, seq int64, status domain.TransactionStatus, batchID string) domain.Transaction {
	t := domain.Transaction{
		ID: id, PayerID: payer, PayeeID: payee,
		Amount: amount, SettledAmount: settled,
		SequenceNumber: seq, Status: status,
	}
	if batchID != "" {
		b := batchID
		t.SettlementBatchID = &b
	}
	r.payments[id] = t
	return t
}

func TestSyncUser_CleanMatch_NoDiscrepancies(t *testing.T) {
	svc, r, _ := newSvc(t)
	seedTxn(r, "tx-1", "alice", "bob", 1_000, 1_000, 1, domain.TxSettled, "b1")

	log := []ClientTxnEntry{{
		TransactionID: "tx-1", PayerID: "alice", PayeeID: "bob",
		Amount: 1_000, SequenceNumber: 1, Status: domain.TxSettled,
	}}

	res, err := svc.SyncUser(context.Background(), "alice", log, nil)
	if err != nil {
		t.Fatalf("SyncUser: %v", err)
	}
	if len(res.Discrepancies) != 0 {
		t.Fatalf("want 0 discrepancies, got %+v", res.Discrepancies)
	}
	if len(res.PayerSide) != 1 {
		t.Fatalf("want 1 payer-side txn, got %d", len(res.PayerSide))
	}
}

func TestSyncUser_MissingFromClient(t *testing.T) {
	svc, r, _ := newSvc(t)
	seedTxn(r, "tx-1", "alice", "bob", 500, 500, 1, domain.TxSettled, "b1")
	seedTxn(r, "tx-2", "alice", "carol", 700, 700, 2, domain.TxSettled, "b1")

	// Client only reports tx-1.
	log := []ClientTxnEntry{{
		TransactionID: "tx-1", PayerID: "alice", PayeeID: "bob",
		Amount: 500, SequenceNumber: 1, Status: domain.TxSettled,
	}}

	res, err := svc.SyncUser(context.Background(), "alice", log, nil)
	if err != nil {
		t.Fatalf("SyncUser: %v", err)
	}
	if len(res.Discrepancies) != 1 {
		t.Fatalf("want 1 discrepancy, got %d: %+v", len(res.Discrepancies), res.Discrepancies)
	}
	d := res.Discrepancies[0]
	if d.TransactionID != "tx-2" || d.Field != "existence" || d.Actual != "missing" {
		t.Errorf("unexpected discrepancy: %+v", d)
	}
}

func TestSyncUser_AmountMismatch(t *testing.T) {
	svc, r, _ := newSvc(t)
	seedTxn(r, "tx-1", "alice", "bob", 1_000, 1_000, 1, domain.TxSettled, "b1")

	log := []ClientTxnEntry{{
		TransactionID: "tx-1", PayerID: "alice", PayeeID: "bob",
		Amount: 999, SequenceNumber: 1, Status: domain.TxSettled,
	}}

	res, err := svc.SyncUser(context.Background(), "alice", log, nil)
	if err != nil {
		t.Fatalf("SyncUser: %v", err)
	}
	if len(res.Discrepancies) != 1 {
		t.Fatalf("want 1 discrepancy, got %+v", res.Discrepancies)
	}
	d := res.Discrepancies[0]
	if d.Field != "amount" || d.Expected != "1000" || d.Actual != "999" {
		t.Errorf("unexpected discrepancy: %+v", d)
	}
}

func TestSyncUser_Disputed_RecordsFraud(t *testing.T) {
	svc, r, fr := newSvc(t)
	seedTxn(r, "tx-1", "alice", "bob", 1_000, 1_000, 1, domain.TxSettled, "b1")

	_, err := svc.SyncUser(context.Background(), "alice", nil, []string{"tx-1"})
	if err != nil {
		t.Fatalf("SyncUser: %v", err)
	}
	if len(fr.events) != 1 {
		t.Fatalf("want 1 fraud event, got %d", len(fr.events))
	}
	ev := fr.events[0]
	if ev.SignalType != domain.FraudGeographicAnomaly {
		t.Errorf("signal type = %s, want GEOGRAPHIC_ANOMALY", ev.SignalType)
	}
	if ev.TransactionID == nil || *ev.TransactionID != "tx-1" {
		t.Errorf("transaction id not propagated: %+v", ev.TransactionID)
	}
	if ev.UserID != "alice" {
		t.Errorf("user id = %s", ev.UserID)
	}
}

func TestSyncUser_PayerReceiverSymmetry(t *testing.T) {
	svc, r, _ := newSvc(t)
	seedTxn(r, "tx-1", "alice", "bob", 1_234, 1_234, 1, domain.TxSettled, "b1")

	payer, err := svc.SyncUser(context.Background(), "alice", nil, nil)
	if err != nil {
		t.Fatalf("alice sync: %v", err)
	}
	receiver, err := svc.SyncUser(context.Background(), "bob", nil, nil)
	if err != nil {
		t.Fatalf("bob sync: %v", err)
	}
	if len(payer.PayerSide) != 1 || len(receiver.ReceiverSide) != 1 {
		t.Fatalf("payer view %d / receiver view %d", len(payer.PayerSide), len(receiver.ReceiverSide))
	}
	p := payer.PayerSide[0]
	r2 := receiver.ReceiverSide[0]
	if p.ID != r2.ID || p.Amount != r2.Amount || p.SettledAmount != r2.SettledAmount || p.Status != r2.Status {
		t.Errorf("payer vs receiver views disagree: %+v vs %+v", p, r2)
	}
}

func seedBalancedAccount(r *fakeRepo, userID string, kind sqlcgen.AccountKind, credit, debit int64) {
	id := fmt.Sprintf("acct-%s-%s", userID, kind)
	r.accounts[id] = pgrepo.AccountSnapshot{
		ID: id, UserID: userID, Kind: kind, Balance: credit - debit,
	}
	r.ledger[id] = fakeLedgerSum{debit: debit, credit: credit}
}

func TestNightlyLedger_Clean(t *testing.T) {
	svc, r, _ := newSvc(t)
	seedBalancedAccount(r, "alice", sqlcgen.AccountKindMain, 10_000, 3_000)
	seedBalancedAccount(r, "alice", sqlcgen.AccountKindLienHolding, 3_000, 0)
	seedBalancedAccount(r, "bob", sqlcgen.AccountKindMain, 3_000, 0)
	r.ceilings["ceil-1"] = pgrepo.CeilingSnapshot{
		ID: "ceil-1", PayerUserID: "alice", CeilingAmount: 5_000, Status: domain.CeilingActive,
	}
	r.ceilSum["ceil-1"] = 3_000

	rec, err := svc.NightlyLedgerReconcile(context.Background())
	if err != nil {
		t.Fatalf("nightly: %v", err)
	}
	if rec.Status != domain.ReconClean {
		t.Fatalf("status = %s want CLEAN, discrepancies=%+v", rec.Status, rec.Discrepancies)
	}
	if len(r.runs) != 1 || r.runs[0].Type != domain.ReconLedger {
		t.Errorf("run not persisted: %+v", r.runs)
	}
}

func TestNightlyLedger_AccountImbalance(t *testing.T) {
	svc, r, _ := newSvc(t)
	// Stored balance 500 but ledger says credit-debit = 1000 - 200 = 800.
	id := "acct-bad"
	r.accounts[id] = pgrepo.AccountSnapshot{ID: id, UserID: "u", Kind: sqlcgen.AccountKindMain, Balance: 500}
	r.ledger[id] = fakeLedgerSum{debit: 200, credit: 1_000}

	rec, err := svc.NightlyLedgerReconcile(context.Background())
	if err != nil {
		t.Fatalf("nightly: %v", err)
	}
	if rec.Status != domain.ReconDiscrepancy {
		t.Fatalf("want DISCREPANCY, got %s", rec.Status)
	}
	if len(rec.Discrepancies) != 1 {
		t.Fatalf("want 1 discrepancy, got %+v", rec.Discrepancies)
	}
	d := rec.Discrepancies[0]
	if d.Expected != "800" || d.Actual != "500" {
		t.Errorf("bad discrepancy values: %+v", d)
	}
}

func TestNightlyLedger_CeilingOverdraw(t *testing.T) {
	svc, r, _ := newSvc(t)
	// Clean account side.
	seedBalancedAccount(r, "alice", sqlcgen.AccountKindMain, 0, 0)
	// Ceiling sum exceeds ceiling amount.
	r.ceilings["ceil-evil"] = pgrepo.CeilingSnapshot{
		ID: "ceil-evil", PayerUserID: "alice", CeilingAmount: 1_000, Status: domain.CeilingExhausted,
	}
	r.ceilSum["ceil-evil"] = 1_500

	rec, err := svc.NightlyLedgerReconcile(context.Background())
	if err != nil {
		t.Fatalf("nightly: %v", err)
	}
	if rec.Status != domain.ReconDiscrepancy {
		t.Fatalf("want DISCREPANCY, got %s", rec.Status)
	}
	found := false
	for _, d := range rec.Discrepancies {
		if d.Field == "ceiling_overdraw:ceil-evil" && d.Actual == "1500" {
			found = true
		}
	}
	if !found {
		t.Errorf("missing ceiling_overdraw discrepancy: %+v", rec.Discrepancies)
	}
}

func TestBatchReceipt_Found(t *testing.T) {
	svc, r, _ := newSvc(t)
	now := time.Now().UTC()
	t1 := seedTxn(r, "tx-1", "alice", "bob", 1_000, 1_000, 1, domain.TxSettled, "b1")
	t1.SubmittedAt = &now
	t1.SettledAt = &now
	r.payments["tx-1"] = t1
	seedTxn(r, "tx-2", "alice", "bob", 2_000, 1_500, 2, domain.TxPartiallySettled, "b1")

	batch, results, err := svc.BatchReceipt(context.Background(), "b1")
	if err != nil {
		t.Fatalf("BatchReceipt: %v", err)
	}
	if batch.ID != "b1" || batch.TotalSubmitted != 2 || batch.TotalSettled != 1 || batch.TotalPartial != 1 {
		t.Errorf("batch totals wrong: %+v", batch)
	}
	if batch.TotalAmount != 2_500 {
		t.Errorf("total amount = %d want 2500", batch.TotalAmount)
	}
	if len(results) != 2 {
		t.Errorf("results len = %d", len(results))
	}
}

func TestBatchReceipt_NotFound(t *testing.T) {
	svc, _, _ := newSvc(t)
	_, _, err := svc.BatchReceipt(context.Background(), "nope")
	if err != ErrNoSuchBatch {
		t.Errorf("want ErrNoSuchBatch, got %v", err)
	}
}
