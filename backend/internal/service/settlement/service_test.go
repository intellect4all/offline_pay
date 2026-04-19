package settlement

import (
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/json"
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
	balance int64 // may go negative for suspense
}

type fakeFinalizeOutboxRow struct {
	OutboxID    string
	PayerUserID string
	Payload     []byte
}

type fakeRepo struct {
	mu       sync.Mutex
	accounts map[string]*fakeAccount // by id
	acctByUK map[string]*fakeAccount // by userID|kind
	ceilings map[string]*domain.CeilingToken
	bankKeys map[string]domain.BankSigningKey
	payments map[string]*domain.Transaction
	paymentBySeq map[string]*domain.Transaction // "payer|seq"
	// submittedBy captures the submitted_by_user_id column the service wrote
	// via CreatePaymentParams.SubmittedByUserID, keyed by payment id. Used by
	// tests that assert either-party submission persists the submitter.
	submittedBy map[string]string
	ledgerTxns []string
	// Recorded outbox enqueues. Tests assert that SubmitClaim +
	// AutoSettleSweep + SyncUser(finalize=true) hand their finalize intent
	// to the outbox rather than calling FinalizeForPayer inline.
	finalizeOutbox []fakeFinalizeOutboxRow
}

func newFakeRepo() *fakeRepo {
	return &fakeRepo{
		accounts:     map[string]*fakeAccount{},
		acctByUK:     map[string]*fakeAccount{},
		ceilings:     map[string]*domain.CeilingToken{},
		bankKeys:     map[string]domain.BankSigningKey{},
		payments:     map[string]*domain.Transaction{},
		paymentBySeq: map[string]*domain.Transaction{},
	}
}

// InsertFinalizeOutbox records the enqueue for later assertions. The fake
// repo deliberately does not serialize or validate the payload — that's
// the service's job; we only care that exactly one row lands per accepted
// claim / sweep target.
func (f *fakeRepo) InsertFinalizeOutbox(_ context.Context, outboxID, payerUserID string, payload []byte) error {
	f.finalizeOutbox = append(f.finalizeOutbox, fakeFinalizeOutboxRow{
		OutboxID:    outboxID,
		PayerUserID: payerUserID,
		Payload:     append([]byte(nil), payload...),
	})
	return nil
}

// finalizeOutboxForPayer returns the recorded rows whose AggregateID
// matches payerUserID. Test-only convenience.
func (f *fakeRepo) finalizeOutboxForPayer(payerUserID string) []fakeFinalizeOutboxRow {
	out := make([]fakeFinalizeOutboxRow, 0)
	for _, r := range f.finalizeOutbox {
		if r.PayerUserID == payerUserID {
			out = append(out, r)
		}
	}
	return out
}

func uk(userID string, kind sqlcgen.AccountKind) string { return userID + "|" + string(kind) }
func seqKey(payer string, seq int64) string             { return fmt.Sprintf("%s|%d", payer, seq) }

func (f *fakeRepo) seedUser(userID string) {
	for _, k := range pgrepo.AllAccountKinds {
		id := fmt.Sprintf("acct-%s-%s", userID, k)
		a := &fakeAccount{id: id, userID: userID, kind: k}
		f.accounts[id] = a
		f.acctByUK[uk(userID, k)] = a
	}
}

func (f *fakeRepo) seedSuspense(id string) {
	a := &fakeAccount{id: id, userID: "system", kind: "suspense"}
	f.accounts[id] = a
}

func (f *fakeRepo) Tx(ctx context.Context, fn func(Repository) error) error {
	f.mu.Lock()
	snap := f.snapshot()
	f.mu.Unlock()
	err := fn(f)
	f.mu.Lock()
	if err != nil {
		f.restore(snap)
	}
	f.mu.Unlock()
	return err
}

type fakeSnap struct {
	accounts     map[string]fakeAccount
	ceilings     map[string]domain.CeilingToken
	payments     map[string]domain.Transaction
	paymentBySeq map[string]string // seq key -> payment id
	ledgerTxns   []string
}

func (f *fakeRepo) snapshot() fakeSnap {
	s := fakeSnap{
		accounts:     map[string]fakeAccount{},
		ceilings:     map[string]domain.CeilingToken{},
		payments:     map[string]domain.Transaction{},
		paymentBySeq: map[string]string{},
		ledgerTxns:   append([]string(nil), f.ledgerTxns...),
	}
	for k, v := range f.accounts {
		s.accounts[k] = *v
	}
	for k, v := range f.ceilings {
		s.ceilings[k] = *v
	}
	for k, v := range f.payments {
		s.payments[k] = *v
	}
	for k, v := range f.paymentBySeq {
		s.paymentBySeq[k] = v.ID
	}
	return s
}

func (f *fakeRepo) restore(s fakeSnap) {
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
	f.payments = map[string]*domain.Transaction{}
	f.paymentBySeq = map[string]*domain.Transaction{}
	for id, p := range s.payments {
		p := p
		f.payments[id] = &p
	}
	for k, id := range s.paymentBySeq {
		if p, ok := f.payments[id]; ok {
			f.paymentBySeq[k] = p
		}
	}
	f.ledgerTxns = s.ledgerTxns
}

func (f *fakeRepo) GetAccountID(_ context.Context, userID string, kind sqlcgen.AccountKind) (string, error) {
	a, ok := f.acctByUK[uk(userID, kind)]
	if !ok {
		return "", ErrNoRows
	}
	return a.id, nil
}

func (f *fakeRepo) DebitAccount(_ context.Context, accountID string, amount int64) error {
	a, ok := f.accounts[accountID]
	if !ok {
		return ErrNoRows
	}
	// Suspense can go negative; all other kinds cannot.
	if a.kind != "suspense" && a.balance < amount {
		return fmt.Errorf("fake: insufficient funds (kind=%s bal=%d need=%d)", a.kind, a.balance, amount)
	}
	a.balance -= amount
	return nil
}

func (f *fakeRepo) ForceDebitAccount(_ context.Context, accountID string, amount int64) error {
	a, ok := f.accounts[accountID]
	if !ok {
		return ErrNoRows
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
		return fmt.Errorf("fake: unbalanced ledger d=%d c=%d", deb, cred)
	}
	f.ledgerTxns = append(f.ledgerTxns, txnID)
	return nil
}

func (f *fakeRepo) GetCeilingToken(_ context.Context, id string) (domain.CeilingToken, error) {
	c, ok := f.ceilings[id]
	if !ok {
		return domain.CeilingToken{}, ErrNoRows
	}
	return *c, nil
}

func (f *fakeRepo) GetBankSigningKey(_ context.Context, keyID string) (domain.BankSigningKey, error) {
	k, ok := f.bankKeys[keyID]
	if !ok {
		return domain.BankSigningKey{}, ErrNoRows
	}
	return k, nil
}

func (f *fakeRepo) UpdateCeilingStatus(_ context.Context, id string, status domain.CeilingStatus) error {
	c, ok := f.ceilings[id]
	if !ok {
		return ErrNoRows
	}
	c.Status = status
	return nil
}

func (f *fakeRepo) GetPaymentBySequence(_ context.Context, payerUserID string, seq int64) (domain.Transaction, error) {
	p, ok := f.paymentBySeq[seqKey(payerUserID, seq)]
	if !ok {
		return domain.Transaction{}, ErrNoRows
	}
	return *p, nil
}

func (f *fakeRepo) CreatePayment(_ context.Context, p pgrepo.CreatePaymentParams) (domain.Transaction, error) {
	if _, dup := f.paymentBySeq[seqKey(p.PayerUserID, p.SequenceNumber)]; dup {
		return domain.Transaction{}, errors.New("fake: unique violation (payer,seq)")
	}
	t := domain.Transaction{
		ID:             p.ID,
		PayerID:        p.PayerUserID,
		PayeeID:        p.PayeeUserID,
		Amount:         p.Amount,
		SequenceNumber: p.SequenceNumber,
		CeilingTokenID: p.CeilingID,
		Status:         p.Status,
	}
	f.payments[p.ID] = &t
	f.paymentBySeq[seqKey(p.PayerUserID, p.SequenceNumber)] = &t
	if f.submittedBy == nil {
		f.submittedBy = map[string]string{}
	}
	f.submittedBy[p.ID] = p.SubmittedByUserID
	return t, nil
}

func (f *fakeRepo) ListPendingForPayer(_ context.Context, payerUserID string) ([]domain.Transaction, error) {
	var out []domain.Transaction
	for _, p := range f.payments {
		if p.PayerID == payerUserID && p.Status == domain.TxPending {
			out = append(out, *p)
		}
	}
	// sorted caller-side
	return out, nil
}

func (f *fakeRepo) UpdatePaymentStatus(_ context.Context, id string, state domain.TransactionStatus,
	settledAmount int64, rejectionReason string, batchID *string,
	submittedAt, settledAt *time.Time) (domain.Transaction, error) {
	p, ok := f.payments[id]
	if !ok {
		return domain.Transaction{}, ErrNoRows
	}
	p.Status = state
	p.SettledAmount = settledAmount
	if rejectionReason != "" {
		r := rejectionReason
		p.RejectionReason = &r
	}
	if batchID != nil {
		p.SettlementBatchID = batchID
	}
	if submittedAt != nil {
		t := *submittedAt
		p.SubmittedAt = &t
	}
	if settledAt != nil {
		t := *settledAt
		p.SettledAt = &t
	}
	return *p, nil
}

// RecordTransaction is a no-op in the settlement fake — tests only
// assert ledger and balance state, not the business-event log.
func (f *fakeRepo) RecordTransaction(_ context.Context, _ pgrepo.RecordTransactionParams) error {
	return nil
}

// GetTransactionAnchorForPayment returns a stable synthetic anchor so
// the production code path (which reuses anchor.ID as the Phase 4b
// ledger txn_id) keeps working. Tests don't assert on the value.
func (f *fakeRepo) GetTransactionAnchorForPayment(_ context.Context, paymentTokenID string) (pgrepo.TransactionAnchor, error) {
	return pgrepo.TransactionAnchor{ID: "anchor-" + paymentTokenID, GroupID: "group-" + paymentTokenID}, nil
}

func (f *fakeRepo) FinalizePairedTransactions(_ context.Context, _ string, _ domain.TransactionLifecycleStatus, _ *int64, _ *string) error {
	return nil
}

func (f *fakeRepo) ListPayersWithStalePending(_ context.Context, olderThan time.Time) ([]string, error) {
	seen := map[string]bool{}
	for _, p := range f.payments {
		if p.Status != domain.TxPending {
			continue
		}
		if p.SubmittedAt == nil || !p.SubmittedAt.Before(olderThan) {
			continue
		}
		seen[p.PayerID] = true
	}
	out := make([]string, 0, len(seen))
	for k := range seen {
		out = append(out, k)
	}
	return out, nil
}

type fixedClock struct{ t time.Time }

func (c *fixedClock) Now() time.Time { return c.t }

type recFraud struct{ events []domain.FraudEvent }

func (r *recFraud) Record(_ context.Context, ev domain.FraudEvent) {
	r.events = append(r.events, ev)
}

// recDetector records detector observations so tests can assert that
// FinalizeForPayer and SubmitClaim forward the right arguments.
type recDetector struct {
	settled []struct {
		user string
		at   time.Time
	}
	claims []struct {
		user, country string
		at            time.Time
	}
}

func (d *recDetector) ObserveSettled(_ context.Context, user string, at time.Time) {
	d.settled = append(d.settled, struct {
		user string
		at   time.Time
	}{user, at})
}

func (d *recDetector) ObserveClaim(_ context.Context, user, country string, at time.Time) {
	d.claims = append(d.claims, struct {
		user, country string
		at            time.Time
	}{user, country, at})
}

type harness struct {
	svc         *Service
	repo        *fakeRepo
	clock       *fixedClock
	fraud       *recFraud
	detector    *recDetector
	bankKP      domain.KeyPair
	receiverKPs map[string]domain.KeyPair
}

// receiverKeyPair lazily mints a device keypair per receiver so generated
// PaymentRequests sign with a stable key across a test.
func (h *harness) receiverKeyPair(t *testing.T, userID string) domain.KeyPair {
	t.Helper()
	if kp, ok := h.receiverKPs[userID]; ok {
		return kp
	}
	kp, err := crypto.GenerateKeyPair()
	if err != nil {
		t.Fatalf("receiver kp: %v", err)
	}
	h.receiverKPs[userID] = kp
	return kp
}

func newHarness(t *testing.T) *harness {
	t.Helper()
	bank, err := crypto.GenerateKeyPair()
	if err != nil {
		t.Fatalf("bank kp: %v", err)
	}
	fr := newFakeRepo()
	fr.bankKeys["bank-1"] = domain.BankSigningKey{
		KeyID: "bank-1", PublicKey: bank.PublicKey, PrivateKey: bank.PrivateKey,
		ActiveFrom: time.Unix(0, 0),
	}
	fr.seedSuspense(SystemSuspenseAccountID)
	clk := &fixedClock{t: time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC)}
	rf := &recFraud{}
	det := &recDetector{}
	idCounter := 0
	svc := &Service{
		Repo:              fr,
		Clock:             clk,
		Fraud:             rf,
		Detector:          det,
		NewID:             func() string { idCounter++; return fmt.Sprintf("id-%04d", idCounter) },
		ClockGrace:        DefaultClockGrace,
		AutoSettleTimeout: DefaultAutoSettleTimeout,
		SuspenseAccountID: SystemSuspenseAccountID,
	}
	return &harness{
		svc: svc, repo: fr, clock: clk, fraud: rf, detector: det, bankKP: bank,
		receiverKPs: map[string]domain.KeyPair{},
	}
}

// issueCeiling seeds a ceiling for payer with the given amount. Returns the
// domain ceiling (populated with valid bank signature) and the payer's
// keypair (caller signs payments with its private half).
func (h *harness) issueCeiling(t *testing.T, payer string, amount int64, expiresAt time.Time) (domain.CeilingToken, domain.KeyPair) {
	t.Helper()
	kp, err := crypto.GenerateKeyPair()
	if err != nil {
		t.Fatalf("payer kp: %v", err)
	}
	h.repo.seedUser(payer)
	// Seed lien balance to the ceiling amount (simulating fund).
	h.repo.accounts[fmt.Sprintf("acct-%s-lien_holding", payer)].balance = amount

	issuedAt := expiresAt.Add(-time.Hour)
	payload := domain.CeilingTokenPayload{
		PayerID:        payer,
		CeilingAmount:  amount,
		IssuedAt:       issuedAt,
		ExpiresAt:      expiresAt,
		SequenceStart:  0,
		PayerPublicKey: kp.PublicKey,
		BankKeyID:      "bank-1",
	}
	sig, err := crypto.SignCeiling(ed25519.PrivateKey(h.bankKP.PrivateKey), payload)
	if err != nil {
		t.Fatalf("sign ceiling: %v", err)
	}
	ct := domain.CeilingToken{
		ID:             "ceil-" + payer,
		PayerID:        payer,
		CeilingAmount:  amount,
		IssuedAt:       payload.IssuedAt,
		ExpiresAt:      payload.ExpiresAt,
		SequenceStart:  0,
		NextSequence:   1,
		PayerPublicKey: kp.PublicKey,
		BankKeyID:      "bank-1",
		BankSignature:  sig,
		Status:         domain.CeilingActive,
		CreatedAt:      payload.IssuedAt,
	}
	h.repo.ceilings[ct.ID] = &ct
	return ct, kp
}

// fakeSessionNonce is a deterministic nonce helper for tests that bypass
// signedClaim (e.g. the hand-built self-pay fixture).
func fakeSessionNonce(seed string) []byte {
	h := sha256.Sum256([]byte("nonce|" + seed))
	return h[:domain.SessionNonceSize]
}

// signedClaim builds a fully-bound ClaimItem with a strict amount binding:
// PR.amount == PT.amount == amount.
func (h *harness) signedClaim(t *testing.T, ct domain.CeilingToken, kp domain.KeyPair, payee string, amount, seq, remaining int64, ts time.Time) ClaimItem {
	return h.signedClaimWithAmounts(t, ct, kp, payee, amount, amount, seq, remaining, ts)
}

// signedClaimWithAmounts is the explicit-amount variant used by unbound-
// mode tests where the PR's amount (0 for unbound) differs from the PT's
// amount (the actual payment). For strict-bind tests use signedClaim.
func (h *harness) signedClaimWithAmounts(t *testing.T, ct domain.CeilingToken, kp domain.KeyPair, payee string, prAmount, ptAmount, seq, remaining int64, ts time.Time) ClaimItem {
	t.Helper()
	rkp := h.receiverKeyPair(t, payee)
	seed := fmt.Sprintf("%s|%s|%d", ct.PayerID, payee, seq)
	nonceSum := sha256.Sum256([]byte("nonce|" + seed))
	nonce := nonceSum[:domain.SessionNonceSize]

	// Display card signed by the active bank key.
	cardPayload := domain.DisplayCardPayload{
		UserID:        payee,
		DisplayName:   payee + " Demo",
		AccountNumber: "8000" + payee,
		IssuedAt:      ts.Add(-time.Hour),
		BankKeyID:     "bank-1",
	}
	cardSig, err := crypto.SignDisplayCard(ed25519.PrivateKey(h.bankKP.PrivateKey), cardPayload)
	if err != nil {
		t.Fatalf("sign display card: %v", err)
	}
	card := domain.DisplayCard{
		UserID:          cardPayload.UserID,
		DisplayName:     cardPayload.DisplayName,
		AccountNumber:   cardPayload.AccountNumber,
		IssuedAt:        cardPayload.IssuedAt,
		BankKeyID:       cardPayload.BankKeyID,
		ServerSignature: cardSig,
	}

	// Receiver-signed PaymentRequest. Expiry is generous (1h) so the
	// existing ceiling-grace test (PT signed 20min in the past) still has
	// a valid PR at submit time — PR expiry is orthogonal to ceiling grace.
	rPayload := domain.PaymentRequestPayload{
		ReceiverID:           payee,
		ReceiverDisplayCard:  card,
		Amount:               prAmount,
		SessionNonce:         nonce,
		IssuedAt:             ts.Add(-time.Minute),
		ExpiresAt:            ts.Add(time.Hour),
		ReceiverDevicePubkey: rkp.PublicKey,
	}
	rSig, err := crypto.SignRequest(ed25519.PrivateKey(rkp.PrivateKey), rPayload)
	if err != nil {
		t.Fatalf("sign request: %v", err)
	}
	req := domain.PaymentRequest{
		ReceiverID:           rPayload.ReceiverID,
		ReceiverDisplayCard:  rPayload.ReceiverDisplayCard,
		Amount:               rPayload.Amount,
		SessionNonce:         rPayload.SessionNonce,
		IssuedAt:             rPayload.IssuedAt,
		ExpiresAt:            rPayload.ExpiresAt,
		ReceiverDevicePubkey: rPayload.ReceiverDevicePubkey,
		ReceiverSignature:    rSig,
	}
	reqHash, err := crypto.HashRequest(req)
	if err != nil {
		t.Fatalf("hash request: %v", err)
	}

	pl := domain.PaymentPayload{
		PayerID: ct.PayerID, PayeeID: payee, Amount: ptAmount,
		SequenceNumber: seq, RemainingCeiling: remaining, Timestamp: ts,
		CeilingTokenID: ct.ID,
		SessionNonce:   nonce,
		RequestHash:    reqHash,
	}
	sig, err := crypto.SignPayment(ed25519.PrivateKey(kp.PrivateKey), pl)
	if err != nil {
		t.Fatalf("sign payment: %v", err)
	}
	pay := domain.PaymentToken{
		PayerID: pl.PayerID, PayeeID: pl.PayeeID, Amount: pl.Amount,
		SequenceNumber: pl.SequenceNumber, RemainingCeiling: pl.RemainingCeiling,
		Timestamp: pl.Timestamp, CeilingTokenID: pl.CeilingTokenID,
		SessionNonce:   pl.SessionNonce,
		RequestHash:    pl.RequestHash,
		PayerSignature: sig,
	}
	return ClaimItem{Payment: pay, Ceiling: ct, Request: req}
}

func TestSubmitClaim_HappyPath_ThenFinalize(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	pay := h.signedClaim(t, ct, kp, "bob", 3_000, 1, 7_000, h.clock.Now())
	batch, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay})
	if err != nil {
		t.Fatalf("SubmitClaim: %v", err)
	}
	if batch.Status != domain.BatchCompleted {
		t.Errorf("batch status = %s", batch.Status)
	}
	if len(results) != 1 || results[0].Status != domain.TxPending {
		t.Fatalf("results = %+v", results)
	}
	// Receiving pending credited, suspense went negative.
	if got := h.repo.accounts["acct-bob-receiving_pending"].balance; got != 3_000 {
		t.Errorf("bob pending = %d", got)
	}
	if got := h.repo.accounts[SystemSuspenseAccountID].balance; got != -3_000 {
		t.Errorf("suspense = %d want -3000", got)
	}

	// Finalize payer.
	fres, err := h.svc.FinalizeForPayer(context.Background(), "alice")
	if err != nil {
		t.Fatalf("Finalize: %v", err)
	}
	if len(fres) != 1 || fres[0].Status != domain.TxSettled || fres[0].SettledAmount != 3_000 {
		t.Fatalf("finalize results = %+v", fres)
	}
	// Balances net out. Phase 4b credits MAIN directly — no intermediate
	// receiving_available hop.
	if got := h.repo.accounts["acct-alice-lien_holding"].balance; got != 7_000 {
		t.Errorf("alice lien = %d want 7000", got)
	}
	if got := h.repo.accounts["acct-bob-receiving_pending"].balance; got != 0 {
		t.Errorf("bob pending = %d want 0", got)
	}
	if got := h.repo.accounts["acct-bob-main"].balance; got != 3_000 {
		t.Errorf("bob main = %d want 3000 (direct credit from Phase 4b)", got)
	}
	if got := h.repo.accounts[SystemSuspenseAccountID].balance; got != 0 {
		t.Errorf("suspense = %d want 0", got)
	}
}

// Payer-side submission: the payer reaches connectivity before the payee
// and drains their own QUEUED offline payment. Verifies that Phase 4a
// accepts the upload, credits the payee (not the submitter), and
// records submitted_by_user_id as the payer.
func TestSubmitClaim_PayerSubmitsOwnToken_ThenFinalize(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	pay := h.signedClaim(t, ct, kp, "bob", 3_000, 1, 7_000, h.clock.Now())
	// Submit as the payer ("alice"), not the payee ("bob").
	batch, results, err := h.svc.SubmitClaim(context.Background(), "alice", []ClaimItem{pay})
	if err != nil {
		t.Fatalf("SubmitClaim: %v", err)
	}
	if batch.Status != domain.BatchCompleted {
		t.Errorf("batch status = %s", batch.Status)
	}
	if len(results) != 1 || results[0].Status != domain.TxPending {
		t.Fatalf("results = %+v", results)
	}
	// Credited account is the payee's — not the submitter's.
	if got := h.repo.accounts["acct-bob-receiving_pending"].balance; got != 3_000 {
		t.Errorf("bob (payee) pending = %d want 3000", got)
	}
	// submitted_by_user_id column records who actually uploaded.
	var persistedSubmitter string
	for _, v := range h.repo.submittedBy {
		persistedSubmitter = v
	}
	if persistedSubmitter != "alice" {
		t.Errorf("submitted_by = %q want alice", persistedSubmitter)
	}

	// Finalize still works identically — Phase 4b doesn't care who triggered 4a.
	fres, err := h.svc.FinalizeForPayer(context.Background(), "alice")
	if err != nil {
		t.Fatalf("Finalize: %v", err)
	}
	if len(fres) != 1 || fres[0].Status != domain.TxSettled || fres[0].SettledAmount != 3_000 {
		t.Fatalf("finalize results = %+v", fres)
	}
	if got := h.repo.accounts["acct-bob-main"].balance; got != 3_000 {
		t.Errorf("bob main = %d want 3000", got)
	}
}

// When the opposite party submits a token already claimed by the first,
// the dedupe on (payer_user_id, sequence_number) returns the existing
// PENDING row idempotently — no double-credit, no error, both devices
// converge on the server's state.
func TestSubmitClaim_OppositePartyReplay_Idempotent(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 5_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")
	pay := h.signedClaim(t, ct, kp, "bob", 1_000, 1, 4_000, h.clock.Now())

	// Payer submits first.
	_, r1, err := h.svc.SubmitClaim(context.Background(), "alice", []ClaimItem{pay})
	if err != nil || r1[0].Status != domain.TxPending {
		t.Fatalf("alice first submit: err=%v results=%+v", err, r1)
	}
	// Payee submits the same transaction afterwards.
	_, r2, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay})
	if err != nil {
		t.Fatalf("bob replay: %v", err)
	}
	if r2[0].Status != domain.TxPending {
		t.Errorf("replay status = %s want PENDING (existing)", r2[0].Status)
	}
	if got := h.repo.accounts["acct-bob-receiving_pending"].balance; got != 1_000 {
		t.Errorf("bob pending double-credited: %d", got)
	}
	if got := h.repo.accounts[SystemSuspenseAccountID].balance; got != -1_000 {
		t.Errorf("suspense double-debited: %d", got)
	}
}

func TestSubmitClaim_TwoReceiversOverlap_PartialSettlement(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 5_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")
	h.repo.seedUser("carol")

	p1 := h.signedClaim(t, ct, kp, "bob", 3_000, 1, 2_000, h.clock.Now())
	// offline, carol's device doesn't know Bob already consumed seq=1 so it
	// reports remaining=2000 (from its own view); server trusts only the
	// ceiling + sequence order.
	p2 := h.signedClaim(t, ct, kp, "carol", 3_000, 2, 2_000, h.clock.Now())

	// Bob submits first.
	_, r1, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{p1})
	if err != nil {
		t.Fatalf("bob claim: %v", err)
	}
	if r1[0].Status != domain.TxPending {
		t.Fatalf("bob result: %+v", r1)
	}
	// Carol submits second.
	_, r2, err := h.svc.SubmitClaim(context.Background(), "carol", []ClaimItem{p2})
	if err != nil {
		// p2 has remaining=-1 which fails payload validate inside Sign;
		// but we signed it — verify-only path in service doesn't call
		// Validate on payload. Might still be OK.
		t.Fatalf("carol claim: %v", err)
	}
	if r2[0].Status != domain.TxPending {
		t.Fatalf("carol result: %+v", r2)
	}

	// Finalize — sequence order: bob seq=1 (3k) full, carol seq=2 (3k) shortfall 1k.
	fres, err := h.svc.FinalizeForPayer(context.Background(), "alice")
	if err != nil {
		t.Fatalf("finalize: %v", err)
	}
	if len(fres) != 2 {
		t.Fatalf("want 2 results, got %d: %+v", len(fres), fres)
	}
	var bobRes, carolRes domain.SettlementResult
	for _, r := range fres {
		if r.SequenceNumber == 1 {
			bobRes = r
		} else {
			carolRes = r
		}
	}
	if bobRes.Status != domain.TxSettled || bobRes.SettledAmount != 3_000 {
		t.Errorf("bob settled wrong: %+v", bobRes)
	}
	if carolRes.Status != domain.TxPartiallySettled || carolRes.SettledAmount != 2_000 {
		t.Errorf("carol partial wrong: %+v", carolRes)
	}
	// Ledger arithmetic: alice lien 0, bob main 3k, carol main 2k
	// (direct Phase 4b credit), suspense 0, pendings 0.
	if got := h.repo.accounts["acct-alice-lien_holding"].balance; got != 0 {
		t.Errorf("alice lien = %d want 0", got)
	}
	if got := h.repo.accounts["acct-bob-main"].balance; got != 3_000 {
		t.Errorf("bob main = %d want 3000", got)
	}
	if got := h.repo.accounts["acct-carol-main"].balance; got != 2_000 {
		t.Errorf("carol main = %d want 2000", got)
	}
	if got := h.repo.accounts["acct-bob-receiving_pending"].balance; got != 0 {
		t.Errorf("bob pending != 0: %d", got)
	}
	if got := h.repo.accounts["acct-carol-receiving_pending"].balance; got != 0 {
		t.Errorf("carol pending != 0: %d", got)
	}
	if got := h.repo.accounts[SystemSuspenseAccountID].balance; got != 0 {
		t.Errorf("suspense != 0: %d", got)
	}
	// Ceiling exhausted.
	if h.repo.ceilings[ct.ID].Status != domain.CeilingExhausted {
		t.Errorf("ceiling status = %s want EXHAUSTED", h.repo.ceilings[ct.ID].Status)
	}
}

func TestSubmitClaim_SelfPayRejected(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 5_000, h.clock.Now().Add(time.Hour))
	// Self-pay is now a structural property of the token (payer_id == payee_id),
	// independent of who submits. A token that pays itself is rejected before
	// any crypto checks. Zero-valued Request is fine — the structural check
	// fires first.
	seed := "alice|alice|1"
	nonce := fakeSessionNonce(seed)
	requestHash := fakeSessionNonce("hash|" + seed)
	requestHash = append(requestHash, fakeSessionNonce("hash|"+seed+"|2")...)
	pl := domain.PaymentPayload{
		PayerID: "alice", PayeeID: "alice", Amount: 100, SequenceNumber: 1,
		RemainingCeiling: 4_900, Timestamp: h.clock.Now(), CeilingTokenID: ct.ID,
		SessionNonce: nonce,
		RequestHash:  requestHash,
	}
	sig, _ := crypto.SignPayment(ed25519.PrivateKey(kp.PrivateKey), pl)
	pay := domain.PaymentToken{
		PayerID: "alice", PayeeID: "alice", Amount: 100,
		SequenceNumber: 1, RemainingCeiling: 4_900,
		Timestamp: pl.Timestamp, CeilingTokenID: ct.ID,
		SessionNonce: pl.SessionNonce, RequestHash: pl.RequestHash,
		PayerSignature: sig,
	}
	// Submitter "alice" is the payer — allowed to submit, but the token
	// itself pays alice → alice, so the structural self-pay check rejects.
	_, results, err := h.svc.SubmitClaim(context.Background(), "alice",
		[]ClaimItem{{Payment: pay, Ceiling: ct}})
	if err != nil {
		t.Fatalf("submit: %v", err)
	}
	if results[0].Status != domain.TxRejected || results[0].Reason != ErrSelfPay.Error() {
		t.Errorf("got %+v, want REJECTED/self-pay", results[0])
	}
}

func TestSubmitClaim_DuplicateIdempotent(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 5_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")
	pay := h.signedClaim(t, ct, kp, "bob", 1_000, 1, 4_000, h.clock.Now())
	_, _, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay})
	if err != nil {
		t.Fatalf("first submit: %v", err)
	}
	// Second submit of same (payer, seq).
	_, r2, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay})
	if err != nil {
		t.Fatalf("dup submit: %v", err)
	}
	if r2[0].Status != domain.TxPending {
		t.Errorf("dup status = %s want PENDING (existing)", r2[0].Status)
	}
	// Receiver pending not double-credited.
	if got := h.repo.accounts["acct-bob-receiving_pending"].balance; got != 1_000 {
		t.Errorf("bob pending double-credited: %d", got)
	}
	if got := h.repo.accounts[SystemSuspenseAccountID].balance; got != -1_000 {
		t.Errorf("suspense double-debited: %d", got)
	}
}

func TestSubmitClaim_ExpiredRejected_WithinGraceAccepted(t *testing.T) {
	h := newHarness(t)
	// Ceiling expired 10 minutes ago (inside 30-min grace).
	ct, kp := h.issueCeiling(t, "alice", 5_000, h.clock.Now().Add(-10*time.Minute))
	h.repo.seedUser("bob")
	pay := h.signedClaim(t, ct, kp, "bob", 1_000, 1, 4_000, h.clock.Now().Add(-20*time.Minute))
	_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay})
	if err != nil {
		t.Fatalf("submit: %v", err)
	}
	if results[0].Status != domain.TxPending {
		t.Errorf("within grace should accept, got %+v", results[0])
	}

	// Advance clock past grace; new payment seq=2.
	h.clock.t = h.clock.t.Add(40 * time.Minute)
	pay2 := h.signedClaim(t, ct, kp, "bob", 500, 2, 3_500, h.clock.Now())
	_, r2, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay2})
	if err != nil {
		t.Fatalf("submit2: %v", err)
	}
	if r2[0].Status != domain.TxRejected || r2[0].Reason != ErrCeilingExpired.Error() {
		t.Errorf("past grace should reject, got %+v", r2[0])
	}
}

func TestSubmitClaim_BadBankSignature_FraudEmitted(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 5_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")
	// Corrupt the bank signature.
	ct.BankSignature = append([]byte{}, ct.BankSignature...)
	ct.BankSignature[0] ^= 0xFF

	pay := h.signedClaim(t, ct, kp, "bob", 1_000, 1, 4_000, h.clock.Now())
	_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay})
	if err != nil {
		t.Fatalf("submit: %v", err)
	}
	if results[0].Status != domain.TxRejected || results[0].Reason != ErrBadBankSignature.Error() {
		t.Errorf("want bad-bank-sig rejection, got %+v", results[0])
	}
	if len(h.fraud.events) != 1 || h.fraud.events[0].SignalType != domain.FraudSignatureInvalid {
		t.Errorf("fraud not emitted: %+v", h.fraud.events)
	}
}

func TestSubmitClaim_SequenceBelowStartRejected(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 5_000, h.clock.Now().Add(time.Hour))
	// Force sequence_start to 5 so seq=3 is below.
	ct.SequenceStart = 5
	// Re-sign ceiling with modified sequence_start so bank sig still verifies.
	newPayload := domain.CeilingTokenPayload{
		PayerID: ct.PayerID, CeilingAmount: ct.CeilingAmount,
		IssuedAt: ct.IssuedAt, ExpiresAt: ct.ExpiresAt,
		SequenceStart: 5, PayerPublicKey: ct.PayerPublicKey,
		BankKeyID: ct.BankKeyID,
	}
	sig, _ := crypto.SignCeiling(ed25519.PrivateKey(h.bankKP.PrivateKey), newPayload)
	ct.BankSignature = sig
	h.repo.ceilings[ct.ID].SequenceStart = 5
	h.repo.ceilings[ct.ID].BankSignature = sig

	h.repo.seedUser("bob")
	pay := h.signedClaim(t, ct, kp, "bob", 1_000, 3, 4_000, h.clock.Now())
	_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay})
	if err != nil {
		t.Fatalf("submit: %v", err)
	}
	if results[0].Status != domain.TxRejected || results[0].Reason != ErrSequenceBelowStart.Error() {
		t.Errorf("want seq-below rejection, got %+v", results[0])
	}
}

func TestSubmitClaim_GeoObserved(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")
	pay := h.signedClaim(t, ct, kp, "bob", 1_000, 1, 9_000, h.clock.Now())

	_, _, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay}, WithSubmitterCountry("NG"))
	if err != nil {
		t.Fatalf("SubmitClaim: %v", err)
	}
	if len(h.detector.claims) != 1 {
		t.Fatalf("claims observed = %d want 1", len(h.detector.claims))
	}
	got := h.detector.claims[0]
	if got.user != "bob" || got.country != "NG" {
		t.Errorf("obs = %+v want bob/NG", got)
	}

	// No country header → no observation.
	h.detector.claims = nil
	pay2 := h.signedClaim(t, ct, kp, "bob", 1_000, 2, 8_000, h.clock.Now())
	if _, _, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay2}); err != nil {
		t.Fatalf("submit 2: %v", err)
	}
	if len(h.detector.claims) != 0 {
		t.Errorf("unexpected geo obs without country: %+v", h.detector.claims)
	}
}

func TestFinalizeForPayer_VelocityObserved(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	// Two settling txns + one that's zero-settle (ceiling exhaustion) must
	// produce exactly two velocity observations — zero-settled rows don't.
	pay1 := h.signedClaim(t, ct, kp, "bob", 4_000, 1, 6_000, h.clock.Now())
	pay2 := h.signedClaim(t, ct, kp, "bob", 6_000, 2, 0, h.clock.Now())
	pay3 := h.signedClaim(t, ct, kp, "bob", 500, 3, 0, h.clock.Now())
	for _, p := range []ClaimItem{pay1, pay2, pay3} {
		if _, _, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{p}); err != nil {
			t.Fatalf("submit seq=%d: %v", p.Payment.SequenceNumber, err)
		}
	}
	if _, err := h.svc.FinalizeForPayer(context.Background(), "alice"); err != nil {
		t.Fatalf("finalize: %v", err)
	}
	if got := len(h.detector.settled); got != 2 {
		t.Fatalf("settled observations = %d want 2", got)
	}
	for _, obs := range h.detector.settled {
		if obs.user != "alice" {
			t.Errorf("obs user = %s want alice", obs.user)
		}
	}
}

func TestAutoSettleSweep_EnqueuesFinalizeEventPerStalePayer(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 5_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")
	pay := h.signedClaim(t, ct, kp, "bob", 2_000, 1, 3_000, h.clock.Now())
	if _, _, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay}); err != nil {
		t.Fatalf("submit: %v", err)
	}
	// Record the starting outbox size so we can subtract the enqueues from
	// the SubmitClaim path and assert only the sweep's contribution.
	baseline := len(h.repo.finalizeOutbox)

	// Nothing stale yet.
	n, err := h.svc.AutoSettleSweep(context.Background())
	if err != nil {
		t.Fatalf("sweep: %v", err)
	}
	if n != 0 {
		t.Errorf("premature sweep: %d", n)
	}
	if got := len(h.repo.finalizeOutbox) - baseline; got != 0 {
		t.Errorf("premature sweep enqueued %d extra rows", got)
	}

	// Advance past timeout — sweep should now enqueue one finalize per
	// stale payer. Ledger doesn't move here; that's the worker's job.
	h.clock.t = h.clock.t.Add(DefaultAutoSettleTimeout + time.Hour)
	n, err = h.svc.AutoSettleSweep(context.Background())
	if err != nil {
		t.Fatalf("sweep: %v", err)
	}
	if n != 1 {
		t.Errorf("sweep enqueued %d want 1", n)
	}
	rows := h.repo.finalizeOutboxForPayer("alice")
	if len(rows) < 1 {
		t.Fatalf("sweep should enqueue a finalize row for alice; got none")
	}
	// The sweep-generated row should carry the sweep reason.
	var saw bool
	for _, r := range rows {
		var fp domain.FinalizePayerPayload
		if err := json.Unmarshal(r.Payload, &fp); err != nil {
			continue
		}
		if fp.Reason == domain.FinalizeReasonSweep {
			saw = true
			break
		}
	}
	if !saw {
		t.Errorf("no sweep-reason finalize payload in %+v", rows)
	}

	// Balances intentionally untouched — finalize work is the worker's.
	if got := h.repo.accounts["acct-bob-main"].balance; got != 0 {
		t.Errorf("sweep should not move funds itself, bob main = %d", got)
	}
}

// PaymentRequest binding tests close the security gap that motivated the PR
// protocol: a third-party scanner cannot hijack a QR addressed to someone
// else, and the payer cannot pay a different amount / a different receiver
// than what the PR declares.

func TestSubmitClaim_WrongSubmitterRejected(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")
	h.repo.seedUser("carol")

	// PR addressed to bob; carol is neither payer (alice) nor payee (bob).
	item := h.signedClaim(t, ct, kp, "bob", 1_000, 1, 9_000, h.clock.Now())
	_, results, err := h.svc.SubmitClaim(context.Background(), "carol", []ClaimItem{item})
	if err != nil {
		t.Fatalf("submit: %v", err)
	}
	if results[0].Status != domain.TxRejected || results[0].Reason != ErrSubmitterNotParty.Error() {
		t.Fatalf("want SubmitterNotParty, got %+v", results[0])
	}
}

func TestSubmitClaim_AmountMismatchRejected(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	item := h.signedClaim(t, ct, kp, "bob", 1_000, 1, 9_000, h.clock.Now())
	// Tamper: PR declared 1000, but rewrite PT.amount to 2000 and re-sign so
	// signature check passes — binding must still catch the mismatch.
	item.Payment.Amount = 2_000
	pl := domain.PaymentPayload{
		PayerID: item.Payment.PayerID, PayeeID: item.Payment.PayeeID,
		Amount: 2_000, SequenceNumber: item.Payment.SequenceNumber,
		RemainingCeiling: item.Payment.RemainingCeiling,
		Timestamp:        item.Payment.Timestamp,
		CeilingTokenID:   item.Payment.CeilingTokenID,
		SessionNonce:     item.Payment.SessionNonce,
		RequestHash:      item.Payment.RequestHash,
	}
	sig, err := crypto.SignPayment(ed25519.PrivateKey(kp.PrivateKey), pl)
	if err != nil {
		t.Fatal(err)
	}
	item.Payment.PayerSignature = sig

	_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{item})
	if err != nil {
		t.Fatalf("submit: %v", err)
	}
	if results[0].Status != domain.TxRejected || results[0].Reason != ErrRequestAmountMismatch.Error() {
		t.Fatalf("want RequestAmountMismatch, got %+v", results[0])
	}
}

func TestSubmitClaim_UnboundAmountAccepted(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	// PR with amount=0 (unbound P2P fallback); payer pays 1500 of their choice.
	item := h.signedClaimWithAmounts(t, ct, kp, "bob",
		domain.UnboundAmount, 1_500, 1, 8_500, h.clock.Now())
	_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{item})
	if err != nil {
		t.Fatalf("submit: %v", err)
	}
	if results[0].Status != domain.TxPending {
		t.Fatalf("want PENDING (unbound accepts), got %+v", results[0])
	}
}

func TestSubmitClaim_RequestHashTamperDetected(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	item := h.signedClaim(t, ct, kp, "bob", 1_000, 1, 9_000, h.clock.Now())
	// Tamper the PR amount after the payer signed — the PT's request_hash
	// no longer matches sha256(canonical(PR)).
	item.Request.Amount = 9999

	_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{item})
	if err != nil {
		t.Fatalf("submit: %v", err)
	}
	if results[0].Status != domain.TxRejected {
		t.Fatalf("want REJECTED, got %+v", results[0])
	}
	// Tampered PR amount breaks the receiver signature first; either signal
	// is an acceptable rejection.
	switch results[0].Reason {
	case ErrBadReceiverSignature.Error(), ErrRequestHashMismatch.Error(), ErrRequestAmountMismatch.Error():
		// expected
	default:
		t.Fatalf("unexpected reason %q", results[0].Reason)
	}
}

func TestSubmitClaim_BadReceiverSignatureRejected(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	item := h.signedClaim(t, ct, kp, "bob", 1_000, 1, 9_000, h.clock.Now())
	item.Request.ReceiverSignature = append([]byte{}, item.Request.ReceiverSignature...)
	item.Request.ReceiverSignature[0] ^= 0xFF

	_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{item})
	if err != nil {
		t.Fatalf("submit: %v", err)
	}
	if results[0].Status != domain.TxRejected || results[0].Reason != ErrBadReceiverSignature.Error() {
		t.Fatalf("want BadReceiverSignature, got %+v", results[0])
	}
}

func TestSubmitClaim_BadDisplayCardSigRejected(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	item := h.signedClaim(t, ct, kp, "bob", 1_000, 1, 9_000, h.clock.Now())
	// Forge a fake display-card signature. The receiver sig over the PR
	// still verifies (card is in-signed data), but the server re-checks the
	// card's server_signature separately.
	item.Request.ReceiverDisplayCard.ServerSignature = append([]byte{}, item.Request.ReceiverDisplayCard.ServerSignature...)
	item.Request.ReceiverDisplayCard.ServerSignature[0] ^= 0xFF

	_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{item})
	if err != nil {
		t.Fatalf("submit: %v", err)
	}
	if results[0].Status != domain.TxRejected {
		t.Fatalf("want REJECTED, got %+v", results[0])
	}
	// Display-card tampering typically breaks the receiver signature over
	// the PR first (display_card is inside the signed payload). Either
	// failure is acceptable.
	switch results[0].Reason {
	case ErrBadDisplayCardSig.Error(), ErrBadReceiverSignature.Error():
		// expected
	default:
		t.Fatalf("unexpected reason %q", results[0].Reason)
	}
}

// SubmitClaim hands Phase 4b off to the worker via outbox. Per the new
// event-driven design, the response should carry PENDING + the RPC should
// leave exactly one finalize row per distinct payer in the batch.
func TestSubmitClaim_EnqueuesFinalizeOutbox(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	item := h.signedClaim(t, ct, kp, "bob", 3_000, 1, 7_000, h.clock.Now())
	_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{item})
	if err != nil {
		t.Fatalf("submit: %v", err)
	}
	if got := results[0].Status; got != domain.TxPending {
		t.Fatalf("claim should return PENDING (finalize is async): got %s (%+v)", got, results[0])
	}
	if results[0].SettledAmount != 0 {
		t.Fatalf("phase 4a should not credit settled_amount yet, got %d", results[0].SettledAmount)
	}
	// Receiver's funds land in RECEIVING_PENDING; the worker moves them
	// to MAIN once the finalize event is processed.
	if got := h.repo.accounts["acct-bob-receiving_pending"].balance; got != 3_000 {
		t.Errorf("bob pending = %d want 3000", got)
	}
	if got := h.repo.accounts["acct-bob-main"].balance; got != 0 {
		t.Errorf("bob main should stay 0 until worker finalizes, got %d", got)
	}
	// Exactly one outbox row, keyed by alice, with reason=claim_accepted.
	rows := h.repo.finalizeOutboxForPayer("alice")
	if len(rows) != 1 {
		t.Fatalf("want 1 finalize row for alice, got %d (%+v)", len(rows), rows)
	}
	var fp domain.FinalizePayerPayload
	if err := json.Unmarshal(rows[0].Payload, &fp); err != nil {
		t.Fatalf("bad payload: %v", err)
	}
	if fp.PayerUserID != "alice" || fp.Reason != domain.FinalizeReasonClaimAccepted {
		t.Errorf("payload = %+v; want payer=alice reason=claim_accepted", fp)
	}
}

// Two accepted claims from the same payer should enqueue only one
// finalize row — the processor drains every PENDING row for a payer
// in one pass, so dedup is just an optimisation.
func TestSubmitClaim_DeduplicatesFinalizeEnqueuePerPayer(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")
	h.repo.seedUser("carol")

	items := []ClaimItem{
		h.signedClaim(t, ct, kp, "bob", 1_000, 1, 9_000, h.clock.Now()),
		h.signedClaim(t, ct, kp, "bob", 1_000, 2, 8_000, h.clock.Now()),
	}
	if _, _, err := h.svc.SubmitClaim(context.Background(), "bob", items); err != nil {
		t.Fatalf("submit: %v", err)
	}
	if got := len(h.repo.finalizeOutboxForPayer("alice")); got != 1 {
		t.Errorf("want 1 finalize row (deduped), got %d", got)
	}
}

func TestSubmitClaim_ExpiredRequestRejected(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	// Generate claim with timestamp far in the past so PR.ExpiresAt +
	// RequestGrace is already behind `now`.
	pastTs := h.clock.Now().Add(-2 * time.Hour)
	item := h.signedClaim(t, ct, kp, "bob", 1_000, 1, 9_000, pastTs)

	_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{item})
	if err != nil {
		t.Fatalf("submit: %v", err)
	}
	if results[0].Status != domain.TxRejected || results[0].Reason != ErrRequestExpired.Error() {
		t.Fatalf("want RequestExpired, got %+v", results[0])
	}
}

// B2: settlement respects server-side ceiling status.
//
// submitOne re-reads the ceiling from the DB at claim time so it can
// reject any status that the client's bank-signed (and therefore
// immutable) copy doesn't reflect. Three cases:
//
//   1. ceiling transitioned to a terminal status (REVOKED/EXPIRED/EXHAUSTED)
//      → reject with ErrCeilingRevoked.
//   2. ceiling in RECOVERY_PENDING but now < release_after → still accept;
//      merchants in flight must still be able to settle during the
//      quarantine window.
//   3. ceiling in RECOVERY_PENDING with now >= release_after → reject
//      with ErrCeilingRecoveryClosed; the sweeper owns the lien from
//      here on.

func TestSubmitClaim_RecoveryPending_AcceptsWithinReleaseWindow(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	// Simulate the payer having recovered the ceiling — quarantine is
	// still in effect (release_after 2h in the future).
	releaseAfter := h.clock.Now().Add(2 * time.Hour)
	c := h.repo.ceilings[ct.ID]
	c.Status = domain.CeilingRecoveryPending
	c.ReleaseAfter = &releaseAfter

	pay := h.signedClaim(t, ct, kp, "bob", 3_000, 1, 7_000, h.clock.Now())
	_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay})
	if err != nil {
		t.Fatalf("SubmitClaim: %v", err)
	}
	if results[0].Status != domain.TxPending {
		t.Fatalf("want PENDING during quarantine window, got %+v", results[0])
	}
}

func TestSubmitClaim_RecoveryPending_RejectsPastReleaseAfter(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	// release_after already elapsed. The sweeper hasn't flipped the
	// status yet — we're racing it. Settlement must reject so the
	// sweeper's pending release math isn't invalidated by a fresh
	// claim.
	releaseAfter := h.clock.Now().Add(-10 * time.Second)
	c := h.repo.ceilings[ct.ID]
	c.Status = domain.CeilingRecoveryPending
	c.ReleaseAfter = &releaseAfter

	pay := h.signedClaim(t, ct, kp, "bob", 3_000, 1, 7_000, h.clock.Now())
	_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay})
	if err != nil {
		t.Fatalf("SubmitClaim: %v", err)
	}
	if results[0].Status != domain.TxRejected ||
		results[0].Reason != ErrCeilingRecoveryClosed.Error() {
		t.Fatalf("want ErrCeilingRecoveryClosed, got %+v", results[0])
	}
}

func TestSubmitClaim_TerminalStatusRejected(t *testing.T) {
	for _, tc := range []struct {
		name   string
		status domain.CeilingStatus
	}{
		{"revoked", domain.CeilingRevoked},
		{"expired", domain.CeilingExpired},
		{"exhausted", domain.CeilingExhausted},
	} {
		t.Run(tc.name, func(t *testing.T) {
			h := newHarness(t)
			ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
			h.repo.seedUser("bob")

			// Flip the DB-side status to a terminal. Client's bank-signed
			// copy still says ACTIVE, but the server must prefer its own
			// view.
			h.repo.ceilings[ct.ID].Status = tc.status

			pay := h.signedClaim(t, ct, kp, "bob", 3_000, 1, 7_000, h.clock.Now())
			_, results, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay})
			if err != nil {
				t.Fatalf("SubmitClaim: %v", err)
			}
			if results[0].Status != domain.TxRejected ||
				results[0].Reason != ErrCeilingRevoked.Error() {
				t.Fatalf("want ErrCeilingRevoked, got %+v", results[0])
			}
		})
	}
}

// Dedup idempotency: a retry of an already-accepted claim against a
// now-recovered ceiling must still return the original PENDING/SETTLED
// result rather than the new ErrCeilingRecoveryClosed. The status
// check runs AFTER the dedupe lookup for exactly this case.
func TestSubmitClaim_RecoveryPending_ReturnsIdempotentForReplay(t *testing.T) {
	h := newHarness(t)
	ct, kp := h.issueCeiling(t, "alice", 10_000, h.clock.Now().Add(time.Hour))
	h.repo.seedUser("bob")

	// First submission while ACTIVE.
	pay := h.signedClaim(t, ct, kp, "bob", 3_000, 1, 7_000, h.clock.Now())
	_, results1, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay})
	if err != nil {
		t.Fatalf("first SubmitClaim: %v", err)
	}
	if results1[0].Status != domain.TxPending {
		t.Fatalf("first result: %+v", results1[0])
	}

	// Now the ceiling has moved to RECOVERY_PENDING past release_after.
	// A legitimate client retrying the same claim must see the original
	// PENDING result, not a spurious ErrCeilingRecoveryClosed.
	releaseAfter := h.clock.Now().Add(-10 * time.Second)
	c := h.repo.ceilings[ct.ID]
	c.Status = domain.CeilingRecoveryPending
	c.ReleaseAfter = &releaseAfter

	_, results2, err := h.svc.SubmitClaim(context.Background(), "bob", []ClaimItem{pay})
	if err != nil {
		t.Fatalf("retry SubmitClaim: %v", err)
	}
	if results2[0].Status != results1[0].Status ||
		results2[0].TransactionID != results1[0].TransactionID {
		t.Fatalf("retry result diverged — status=%s, txn=%s vs original status=%s, txn=%s",
			results2[0].Status, results2[0].TransactionID,
			results1[0].Status, results1[0].TransactionID)
	}
}
