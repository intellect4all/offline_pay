package wallet

import (
	"context"
	"crypto/ed25519"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/intellect/offlinepay/internal/crypto"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

type fakeAccount struct {
	id      string
	userID  string
	kind    sqlcgen.AccountKind
	balance int64
}

type fakePayment struct {
	id        string
	ceilingID string
	state     domain.TransactionStatus
	// settledKobo models payment_tokens.settled_amount_kobo — used by
	// SumSettledForCeiling so releaseCeiling tests can simulate partial
	// settlements. Zero for in-flight states.
	settledKobo int64
}

type fakeRepo struct {
	mu           sync.Mutex
	accounts     map[string]*fakeAccount // by id
	acctByUK     map[string]*fakeAccount // by userID|kind
	userPubkey   map[string][]byte
	activeBank   domain.BankSigningKey
	ceilings     map[string]*domain.CeilingToken // by id
	activeByUser map[string]string               // userID -> active ceiling id
	payments     []fakePayment
	ledgerTxns   []string
	nextID       int
	// staging for tx
	inTx bool
}

func newFakeRepo() *fakeRepo {
	return &fakeRepo{
		accounts:     map[string]*fakeAccount{},
		acctByUK:     map[string]*fakeAccount{},
		userPubkey:   map[string][]byte{},
		ceilings:     map[string]*domain.CeilingToken{},
		activeByUser: map[string]string{},
	}
}

func uk(userID string, kind sqlcgen.AccountKind) string {
	return userID + "|" + string(kind)
}

func (f *fakeRepo) seedUser(userID string, mainBal int64, pub []byte) {
	for _, k := range pgrepo.AllAccountKinds {
		id := fmt.Sprintf("acct-%s-%s", userID, k)
		bal := int64(0)
		if k == sqlcgen.AccountKindMain {
			bal = mainBal
		}
		a := &fakeAccount{id: id, userID: userID, kind: k, balance: bal}
		f.accounts[id] = a
		f.acctByUK[uk(userID, k)] = a
	}
	f.userPubkey[userID] = pub
}

func (f *fakeRepo) Tx(ctx context.Context, fn func(Repository) error) error {
	// Simple semantics: snapshot + rollback on error. Good enough for our
	// tests; concurrency is not exercised.
	f.mu.Lock()
	snap := f.snapshot()
	f.inTx = true
	f.mu.Unlock()

	err := fn(f)

	f.mu.Lock()
	f.inTx = false
	if err != nil {
		f.restore(snap)
	}
	f.mu.Unlock()
	return err
}

type fakeSnapshot struct {
	accounts     map[string]fakeAccount
	ceilings     map[string]domain.CeilingToken
	activeByUser map[string]string
	payments     []fakePayment
	ledgerTxns   []string
}

func (f *fakeRepo) snapshot() fakeSnapshot {
	acc := make(map[string]fakeAccount, len(f.accounts))
	for k, v := range f.accounts {
		acc[k] = *v
	}
	ce := make(map[string]domain.CeilingToken, len(f.ceilings))
	for k, v := range f.ceilings {
		ce[k] = *v
	}
	ab := make(map[string]string, len(f.activeByUser))
	for k, v := range f.activeByUser {
		ab[k] = v
	}
	pm := append([]fakePayment(nil), f.payments...)
	lg := append([]string(nil), f.ledgerTxns...)
	return fakeSnapshot{accounts: acc, ceilings: ce, activeByUser: ab, payments: pm, ledgerTxns: lg}
}

func (f *fakeRepo) restore(s fakeSnapshot) {
	f.accounts = map[string]*fakeAccount{}
	f.acctByUK = map[string]*fakeAccount{}
	for id, a := range s.accounts {
		a := a
		f.accounts[id] = &a
		f.acctByUK[uk(a.userID, a.kind)] = f.accounts[id]
	}
	f.ceilings = map[string]*domain.CeilingToken{}
	for id, c := range s.ceilings {
		c := c
		f.ceilings[id] = &c
	}
	f.activeByUser = s.activeByUser
	f.payments = s.payments
	f.ledgerTxns = s.ledgerTxns
}

func (f *fakeRepo) GetAccountID(_ context.Context, userID string, kind sqlcgen.AccountKind) (string, error) {
	a, ok := f.acctByUK[uk(userID, kind)]
	if !ok {
		return "", ErrNoRows
	}
	return a.id, nil
}

func (f *fakeRepo) GetAccountBalance(_ context.Context, userID string, kind sqlcgen.AccountKind) (int64, error) {
	a, ok := f.acctByUK[uk(userID, kind)]
	if !ok {
		return 0, ErrNoRows
	}
	return a.balance, nil
}

func (f *fakeRepo) DebitAccount(_ context.Context, accountID string, amount int64) error {
	a, ok := f.accounts[accountID]
	if !ok {
		return ErrNoRows
	}
	if a.balance < amount {
		return errors.New("fake: insufficient funds")
	}
	a.balance -= amount
	return nil
}

func (f *fakeRepo) CreditAccount(_ context.Context, accountID string, amount int64) error {
	a, ok := f.accounts[accountID]
	if !ok {
		return ErrNoRows
	}
	a.balance += amount
	return nil
}

func (f *fakeRepo) PostLedger(_ context.Context, txnID string, legs []pgrepo.LedgerLeg) error {
	if len(legs) < 2 {
		return errors.New("fake: need 2 legs")
	}
	var deb, cred int64
	for _, l := range legs {
		switch l.Direction {
		case "DEBIT":
			deb += l.Amount
		case "CREDIT":
			cred += l.Amount
		default:
			return fmt.Errorf("fake: bad dir %s", l.Direction)
		}
	}
	if deb != cred {
		return errors.New("fake: unbalanced ledger")
	}
	f.ledgerTxns = append(f.ledgerTxns, txnID)
	return nil
}

func (f *fakeRepo) GetUserPayerPubkey(_ context.Context, userID string) ([]byte, error) {
	pk, ok := f.userPubkey[userID]
	if !ok {
		return nil, ErrNoRows
	}
	return pk, nil
}

func (f *fakeRepo) GetActiveCeiling(_ context.Context, userID string) (domain.CeilingToken, error) {
	id, ok := f.activeByUser[userID]
	if !ok {
		return domain.CeilingToken{}, ErrNoRows
	}
	c := f.ceilings[id]
	return *c, nil
}

func (f *fakeRepo) GetActiveBankSigningKey(_ context.Context) (domain.BankSigningKey, error) {
	return f.activeBank, nil
}

func (f *fakeRepo) IssueCeilingToken(_ context.Context, p pgrepo.IssueCeilingParams) (domain.CeilingToken, error) {
	if _, dup := f.activeByUser[p.PayerUserID]; dup {
		return domain.CeilingToken{}, errors.New("fake: unique violation: one active per user")
	}
	c := domain.CeilingToken{
		ID:             p.ID,
		PayerID:        p.PayerUserID,
		CeilingAmount:  p.CeilingAmount,
		IssuedAt:       p.IssuedAt,
		ExpiresAt:      p.ExpiresAt,
		SequenceStart:  p.SequenceStart,
		NextSequence:   p.SequenceStart + 1,
		PayerPublicKey: p.PayerPublicKey,
		BankKeyID:      p.BankKeyID,
		BankSignature:  p.BankSignature,
		Status:         domain.CeilingActive,
		CreatedAt:      p.IssuedAt,
	}
	f.ceilings[p.ID] = &c
	f.activeByUser[p.PayerUserID] = p.ID
	return c, nil
}

func (f *fakeRepo) UpdateCeilingStatus(_ context.Context, id string, status domain.CeilingStatus) error {
	c, ok := f.ceilings[id]
	if !ok {
		return ErrNoRows
	}
	c.Status = status
	if status != domain.CeilingActive && status != domain.CeilingRecoveryPending {
		delete(f.activeByUser, c.PayerID)
	}
	return nil
}

func (f *fakeRepo) MarkCeilingRecoveryPending(_ context.Context, id string, releaseAfter time.Time) (int64, error) {
	c, ok := f.ceilings[id]
	if !ok {
		return 0, ErrNoRows
	}
	if c.Status != domain.CeilingActive {
		return 0, nil
	}
	c.Status = domain.CeilingRecoveryPending
	r := releaseAfter
	c.ReleaseAfter = &r
	// Keep activeByUser pointing at the row — RECOVERY_PENDING still
	// occupies the single-live-ceiling slot per the partial unique index.
	return 1, nil
}

func (f *fakeRepo) ListReleasableExpiredCeilings(_ context.Context, before time.Time) ([]domain.CeilingToken, error) {
	out := []domain.CeilingToken{}
	for _, c := range f.ceilings {
		eligible := false
		switch c.Status {
		case domain.CeilingActive:
			eligible = c.ExpiresAt.Before(before)
		case domain.CeilingRecoveryPending:
			eligible = c.ReleaseAfter != nil && c.ReleaseAfter.Before(before)
		}
		if !eligible {
			continue
		}
		inflight := 0
		for _, p := range f.payments {
			if p.ceilingID == c.ID && (p.state == domain.TxPending || p.state == domain.TxSubmitted) {
				inflight++
			}
		}
		if inflight > 0 {
			continue
		}
		out = append(out, *c)
	}
	return out, nil
}

func (f *fakeRepo) CountInFlightPaymentsForCeiling(_ context.Context, ceilingID string) (int64, error) {
	var n int64
	for _, p := range f.payments {
		if p.ceilingID == ceilingID && (p.state == domain.TxPending || p.state == domain.TxSubmitted) {
			n++
		}
	}
	return n, nil
}

func (f *fakeRepo) SumSettledForCeiling(_ context.Context, ceilingID string) (int64, error) {
	var sum int64
	for _, p := range f.payments {
		if p.ceilingID == ceilingID {
			sum += p.settledKobo
		}
	}
	return sum, nil
}

func (f *fakeRepo) GetCurrentCeilingForPayer(_ context.Context, userID string) (*pgrepo.CurrentCeilingRow, error) {
	// Pick the newest non-terminal ceiling for the user, mirroring the
	// SQL query's ORDER BY issued_at DESC LIMIT 1. Ties broken by map
	// iteration order, which is good enough for unit tests; the real
	// query is deterministic.
	var best *domain.CeilingToken
	for _, c := range f.ceilings {
		if c.PayerID != userID {
			continue
		}
		if c.Status != domain.CeilingActive && c.Status != domain.CeilingRecoveryPending {
			continue
		}
		if best == nil || c.IssuedAt.After(best.IssuedAt) {
			best = c
		}
	}
	if best == nil {
		return nil, nil
	}
	var settled int64
	for _, p := range f.payments {
		if p.ceilingID == best.ID {
			settled += p.settledKobo
		}
	}
	return &pgrepo.CurrentCeilingRow{
		ID:            best.ID,
		Status:        best.Status,
		CeilingKobo:   best.CeilingAmount,
		SettledKobo:   settled,
		RemainingKobo: best.CeilingAmount - settled,
		IssuedAt:      best.IssuedAt,
		ExpiresAt:     best.ExpiresAt,
		ReleaseAfter:  best.ReleaseAfter,
	}, nil
}

// RecordTransaction is a no-op for the wallet fake — tests only verify
// ledger / balance state, not the business-event log.
func (f *fakeRepo) RecordTransaction(_ context.Context, _ pgrepo.RecordTransactionParams) error {
	return nil
}

type fixedClock struct{ t time.Time }

func (c *fixedClock) Now() time.Time { return c.t }

func newService(t *testing.T) (*Service, *fakeRepo, domain.KeyPair) {
	t.Helper()
	bank, err := crypto.GenerateKeyPair()
	if err != nil {
		t.Fatalf("bank keypair: %v", err)
	}
	fr := newFakeRepo()
	fr.activeBank = domain.BankSigningKey{
		KeyID:      "bank-key-1",
		PublicKey:  bank.PublicKey,
		PrivateKey: bank.PrivateKey,
		ActiveFrom: time.Unix(0, 0),
	}
	clk := &fixedClock{t: time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC)}
	var idCounter int
	svc := &Service{
		Repo:       fr,
		Clock:      clk,
		SeqTracker: NoopSequenceTracker{},
		NewID: func() string {
			idCounter++
			return fmt.Sprintf("id-%04d", idCounter)
		},
	}
	return svc, fr, bank
}

func TestFundOffline_HappyPath(t *testing.T) {
	svc, fr, bank := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)

	ct, err := svc.FundOffline(context.Background(), "u1", 5_000_00, time.Hour)
	if err != nil {
		t.Fatalf("FundOffline: %v", err)
	}
	if ct.Status != domain.CeilingActive {
		t.Errorf("status = %s, want ACTIVE", ct.Status)
	}
	if ct.CeilingAmount != 5_000_00 {
		t.Errorf("amount = %d", ct.CeilingAmount)
	}
	// balance shifted.
	if got := fr.accounts["acct-u1-main"].balance; got != 5_000_00 {
		t.Errorf("main = %d, want 500000", got)
	}
	if got := fr.accounts["acct-u1-lien_holding"].balance; got != 5_000_00 {
		t.Errorf("lien = %d, want 500000", got)
	}
	// signature verifies.
	payload := domain.CeilingTokenPayload{
		PayerID:        ct.PayerID,
		CeilingAmount:  ct.CeilingAmount,
		IssuedAt:       ct.IssuedAt,
		ExpiresAt:      ct.ExpiresAt,
		SequenceStart:  ct.SequenceStart,
		PayerPublicKey: ct.PayerPublicKey,
		BankKeyID:      ct.BankKeyID,
	}
	if err := crypto.VerifyCeiling(ed25519.PublicKey(bank.PublicKey), payload, ct.BankSignature); err != nil {
		t.Errorf("verify ceiling sig: %v", err)
	}
}

func TestFundOffline_RefusesWhenActiveExists(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)

	if _, err := svc.FundOffline(context.Background(), "u1", 1_000_00, time.Hour); err != nil {
		t.Fatalf("first fund: %v", err)
	}
	_, err := svc.FundOffline(context.Background(), "u1", 1_000_00, time.Hour)
	if !errors.Is(err, ErrActiveCeilingExists) {
		t.Errorf("err = %v, want ErrActiveCeilingExists", err)
	}
}

func TestFundOffline_InsufficientFunds(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 100, payerKP.PublicKey)
	_, err := svc.FundOffline(context.Background(), "u1", 1_000_00, time.Hour)
	if !errors.Is(err, ErrInsufficientFunds) {
		t.Errorf("err = %v, want ErrInsufficientFunds", err)
	}
}

func TestFundOffline_MissingPubkey(t *testing.T) {
	svc, fr, _ := newService(t)
	fr.seedUser("u1", 10_000_00, nil)
	_, err := svc.FundOffline(context.Background(), "u1", 1_000_00, time.Hour)
	if !errors.Is(err, ErrMissingPayerPubkey) {
		t.Errorf("err = %v, want ErrMissingPayerPubkey", err)
	}
}

func TestMoveToMain_RefusesWithUnsettledClaims(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	ct, err := svc.FundOffline(context.Background(), "u1", 5_000_00, time.Hour)
	if err != nil {
		t.Fatalf("fund: %v", err)
	}
	fr.payments = append(fr.payments, fakePayment{id: "p1", ceilingID: ct.ID, state: domain.TxPending})

	err = svc.MoveToMain(context.Background(), "u1")
	if !errors.Is(err, ErrUnsettledClaims) {
		t.Errorf("err = %v, want ErrUnsettledClaims", err)
	}
	// Balances must be unchanged.
	if got := fr.accounts["acct-u1-main"].balance; got != 5_000_00 {
		t.Errorf("main moved unexpectedly: %d", got)
	}
}

func TestMoveToMain_Success(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	if _, err := svc.FundOffline(context.Background(), "u1", 5_000_00, time.Hour); err != nil {
		t.Fatalf("fund: %v", err)
	}
	if err := svc.MoveToMain(context.Background(), "u1"); err != nil {
		t.Fatalf("move: %v", err)
	}
	if got := fr.accounts["acct-u1-main"].balance; got != 10_000_00 {
		t.Errorf("main = %d, want full restore", got)
	}
	if got := fr.accounts["acct-u1-lien_holding"].balance; got != 0 {
		t.Errorf("lien = %d, want 0", got)
	}
	if _, ok := fr.activeByUser["u1"]; ok {
		t.Errorf("active ceiling not cleared")
	}
}

func TestMoveToMain_NoActiveCeiling(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	err := svc.MoveToMain(context.Background(), "u1")
	if !errors.Is(err, ErrNoActiveCeiling) {
		t.Errorf("err = %v, want ErrNoActiveCeiling", err)
	}
}

func TestRefresh_Atomic(t *testing.T) {
	svc, fr, bank := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	if _, err := svc.FundOffline(context.Background(), "u1", 2_000_00, time.Hour); err != nil {
		t.Fatalf("fund: %v", err)
	}
	ct, err := svc.Refresh(context.Background(), "u1", 7_000_00, 2*time.Hour)
	if err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if ct.CeilingAmount != 7_000_00 {
		t.Errorf("new amount = %d", ct.CeilingAmount)
	}
	if got := fr.accounts["acct-u1-main"].balance; got != 10_000_00-7_000_00 {
		t.Errorf("main = %d", got)
	}
	// verify new signature with bank pub.
	payload := domain.CeilingTokenPayload{
		PayerID: ct.PayerID, CeilingAmount: ct.CeilingAmount,
		IssuedAt: ct.IssuedAt, ExpiresAt: ct.ExpiresAt,
		SequenceStart: ct.SequenceStart, PayerPublicKey: ct.PayerPublicKey,
		BankKeyID: ct.BankKeyID,
	}
	if err := crypto.VerifyCeiling(ed25519.PublicKey(bank.PublicKey), payload, ct.BankSignature); err != nil {
		t.Errorf("verify refreshed sig: %v", err)
	}
}

func TestReleaseOnExpiry(t *testing.T) {
	svc, fr, _ := newService(t)
	clk := svc.Clock.(*fixedClock)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	fr.seedUser("u2", 10_000_00, payerKP.PublicKey)

	ct1, err := svc.FundOffline(context.Background(), "u1", 3_000_00, 30*time.Minute)
	if err != nil {
		t.Fatalf("fund u1: %v", err)
	}
	_, err = svc.FundOffline(context.Background(), "u2", 4_000_00, 30*time.Minute)
	if err != nil {
		t.Fatalf("fund u2: %v", err)
	}

	// Advance past TTL + grace.
	clk.t = clk.t.Add(30*time.Minute + ReleaseGrace + time.Minute)

	// Attach an in-flight claim to u1 — it must NOT be swept.
	fr.payments = append(fr.payments, fakePayment{id: "p1", ceilingID: ct1.ID, state: domain.TxSubmitted})

	n, err := svc.ReleaseOnExpiry(context.Background())
	if err != nil {
		t.Fatalf("release: %v", err)
	}
	if n != 1 {
		t.Errorf("released = %d, want 1", n)
	}
	// u2 restored.
	if got := fr.accounts["acct-u2-main"].balance; got != 10_000_00 {
		t.Errorf("u2 main = %d", got)
	}
	// u1 still locked.
	if got := fr.accounts["acct-u1-lien_holding"].balance; got != 3_000_00 {
		t.Errorf("u1 lien = %d (should be held)", got)
	}

	// Idempotent: second run releases nothing new.
	n2, err := svc.ReleaseOnExpiry(context.Background())
	if err != nil {
		t.Fatalf("release 2: %v", err)
	}
	if n2 != 0 {
		t.Errorf("second sweep released %d, want 0", n2)
	}
}

func TestGetBalances(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	if _, err := svc.FundOffline(context.Background(), "u1", 3_000_00, time.Hour); err != nil {
		t.Fatalf("fund: %v", err)
	}
	b, err := svc.GetBalances(context.Background(), "u1")
	if err != nil {
		t.Fatalf("balances: %v", err)
	}
	if b.Main != 7_000_00 || b.LienHolding != 3_000_00 {
		t.Errorf("unexpected balances: %+v", b)
	}
}

func TestSequenceTrackerCalled(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	rec := &recordingTracker{}
	svc.SeqTracker = rec
	ct, err := svc.FundOffline(context.Background(), "u1", 1_000_00, time.Hour)
	if err != nil {
		t.Fatalf("fund: %v", err)
	}
	if len(rec.calls) != 1 || rec.calls[0].ceilingID != ct.ID {
		t.Errorf("tracker calls = %+v", rec.calls)
	}
}

type recordingTracker struct {
	calls []struct {
		userID    string
		ceilingID string
		seqStart  int64
	}
}

func (r *recordingTracker) RegisterCeiling(_ context.Context, userID, ceilingID string, seqStart int64) error {
	r.calls = append(r.calls, struct {
		userID    string
		ceilingID string
		seqStart  int64
	}{userID, ceilingID, seqStart})
	return nil
}

type fakeFraudGate struct {
	allowed int64
	tier    string
	err     error
}

func (f fakeFraudGate) ClampCeiling(_ context.Context, _ string, requested int64) (int64, string, error) {
	if f.err != nil {
		return 0, "", f.err
	}
	if f.allowed < 0 {
		return requested, f.tier, nil
	}
	if f.allowed < requested {
		return f.allowed, f.tier, nil
	}
	return requested, f.tier, nil
}

func TestFundOffline_FraudClampReduced(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	svc.Fraud = fakeFraudGate{allowed: 500_000, tier: "REDUCED"}

	ct, err := svc.FundOffline(context.Background(), "u1", 5_000_00, time.Hour)
	if err != nil {
		t.Fatalf("fund: %v", err)
	}
	if ct.CeilingAmount != 500_000 {
		t.Errorf("ceiling clamped to %d, want 500000", ct.CeilingAmount)
	}
}

func TestFundOffline_FraudClampStandardNoOp(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	svc.Fraud = fakeFraudGate{allowed: -1, tier: "STANDARD"}

	ct, err := svc.FundOffline(context.Background(), "u1", 3_000_00, time.Hour)
	if err != nil {
		t.Fatalf("fund: %v", err)
	}
	if ct.CeilingAmount != 3_000_00 {
		t.Errorf("ceiling = %d, want 300000", ct.CeilingAmount)
	}
}

func TestFundOffline_FraudSuspended(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	svc.Fraud = fakeFraudGate{allowed: 0, tier: "SUSPENDED"}

	_, err := svc.FundOffline(context.Background(), "u1", 1_000_00, time.Hour)
	if !errors.Is(err, ErrSuspended) {
		t.Fatalf("err = %v, want ErrSuspended", err)
	}
}

// fakeSigner captures calls from the wallet service so the test can
// assert FundOffline went through the injected signer path rather than
// the legacy local-priv-key path.
type fakeSigner struct {
	keyID string
	msgs  [][]byte
	priv  ed25519.PrivateKey
}

func (f *fakeSigner) Sign(_ context.Context, keyID string, msg []byte) ([]byte, error) {
	f.keyID = keyID
	f.msgs = append(f.msgs, append([]byte(nil), msg...))
	return ed25519.Sign(f.priv, msg), nil
}

func TestFundOffline_SignsViaSigner(t *testing.T) {
	svc, fr, bank := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)

	// Remove the private key from the bank row to prove the signer path
	// — not the legacy crypto.SignCeiling path — is doing the work.
	fr.activeBank.PrivateKey = nil

	signer := &fakeSigner{priv: bank.PrivateKey}
	svc.Signer = signer

	ct, err := svc.FundOffline(context.Background(), "u1", 1_000_00, time.Hour)
	if err != nil {
		t.Fatalf("FundOffline: %v", err)
	}
	if signer.keyID != "bank-key-1" {
		t.Fatalf("signer called with keyID=%q, want bank-key-1", signer.keyID)
	}
	if len(signer.msgs) != 1 {
		t.Fatalf("want 1 sign call, got %d", len(signer.msgs))
	}
	payload := domain.CeilingTokenPayload{
		PayerID:        ct.PayerID,
		CeilingAmount:  ct.CeilingAmount,
		IssuedAt:       ct.IssuedAt,
		ExpiresAt:      ct.ExpiresAt,
		SequenceStart:  ct.SequenceStart,
		PayerPublicKey: ct.PayerPublicKey,
		BankKeyID:      ct.BankKeyID,
	}
	if err := crypto.VerifyCeiling(ed25519.PublicKey(bank.PublicKey), payload, ct.BankSignature); err != nil {
		t.Fatalf("verify: %v", err)
	}
}

func TestRecoverOfflineCeiling_Success(t *testing.T) {
	svc, fr, _ := newService(t)
	svc.AutoSettleTimeout = 72 * time.Hour
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	ct, err := svc.FundOffline(context.Background(), "u1", 5_000_00, 24*time.Hour)
	if err != nil {
		t.Fatalf("fund: %v", err)
	}

	rec, err := svc.RecoverOfflineCeiling(context.Background(), "u1")
	if err != nil {
		t.Fatalf("recover: %v", err)
	}
	if rec.Status != domain.CeilingRecoveryPending {
		t.Fatalf("status = %s, want RECOVERY_PENDING", rec.Status)
	}
	if rec.ReleaseAfter == nil {
		t.Fatal("release_after not set")
	}
	expectedReleaseAfter := ct.ExpiresAt.Add(72 * time.Hour).Add(ReleaseGrace)
	if !rec.ReleaseAfter.Equal(expectedReleaseAfter) {
		t.Fatalf("release_after = %s, want %s", rec.ReleaseAfter, expectedReleaseAfter)
	}
	// Lien balance MUST still be locked — recovery doesn't move money.
	if got := fr.accounts["acct-u1-lien_holding"].balance; got != 5_000_00 {
		t.Fatalf("lien = %d, want 5_000_00 (lien stays locked during quarantine)", got)
	}
	if got := fr.accounts["acct-u1-main"].balance; got != 5_000_00 {
		t.Fatalf("main = %d, want 5_000_00 (unchanged)", got)
	}
}

func TestRecoverOfflineCeiling_RefusesWithUnsettledClaims(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	ct, err := svc.FundOffline(context.Background(), "u1", 5_000_00, 24*time.Hour)
	if err != nil {
		t.Fatalf("fund: %v", err)
	}
	fr.payments = append(fr.payments, fakePayment{id: "p1", ceilingID: ct.ID, state: domain.TxPending})

	_, err = svc.RecoverOfflineCeiling(context.Background(), "u1")
	if !errors.Is(err, ErrUnsettledClaims) {
		t.Fatalf("err = %v, want ErrUnsettledClaims", err)
	}
	// Ceiling must remain ACTIVE.
	if fr.ceilings[ct.ID].Status != domain.CeilingActive {
		t.Fatalf("ceiling flipped despite refused recovery: %s", fr.ceilings[ct.ID].Status)
	}
}

func TestRecoverOfflineCeiling_NoActive(t *testing.T) {
	svc, fr, _ := newService(t)
	fr.seedUser("u1", 10_000_00, nil)
	_, err := svc.RecoverOfflineCeiling(context.Background(), "u1")
	if !errors.Is(err, ErrNoActiveCeiling) {
		t.Fatalf("err = %v, want ErrNoActiveCeiling", err)
	}
}

func TestReleaseOnExpiry_ReleasesRecoveryPending(t *testing.T) {
	svc, fr, _ := newService(t)
	svc.AutoSettleTimeout = time.Hour
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	if _, err := svc.FundOffline(context.Background(), "u1", 5_000_00, time.Hour); err != nil {
		t.Fatalf("fund: %v", err)
	}
	rec, err := svc.RecoverOfflineCeiling(context.Background(), "u1")
	if err != nil {
		t.Fatalf("recover: %v", err)
	}

	// Before release_after: sweep is a no-op.
	svc.Clock.(*fixedClock).t = rec.ReleaseAfter.Add(-5 * time.Minute)
	n, err := svc.ReleaseOnExpiry(context.Background())
	if err != nil {
		t.Fatalf("sweep: %v", err)
	}
	if n != 0 {
		t.Fatalf("premature release: n=%d", n)
	}
	if got := fr.accounts["acct-u1-lien_holding"].balance; got != 5_000_00 {
		t.Fatalf("lien moved prematurely: %d", got)
	}

	// After release_after + grace: sweep releases.
	svc.Clock.(*fixedClock).t = rec.ReleaseAfter.Add(2 * ReleaseGrace)
	n, err = svc.ReleaseOnExpiry(context.Background())
	if err != nil {
		t.Fatalf("sweep: %v", err)
	}
	if n != 1 {
		t.Fatalf("released n=%d, want 1", n)
	}
	if got := fr.accounts["acct-u1-main"].balance; got != 10_000_00 {
		t.Fatalf("main = %d, want full restore", got)
	}
	if fr.ceilings[rec.ID].Status != domain.CeilingRevoked {
		t.Fatalf("terminal status = %s, want REVOKED", fr.ceilings[rec.ID].Status)
	}
}

// Tests for the B1 "release remaining, not full ceiling" fix.
//
// Before B1, releaseCeiling always tried to debit c.CeilingAmount.
// As soon as a partial settlement hit the lien, the balance guard on
// DecrementAccountBalance flipped the release into `pgx.ErrNoRows`,
// stranding the lien. After B1 we query SumSettledForCeiling and only
// move the remaining amount.
func TestReleaseOnExpiry_PartialSettled_ReleasesRemaining(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	ct, err := svc.FundOffline(context.Background(), "u1", 5_000_00, time.Hour)
	if err != nil {
		t.Fatalf("fund: %v", err)
	}

	// Simulate that settlement has already landed a 1,500.00 (150_000
	// kobo) payment against this ceiling: the lien account balance
	// mirrors that debit, and the payment_tokens row records the
	// settled amount. Status != PENDING/SUBMITTED so it doesn't block
	// ReleaseOnExpiry.
	const settled int64 = 150_000
	fr.accounts["acct-u1-lien_holding"].balance -= settled
	fr.payments = append(fr.payments, fakePayment{
		id:          "p-partial",
		ceilingID:   ct.ID,
		state:       domain.TxSettled,
		settledKobo: settled,
	})

	// Ceiling expires and the sweep runs past the grace window.
	svc.Clock.(*fixedClock).t = ct.ExpiresAt.Add(2 * ReleaseGrace)
	n, err := svc.ReleaseOnExpiry(context.Background())
	if err != nil {
		t.Fatalf("sweep: %v", err)
	}
	if n != 1 {
		t.Fatalf("released n=%d, want 1 (partial-settled ceiling should release the remainder)", n)
	}
	// Only the REMAINING lien (4,850.00 kobo) should have returned to
	// main; the 150_000 kobo that settled stays debited.
	const remaining = 5_000_00 - settled
	wantMain := int64(10_000_00) - 5_000_00 + remaining
	if got := fr.accounts["acct-u1-main"].balance; got != wantMain {
		t.Errorf("main = %d, want %d (original 10_000_00 - ceiling 5_000_00 + remaining %d)",
			got, wantMain, remaining)
	}
	if got := fr.accounts["acct-u1-lien_holding"].balance; got != 0 {
		t.Errorf("lien = %d, want 0", got)
	}
	if fr.ceilings[ct.ID].Status != domain.CeilingExpired {
		t.Errorf("terminal status = %s, want EXPIRED", fr.ceilings[ct.ID].Status)
	}
}

// Fully-spent ceiling: lien balance reached 0 via settlements before
// the sweep runs. releaseCeiling should still flip the status to
// terminal but MUST NOT call DebitAccount (would fail the balance
// guard on a zero-balance lien and return pgx.ErrNoRows).
func TestReleaseOnExpiry_FullySettled_FlipsStatusWithoutDebit(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	ct, err := svc.FundOffline(context.Background(), "u1", 2_000_00, time.Hour)
	if err != nil {
		t.Fatalf("fund: %v", err)
	}
	// Entire ceiling settled out.
	fr.accounts["acct-u1-lien_holding"].balance = 0
	fr.payments = append(fr.payments, fakePayment{
		id:          "p-full",
		ceilingID:   ct.ID,
		state:       domain.TxSettled,
		settledKobo: 2_000_00,
	})

	svc.Clock.(*fixedClock).t = ct.ExpiresAt.Add(2 * ReleaseGrace)
	n, err := svc.ReleaseOnExpiry(context.Background())
	if err != nil {
		t.Fatalf("sweep: %v", err)
	}
	if n != 1 {
		t.Fatalf("released n=%d, want 1 (status must still flip terminal)", n)
	}
	if got := fr.accounts["acct-u1-main"].balance; got != 10_000_00-2_000_00 {
		t.Errorf("main balance shifted unexpectedly: %d", got)
	}
	if fr.ceilings[ct.ID].Status != domain.CeilingExpired {
		t.Errorf("terminal status = %s, want EXPIRED", fr.ceilings[ct.ID].Status)
	}
}

// MoveToMain with partial settlement — same math, but the
// user-initiated path. Regression guard for the 502
// `move to main: wallet: debit lien: no rows in result set`
// we hit before B1.
func TestMoveToMain_PartialSettled_ReturnsRemaining(t *testing.T) {
	svc, fr, _ := newService(t)
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	ct, err := svc.FundOffline(context.Background(), "u1", 5_000_00, time.Hour)
	if err != nil {
		t.Fatalf("fund: %v", err)
	}
	const settled int64 = 50_000 // 500.00
	fr.accounts["acct-u1-lien_holding"].balance -= settled
	fr.payments = append(fr.payments, fakePayment{
		id:          "p-mtm",
		ceilingID:   ct.ID,
		state:       domain.TxSettled,
		settledKobo: settled,
	})

	if err := svc.MoveToMain(context.Background(), "u1"); err != nil {
		t.Fatalf("MoveToMain failed: %v", err)
	}
	// User funded 5M, 50k already settled, moved the remaining 4.95M back.
	wantMain := int64(10_000_00) - 5_000_00 + (5_000_00 - settled)
	if got := fr.accounts["acct-u1-main"].balance; got != wantMain {
		t.Errorf("main = %d, want %d", got, wantMain)
	}
	if got := fr.accounts["acct-u1-lien_holding"].balance; got != 0 {
		t.Errorf("lien = %d, want 0", got)
	}
	if fr.ceilings[ct.ID].Status != domain.CeilingRevoked {
		t.Errorf("terminal status = %s, want REVOKED", fr.ceilings[ct.ID].Status)
	}
}

func TestReleaseOnExpiry_RecoveryPending_InFlightBlocks(t *testing.T) {
	svc, fr, _ := newService(t)
	svc.AutoSettleTimeout = time.Hour
	payerKP, _ := crypto.GenerateKeyPair()
	fr.seedUser("u1", 10_000_00, payerKP.PublicKey)
	ct, err := svc.FundOffline(context.Background(), "u1", 5_000_00, time.Hour)
	if err != nil {
		t.Fatalf("fund: %v", err)
	}
	rec, err := svc.RecoverOfflineCeiling(context.Background(), "u1")
	if err != nil {
		t.Fatalf("recover: %v", err)
	}
	// A late claim landed on this ceiling between recovery and sweep.
	fr.payments = append(fr.payments, fakePayment{id: "p-late", ceilingID: ct.ID, state: domain.TxPending})

	svc.Clock.(*fixedClock).t = rec.ReleaseAfter.Add(2 * ReleaseGrace)
	n, err := svc.ReleaseOnExpiry(context.Background())
	if err != nil {
		t.Fatalf("sweep: %v", err)
	}
	if n != 0 {
		t.Fatalf("released despite in-flight: %d", n)
	}
	if got := fr.accounts["acct-u1-lien_holding"].balance; got != 5_000_00 {
		t.Fatalf("lien prematurely moved: %d", got)
	}
}
