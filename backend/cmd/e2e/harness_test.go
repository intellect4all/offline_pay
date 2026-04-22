//go:build e2e || scale

// End-to-end / stress / chaos test harness.
//
// Run with:
//
//	go test -tags=e2e ./cmd/e2e/...
//
// Requires Docker (testcontainers launches Postgres 16). The suite wires
// pgrepo + all services in-process (no gRPC for speed), seeds a bank key +
// realm key + sealed-box pair, registers 50 users, and runs:
//
//   - TestThousandTxnStress
//   - TestDoubleSpendConflict
//   - TestClockSkewChaos
//   - TestKeyRotationChaos
//   - TestCircularChain
//   - TestCrashResume  (best-effort idempotency check)
//   - TestGossipPropagation
//
// A summary is printed at the end; if WRITE_STRESS_REPORT=1 is set, it is
// also appended to docs/stress-report.md.
package e2e

import (
	"context"
	"crypto/ed25519"
	crand "crypto/rand"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/testcontainers/testcontainers-go"
	tcpostgres "github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/crypto"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
	"github.com/intellect/offlinepay/internal/service/gossip"
	"github.com/intellect/offlinepay/internal/service/reconciliation"
	"github.com/intellect/offlinepay/internal/service/settlement"
	"github.com/intellect/offlinepay/internal/service/wallet"
)

// env packages the fully-wired service graph for a single test run.
type env struct {
	t *testing.T

	pool     *pgxpool.Pool
	repo     *pgrepo.Repo
	wallet   *wallet.Service
	settle   *settlement.Service
	recon    *reconciliation.Service
	gossip   *gossip.Service
	sbPub    *[32]byte
	sbPriv   *[32]byte
	bankKey  domain.BankSigningKey
	users    []user
	userByID map[string]*user
}

type user struct {
	id      string
	pub     ed25519.PublicKey
	priv    ed25519.PrivateKey
	seq     int64 // per-user monotonic sequence counter (client-side)
	ceiling *domain.CeilingToken
}

func migrationsDir(t *testing.T) string {
	t.Helper()
	_, thisFile, _, _ := runtime.Caller(0)
	dir := filepath.Join(filepath.Dir(thisFile), "..", "..", "db", "migrations")
	abs, err := filepath.Abs(dir)
	if err != nil {
		t.Fatalf("abs: %v", err)
	}
	return abs
}

func startPostgres(t *testing.T, ctx context.Context) (*pgxpool.Pool, func()) {
	t.Helper()
	container, err := tcpostgres.Run(ctx, "postgres:16-alpine",
		tcpostgres.WithDatabase("offlinepay_e2e"),
		tcpostgres.WithUsername("offlinepay"),
		tcpostgres.WithPassword("offlinepay"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(60*time.Second),
		),
	)
	if err != nil {
		t.Fatalf("postgres: %v", err)
	}
	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("dsn: %v", err)
	}
	migrateDSN := strings.Replace(dsn, "postgres://", "pgx5://", 1)
	m, err := migrate.New("file://"+migrationsDir(t), migrateDSN)
	if err != nil {
		t.Fatalf("migrate new: %v", err)
	}
	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		t.Fatalf("migrate up: %v", err)
	}
	_, _ = m.Close()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	return pool, func() {
		pool.Close()
		_ = container.Terminate(context.Background())
	}
}

// buildEnv stands up a full in-process wiring + N registered users.
func buildEnv(t *testing.T, n int) (*env, func()) {
	t.Helper()
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	repo := pgrepo.New(pool, cache.Noop{})

	bankKP, err := crypto.GenerateKeyPair()
	if err != nil {
		t.Fatal(err)
	}
	bk := domain.BankSigningKey{
		KeyID: "bank-1", PublicKey: bankKP.PublicKey, PrivateKey: bankKP.PrivateKey,
		ActiveFrom: time.Now().UTC().Add(-time.Hour),
	}
	if err := repo.UpsertBankSigningKey(ctx, bk); err != nil {
		t.Fatal(err)
	}
	if err := repo.UpsertRealmKey(ctx, 1, []byte("00000000000000000000000000000000"), time.Now().UTC()); err != nil {
		t.Fatal(err)
	}
	sbPub, sbPriv, err := crypto.GenerateSealedBoxKeyPair()
	if err != nil {
		t.Fatal(err)
	}

	walletSvc := wallet.New(wallet.NewPgRepoAdapter(repo))
	settleSvc := settlement.New(settlement.NewPgRepoAdapter(repo))
	reconSvc := reconciliation.New(reconciliation.NewPgRepoAdapter(repo))
	gossipSvc := gossip.New(settleSvc, gossip.SealedBoxKeys{Public: sbPub, Private: sbPriv})

	e := &env{
		t: t, pool: pool, repo: repo,
		wallet: walletSvc, settle: settleSvc, recon: reconSvc, gossip: gossipSvc,
		sbPub: sbPub, sbPriv: sbPriv, bankKey: bk,
		userByID: make(map[string]*user, n),
	}

	for i := 0; i < n; i++ {
		pub, priv, err := ed25519.GenerateKey(crand.Reader)
		if err != nil {
			t.Fatal(err)
		}
		phone := fmt.Sprintf("+234800%07d", i)
		acct := fmt.Sprintf("800%07d", i)
		uid, err := repo.RegisterUser(ctx, phone, acct, "", "TIER_0", 1)
		if err != nil {
			t.Fatal(err)
		}
		if err := repo.SetUserPayerPubkey(ctx, uid, pub); err != nil {
			t.Fatal(err)
		}
		u := &user{id: uid, pub: pub, priv: priv}
		e.users = append(e.users, *u)
		e.userByID[uid] = &e.users[len(e.users)-1]
	}
	return e, cleanup
}

// creditMain credits kobo directly to a user's main account (bypasses KYC).
func (e *env) creditMain(ctx context.Context, userID string, kobo int64) {
	accID, err := e.repo.GetAccountID(ctx, userID, sqlcgen.AccountKindMain)
	if err != nil {
		e.t.Fatal(err)
	}
	// Ledger-balanced: pair with a suspense credit so double-entry holds.
	txnID := pgrepo.NewID()
	err = e.repo.Tx(ctx, func(tx *pgrepo.Repo) error {
		if err := tx.PostLedger(ctx, txnID, []pgrepo.LedgerLeg{
			{AccountID: settlement.SystemSuspenseAccountID, Direction: "DEBIT", Amount: kobo, Memo: "test seed"},
			{AccountID: accID, Direction: "CREDIT", Amount: kobo, Memo: "test seed"},
		}); err != nil {
			return err
		}
		if err := tx.ForceDebitAccount(ctx, settlement.SystemSuspenseAccountID, kobo); err != nil {
			return err
		}
		return tx.CreditAccount(ctx, accID, kobo)
	})
	if err != nil {
		e.t.Fatalf("credit main: %v", err)
	}
}

// ensureCeiling makes sure the user has an active ceiling with >= want kobo
// remaining; if not, drains and re-funds.
func (e *env) ensureCeiling(ctx context.Context, u *user, want int64) {
	if u.ceiling != nil && u.ceiling.CeilingAmount-u.seq >= want {
		return
	}
	// Fund with 10x requested amount to reduce churn.
	amt := want * 10
	if amt < 10_000_00 {
		amt = 10_000_00
	}
	e.creditMain(ctx, u.id, amt)
	ct, err := e.wallet.FundOffline(ctx, u.id, amt, 30*time.Minute)
	if err != nil {
		e.t.Fatalf("fund offline for %s: %v", u.id, err)
	}
	u.ceiling = &ct
	u.seq = ct.SequenceStart
}

// makePayment generates a signed PaymentToken from u → to for amount kobo.
func (e *env) makePayment(u *user, to *user, amount int64, ts time.Time) (domain.PaymentToken, domain.CeilingToken) {
	u.seq++
	remaining := u.ceiling.CeilingAmount - u.seq*amount // not used by server; audit-only
	if remaining < 0 {
		remaining = 0
	}
	payload := domain.PaymentPayload{
		PayerID:          u.id,
		PayeeID:          to.id,
		Amount:           amount,
		SequenceNumber:   u.seq,
		RemainingCeiling: remaining,
		Timestamp:        ts,
		CeilingTokenID:   u.ceiling.ID,
	}
	sig, err := crypto.SignPayment(u.priv, payload)
	if err != nil {
		e.t.Fatalf("sign: %v", err)
	}
	return domain.PaymentToken{
		PayerID: u.id, PayeeID: to.id, Amount: amount,
		SequenceNumber: u.seq, RemainingCeiling: remaining,
		Timestamp: ts, CeilingTokenID: u.ceiling.ID,
		PayerSignature: sig,
	}, *u.ceiling
}

type runSummary struct {
	mu            sync.Mutex
	TxnsSubmitted int
	TxnsSettled   int
	TxnsPartial   int
	TxnsRejected  int
	SettledTotal  int64
	Conflicts     int
	Durations     []time.Duration
	Tests         []string
}

var global runSummary

func (r *runSummary) add(n int, total int64, part, rej int, conflicts int) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.TxnsSubmitted += n
	r.TxnsSettled += n - part - rej
	r.TxnsPartial += part
	r.TxnsRejected += rej
	r.SettledTotal += total
	r.Conflicts += conflicts
}

// TestZMain is a named-alphabetically-last hack to print the summary after
// all other tests in this package complete when running `go test`.
func TestZMain(t *testing.T) {
	global.mu.Lock()
	defer global.mu.Unlock()
	var meanLatency time.Duration
	if len(global.Durations) > 0 {
		var tot time.Duration
		for _, d := range global.Durations {
			tot += d
		}
		meanLatency = tot / time.Duration(len(global.Durations))
	}
	lines := []string{
		fmt.Sprintf("## E2E run summary (%s)", time.Now().UTC().Format(time.RFC3339)),
		fmt.Sprintf("- Tests: %s", strings.Join(global.Tests, ", ")),
		fmt.Sprintf("- Txns submitted: %d", global.TxnsSubmitted),
		fmt.Sprintf("- Settled: %d", global.TxnsSettled),
		fmt.Sprintf("- Partially settled: %d", global.TxnsPartial),
		fmt.Sprintf("- Rejected: %d", global.TxnsRejected),
		fmt.Sprintf("- Settled total (kobo): %d", global.SettledTotal),
		fmt.Sprintf("- Conflicts detected: %d", global.Conflicts),
		fmt.Sprintf("- Mean per-txn latency: %s", meanLatency),
	}
	summary := strings.Join(lines, "\n")
	t.Log("\n" + summary)
	if os.Getenv("WRITE_STRESS_REPORT") == "1" {
		_, thisFile, _, _ := runtime.Caller(0)
		path := filepath.Join(filepath.Dir(thisFile), "..", "..", "..", "docs", "stress-report.md")
		abs, _ := filepath.Abs(path)
		f, err := os.OpenFile(abs, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
		if err != nil {
			t.Logf("open stress-report: %v", err)
			return
		}
		defer f.Close()
		if _, err := f.WriteString("\n\n" + summary + "\n"); err != nil {
			t.Logf("write stress-report: %v", err)
		}
	}
}

func TestThousandTxnStress(t *testing.T) {
	global.Tests = append(global.Tests, "TestThousandTxnStress")
	ctx := context.Background()
	e, cleanup := buildEnv(t, 50)
	defer cleanup()

	const N = 1000
	rng := rand.New(rand.NewSource(42))

	// Ensure every user has a ceiling up front.
	for i := range e.users {
		e.ensureCeiling(ctx, &e.users[i], 500_00)
	}

	type submission struct {
		payerID    string
		receiverID string
		payment    domain.PaymentToken
		ceiling    domain.CeilingToken
	}
	subs := make([]submission, 0, N)

	start := time.Now()
	var totalSubmitted int64
	for i := 0; i < N; i++ {
		payerIdx := rng.Intn(len(e.users))
		receiverIdx := rng.Intn(len(e.users))
		for receiverIdx == payerIdx {
			receiverIdx = rng.Intn(len(e.users))
		}
		payer := &e.users[payerIdx]
		receiver := &e.users[receiverIdx]

		amount := int64(100_00 + rng.Intn(400_00)) // ₦100–₦500 each
		// Refresh ceiling if budget + current seq would exceed ceiling amount.
		if payer.ceiling == nil || payer.ceiling.CeilingAmount-payer.seq*amount < amount {
			e.ensureCeiling(ctx, payer, amount)
		}
		pt, ct := e.makePayment(payer, receiver, amount, time.Now().UTC())
		subs = append(subs, submission{payer.id, receiver.id, pt, ct})
		totalSubmitted += amount
	}

	// Shuffle so claims arrive out of order (simulating heterogeneous reconnects).
	rng.Shuffle(len(subs), func(i, j int) { subs[i], subs[j] = subs[j], subs[i] })

	settled, partial, rejected := 0, 0, 0
	// Submit in batches by receiver to match real submitclaim semantics.
	byReceiver := map[string][]settlement.ClaimItem{}
	for _, s := range subs {
		byReceiver[s.receiverID] = append(byReceiver[s.receiverID], settlement.ClaimItem{
			Payment: s.payment, Ceiling: s.ceiling,
		})
	}
	for rid, items := range byReceiver {
		if _, _, err := e.settle.SubmitClaim(ctx, rid, items); err != nil {
			t.Fatalf("submitclaim %s: %v", rid, err)
		}
	}
	// Finalize for each unique payer.
	payers := map[string]bool{}
	for _, s := range subs {
		payers[s.payerID] = true
	}
	var settledTotal int64
	for pid := range payers {
		results, err := e.settle.FinalizeForPayer(ctx, pid)
		if err != nil {
			t.Fatalf("finalize %s: %v", pid, err)
		}
		for _, r := range results {
			switch r.Status {
			case domain.TxSettled:
				settled++
				settledTotal += r.SettledAmount
			case domain.TxPartiallySettled:
				partial++
				settledTotal += r.SettledAmount
			case domain.TxRejected:
				rejected++
			}
		}
	}
	duration := time.Since(start)
	t.Logf("stress: N=%d settled=%d partial=%d rejected=%d total=%d duration=%s",
		N, settled, partial, rejected, settledTotal, duration)

	// Ledger reconciliation.
	rec, err := e.recon.NightlyLedgerReconcile(ctx)
	if err != nil {
		t.Fatalf("recon: %v", err)
	}
	if rec.Status != domain.ReconClean {
		b, _ := json.MarshalIndent(rec.Discrepancies, "", "  ")
		t.Fatalf("ledger not clean: %s\n%s", rec.Status, b)
	}

	global.add(N, settledTotal, partial, rejected, 0)
	global.mu.Lock()
	global.Durations = append(global.Durations, duration/time.Duration(N))
	global.mu.Unlock()
}

func TestDoubleSpendConflict(t *testing.T) {
	global.Tests = append(global.Tests, "TestDoubleSpendConflict")
	ctx := context.Background()
	e, cleanup := buildEnv(t, 4)
	defer cleanup()

	payer := &e.users[0]
	a, b, c := &e.users[1], &e.users[2], &e.users[3]

	// Fund payer with exactly ₦5,000.
	e.creditMain(ctx, payer.id, 5_000_00)
	ct, err := e.wallet.FundOffline(ctx, payer.id, 5_000_00, time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	payer.ceiling = &ct
	payer.seq = ct.SequenceStart

	// Three overlapping payments of ₦3,000 each → total ₦9,000 attempted.
	now := time.Now().UTC()
	p1, c1 := e.makePayment(payer, a, 3_000_00, now)
	p2, c2 := e.makePayment(payer, b, 3_000_00, now)
	p3, c3 := e.makePayment(payer, c, 3_000_00, now)

	if _, _, err := e.settle.SubmitClaim(ctx, a.id, []settlement.ClaimItem{{Payment: p1, Ceiling: c1}}); err != nil {
		t.Fatal(err)
	}
	if _, _, err := e.settle.SubmitClaim(ctx, b.id, []settlement.ClaimItem{{Payment: p2, Ceiling: c2}}); err != nil {
		t.Fatal(err)
	}
	if _, _, err := e.settle.SubmitClaim(ctx, c.id, []settlement.ClaimItem{{Payment: p3, Ceiling: c3}}); err != nil {
		t.Fatal(err)
	}

	results, err := e.settle.FinalizeForPayer(ctx, payer.id)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 3 {
		t.Fatalf("expected 3 results, got %d", len(results))
	}

	// Results are returned in sequence order: full, partial, zero.
	wantSeq := []struct {
		settled int64
		status  domain.TransactionStatus
	}{
		{3_000_00, domain.TxSettled},
		{2_000_00, domain.TxPartiallySettled},
		{0, domain.TxPartiallySettled},
	}
	var total int64
	for i, r := range results {
		if r.SettledAmount != wantSeq[i].settled || r.Status != wantSeq[i].status {
			t.Errorf("result[%d] = (%d, %s), want (%d, %s)",
				i, r.SettledAmount, r.Status, wantSeq[i].settled, wantSeq[i].status)
		}
		total += r.SettledAmount
	}
	if total != 5_000_00 {
		t.Fatalf("total settled = %d, want 500000", total)
	}
	global.add(3, total, 2, 0, 1)
}

func TestClockSkewChaos(t *testing.T) {
	global.Tests = append(global.Tests, "TestClockSkewChaos")
	ctx := context.Background()
	e, cleanup := buildEnv(t, 2)
	defer cleanup()

	payer, receiver := &e.users[0], &e.users[1]
	e.creditMain(ctx, payer.id, 10_000_00)
	ct, err := e.wallet.FundOffline(ctx, payer.id, 10_000_00, time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	payer.ceiling = &ct
	payer.seq = ct.SequenceStart

	// Device clock ±15 min from server time — within the 30-minute grace.
	now := time.Now().UTC()
	p1, c1 := e.makePayment(payer, receiver, 100_00, now.Add(-15*time.Minute))
	p2, c2 := e.makePayment(payer, receiver, 100_00, now.Add(15*time.Minute))

	_, res, err := e.settle.SubmitClaim(ctx, receiver.id, []settlement.ClaimItem{
		{Payment: p1, Ceiling: c1},
		{Payment: p2, Ceiling: c2},
	})
	if err != nil {
		t.Fatal(err)
	}
	for _, r := range res {
		if r.Status != domain.TxPending {
			t.Errorf("within-grace claim rejected: %s (%s)", r.Status, r.Reason)
		}
	}

	// Now expire the ceiling by moving the service clock forward past the
	// grace. Claim must be rejected with ErrCeilingExpired.
	fakeClock := &advanceClock{now: ct.ExpiresAt.Add(e.settle.ClockGrace + time.Minute)}
	e.settle.Clock = fakeClock
	p3, c3 := e.makePayment(payer, receiver, 100_00, now.Add(-60*time.Minute))
	_, res3, err := e.settle.SubmitClaim(ctx, receiver.id, []settlement.ClaimItem{{Payment: p3, Ceiling: c3}})
	if err != nil {
		t.Fatal(err)
	}
	if len(res3) != 1 || res3[0].Status != domain.TxRejected {
		t.Fatalf("expected rejection outside grace, got %+v", res3)
	}
	// Reset clock for subsequent tests.
	e.settle.Clock = settlement.SystemClock{}
}

type advanceClock struct{ now time.Time }

func (c *advanceClock) Now() time.Time { return c.now }

func TestKeyRotationChaos(t *testing.T) {
	global.Tests = append(global.Tests, "TestKeyRotationChaos")
	ctx := context.Background()
	e, cleanup := buildEnv(t, 2)
	defer cleanup()

	payer, receiver := &e.users[0], &e.users[1]
	e.creditMain(ctx, payer.id, 5_000_00)
	ct, err := e.wallet.FundOffline(ctx, payer.id, 5_000_00, time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	payer.ceiling = &ct
	payer.seq = ct.SequenceStart

	// Client signs a payment under the current ceiling (bank-key-1).
	p1, c1 := e.makePayment(payer, receiver, 100_00, time.Now().UTC())

	// Rotate: install a new bank key; the existing ceiling references the
	// old key_id and must still verify (lookup by key_id is still valid).
	newKP, err := crypto.GenerateKeyPair()
	if err != nil {
		t.Fatal(err)
	}
	if err := e.repo.UpsertBankSigningKey(ctx, domain.BankSigningKey{
		KeyID: "bank-2", PublicKey: newKP.PublicKey, PrivateKey: newKP.PrivateKey,
		ActiveFrom: time.Now().UTC(),
	}); err != nil {
		t.Fatal(err)
	}

	_, res, err := e.settle.SubmitClaim(ctx, receiver.id, []settlement.ClaimItem{{Payment: p1, Ceiling: c1}})
	if err != nil {
		t.Fatal(err)
	}
	if len(res) != 1 || res[0].Status != domain.TxPending {
		t.Fatalf("expected PENDING after key rotation, got %+v", res)
	}
}

func TestCircularChain(t *testing.T) {
	global.Tests = append(global.Tests, "TestCircularChain")
	ctx := context.Background()
	e, cleanup := buildEnv(t, 3)
	defer cleanup()

	a, b, c := &e.users[0], &e.users[1], &e.users[2]
	for _, u := range []*user{a, b, c} {
		e.creditMain(ctx, u.id, 5_000_00)
		ct, err := e.wallet.FundOffline(ctx, u.id, 5_000_00, time.Hour)
		if err != nil {
			t.Fatal(err)
		}
		u.ceiling = &ct
		u.seq = ct.SequenceStart
	}
	now := time.Now().UTC()
	pAB, cAB := e.makePayment(a, b, 100_00, now)
	pBC, cBC := e.makePayment(b, c, 200_00, now)
	pCA, cCA := e.makePayment(c, a, 150_00, now)

	if _, _, err := e.settle.SubmitClaim(ctx, b.id, []settlement.ClaimItem{{Payment: pAB, Ceiling: cAB}}); err != nil {
		t.Fatal(err)
	}
	if _, _, err := e.settle.SubmitClaim(ctx, c.id, []settlement.ClaimItem{{Payment: pBC, Ceiling: cBC}}); err != nil {
		t.Fatal(err)
	}
	if _, _, err := e.settle.SubmitClaim(ctx, a.id, []settlement.ClaimItem{{Payment: pCA, Ceiling: cCA}}); err != nil {
		t.Fatal(err)
	}
	for _, u := range []*user{a, b, c} {
		if _, err := e.settle.FinalizeForPayer(ctx, u.id); err != nil {
			t.Fatal(err)
		}
	}
	// Phase 4b now credits MAIN directly. Setup primes main to
	// credit_main(500_000) then FundOffline(500_000), so main starts at
	// zero — the settled offline-payment volume is the whole main
	// balance post-finalize.
	check := func(uid string, wantInbound int64) {
		bal, err := e.wallet.GetBalances(ctx, uid)
		if err != nil {
			t.Fatal(err)
		}
		if bal.Main != wantInbound {
			t.Errorf("%s settled inbound (main) = %d, want %d",
				uid, bal.Main, wantInbound)
		}
	}
	check(a.id, 150_00)
	check(b.id, 100_00)
	check(c.id, 200_00)
	global.add(3, 100_00+200_00+150_00, 0, 0, 0)
}

// TestCrashResume verifies idempotency.
func TestCrashResume(t *testing.T) {
	global.Tests = append(global.Tests, "TestCrashResume")
	ctx := context.Background()
	e, cleanup := buildEnv(t, 2)
	defer cleanup()

	payer, receiver := &e.users[0], &e.users[1]
	e.creditMain(ctx, payer.id, 5_000_00)
	ct, err := e.wallet.FundOffline(ctx, payer.id, 5_000_00, time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	payer.ceiling = &ct
	payer.seq = ct.SequenceStart

	p1, c1 := e.makePayment(payer, receiver, 200_00, time.Now().UTC())
	if _, _, err := e.settle.SubmitClaim(ctx, receiver.id, []settlement.ClaimItem{{Payment: p1, Ceiling: c1}}); err != nil {
		t.Fatal(err)
	}

	// Inject a panic at pre-commit so the first FinalizeForPayer dies just
	// before the tx commits. The deferred rollback in pgrepo.Tx must put the
	// DB back in PENDING state so the resume call can settle deterministically.
	panicOnce := true
	e.settle.PanicAfter = func(stage string) {
		if stage == "pre-commit" && panicOnce {
			panicOnce = false
			panic("injected fault: pre-commit")
		}
	}
	func() {
		defer func() {
			if r := recover(); r == nil {
				t.Fatal("expected injected panic from FinalizeForPayer")
			}
		}()
		_, _ = e.settle.FinalizeForPayer(ctx, payer.id)
	}()
	e.settle.PanicAfter = nil

	// Resume — should now settle the PENDING txn cleanly.
	results1, err := e.settle.FinalizeForPayer(ctx, payer.id)
	if err != nil {
		t.Fatal(err)
	}
	if len(results1) != 1 || results1[0].SettledAmount != 200_00 || results1[0].Status != domain.TxSettled {
		t.Fatalf("unexpected resume results: %+v", results1)
	}
	// A subsequent run is a no-op (idempotent).
	results2, err := e.settle.FinalizeForPayer(ctx, payer.id)
	if err != nil {
		t.Fatal(err)
	}
	if len(results2) != 0 {
		t.Fatalf("second resume should produce zero new results, got %d", len(results2))
	}
	global.add(1, 200_00, 0, 0, 0)
}

func TestGossipPropagation(t *testing.T) {
	global.Tests = append(global.Tests, "TestGossipPropagation")
	ctx := context.Background()
	e, cleanup := buildEnv(t, 4)
	defer cleanup()

	a, b, c, d := &e.users[0], &e.users[1], &e.users[2], &e.users[3]
	// Fund all three payers (A, B, C).
	for _, u := range []*user{a, b, c} {
		e.creditMain(ctx, u.id, 5_000_00)
		ct, err := e.wallet.FundOffline(ctx, u.id, 5_000_00, time.Hour)
		if err != nil {
			t.Fatal(err)
		}
		u.ceiling = &ct
		u.seq = ct.SequenceStart
	}

	now := time.Now().UTC()
	pAB, cAB := e.makePayment(a, b, 100_00, now)
	pBC, cBC := e.makePayment(b, c, 150_00, now)
	pCD, cCD := e.makePayment(c, d, 200_00, now)

	// Build sealed-box blobs for each of the three txns. Only D goes online
	// and uploads all three.
	mkBlob := func(pt domain.PaymentToken, ct domain.CeilingToken, senderID string) domain.GossipBlob {
		wire := gossip.WireInnerPayload{
			Ceiling: gossip.CeilingTokenWire{
				ID: ct.ID,
				Payload: domain.CeilingTokenPayload{
					PayerID:        ct.PayerID,
					CeilingAmount:  ct.CeilingAmount,
					IssuedAt:       ct.IssuedAt,
					ExpiresAt:      ct.ExpiresAt,
					SequenceStart:  ct.SequenceStart,
					PayerPublicKey: ct.PayerPublicKey,
					BankKeyID:      ct.BankKeyID,
				},
				BankSignature: ct.BankSignature,
			},
			Payment:      pt,
			SenderUserID: senderID,
		}
		inner, err := gossip.EncodeInner(wire)
		if err != nil {
			t.Fatal(err)
		}
		sealed, err := crypto.SealAnonymous(e.sbPub, inner)
		if err != nil {
			t.Fatal(err)
		}
		return domain.GossipBlob{
			TransactionHash:  []byte(pt.PayerID + ":" + fmt.Sprint(pt.SequenceNumber)),
			EncryptedBlob:    sealed,
			BankSignature:    ct.BankSignature,
			CeilingTokenHash: []byte(ct.ID),
			HopCount:         1,
			BlobSize:         len(sealed),
		}
	}
	blobs := []domain.GossipBlob{
		mkBlob(pAB, cAB, b.id),
		mkBlob(pBC, cBC, c.id),
		mkBlob(pCD, cCD, d.id),
	}
	res, err := e.gossip.Upload(ctx, d.id, blobs)
	if err != nil {
		t.Fatal(err)
	}
	if res.Accepted != 3 || res.Rejected != 0 {
		t.Fatalf("gossip: accepted=%d rejected=%d (want 3/0); items=%+v", res.Accepted, res.Rejected, res.Items)
	}
	// Finalize each payer.
	for _, u := range []*user{a, b, c} {
		if _, err := e.settle.FinalizeForPayer(ctx, u.id); err != nil {
			t.Fatal(err)
		}
	}
	check := func(uid string, wantInbound int64) {
		bal, err := e.wallet.GetBalances(ctx, uid)
		if err != nil {
			t.Fatal(err)
		}
		if bal.Main != wantInbound {
			t.Errorf("%s settled inbound (main) = %d, want %d",
				uid, bal.Main, wantInbound)
		}
	}
	check(b.id, 100_00)
	check(c.id, 150_00)
	check(d.id, 200_00)
	global.add(3, 100_00+150_00+200_00, 0, 0, 0)
}

// unused helper to appease goimports — counter referenced from atomic test paths
var _ = atomic.LoadInt64
