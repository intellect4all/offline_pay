//go:build integration

// Package pgrepo integration tests.
//
// Run with:
//
//	go test -tags=integration ./internal/repository/...
//
// Requires Docker to be running (testcontainers spins up Postgres 16).
// Migrations are applied from ../../../db/migrations via golang-migrate.
package pgrepo

import (
	"context"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/testcontainers/testcontainers-go"
	tcpostgres "github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

func migrationsDir(t *testing.T) string {
	t.Helper()
	_, thisFile, _, _ := runtime.Caller(0)
	// thisFile: backend/internal/repository/pgrepo/repo_test.go
	// migrations: backend/db/migrations
	dir := filepath.Join(filepath.Dir(thisFile), "..", "..", "..", "db", "migrations")
	abs, err := filepath.Abs(dir)
	if err != nil {
		t.Fatalf("resolve migrations dir: %v", err)
	}
	return abs
}

func startPostgres(t *testing.T, ctx context.Context) (*pgxpool.Pool, func()) {
	t.Helper()
	container, err := tcpostgres.Run(ctx,
		"postgres:16-alpine",
		tcpostgres.WithDatabase("offlinepay_test"),
		tcpostgres.WithUsername("offlinepay"),
		tcpostgres.WithPassword("offlinepay"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(60*time.Second),
		),
	)
	if err != nil {
		t.Fatalf("start postgres: %v", err)
	}

	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("dsn: %v", err)
	}

	// Apply migrations via golang-migrate. Driver URL scheme = "pgx5".
	migrateDSN := strings.Replace(dsn, "postgres://", "pgx5://", 1)
	m, err := migrate.New("file://"+migrationsDir(t), migrateDSN)
	if err != nil {
		t.Fatalf("migrate new: %v", err)
	}
	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		t.Fatalf("migrate up: %v", err)
	}
	srcErr, dbErr := m.Close()
	if srcErr != nil {
		t.Fatalf("migrate source close: %v", srcErr)
	}
	if dbErr != nil {
		t.Fatalf("migrate db close: %v", dbErr)
	}

	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("pgxpool: %v", err)
	}

	cleanup := func() {
		pool.Close()
		_ = container.Terminate(context.Background())
	}
	return pool, cleanup
}

func TestRepo_EndToEnd(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	repo := New(pool)

	// 1. Register a user -> inserts user + 5 accounts.
	userID, err := repo.RegisterUser(ctx, "+2348000000001", "8000000001", "", "TIER_0", 1)
	if err != nil {
		t.Fatalf("register user: %v", err)
	}
	payeeID, err := repo.RegisterUser(ctx, "+2348000000002", "8000000002", "", "TIER_0", 1)
	if err != nil {
		t.Fatalf("register payee: %v", err)
	}

	// Verify the five accounts exist.
	q := sqlcgen.New(pool)
	accts, err := q.ListAccountsByUser(ctx, userID)
	if err != nil {
		t.Fatalf("list accounts: %v", err)
	}
	if len(accts) != 5 {
		t.Fatalf("expected 5 accounts, got %d", len(accts))
	}
	seen := map[sqlcgen.AccountKind]bool{}
	for _, a := range accts {
		seen[a.Kind] = true
	}
	for _, want := range AllAccountKinds {
		if !seen[want] {
			t.Errorf("missing account kind %s", want)
		}
	}

	// 2. Upsert a bank signing key + register a lien account -> issue a ceiling.
	if err := repo.UpsertBankSigningKey(ctx, domain.BankSigningKey{
		KeyID:      "bank-key-1",
		PublicKey:  []byte("pub"),
		PrivateKey: []byte("priv"),
		ActiveFrom: time.Now().UTC(),
	}); err != nil {
		t.Fatalf("upsert bank key: %v", err)
	}

	lienAcctID, err := repo.GetAccountID(ctx, userID, sqlcgen.AccountKindLienHolding)
	if err != nil {
		t.Fatalf("get lien account: %v", err)
	}

	now := time.Now().UTC()
	ceiling, err := repo.IssueCeilingToken(ctx, IssueCeilingParams{
		PayerUserID:    userID,
		CeilingAmount:  100_00, // ₦100.00 in kobo
		SequenceStart:  0,
		IssuedAt:       now,
		ExpiresAt:      now.Add(30 * time.Minute),
		PayerPublicKey: []byte("payer-pub"),
		BankKeyID:      "bank-key-1",
		BankSignature:  []byte("sig"),
		LienAccountID:  lienAcctID,
	})
	if err != nil {
		t.Fatalf("issue ceiling: %v", err)
	}
	if ceiling.Status != domain.CeilingActive {
		t.Fatalf("expected ACTIVE, got %s", ceiling.Status)
	}

	// 3. One-active-per-user enforced.
	if _, err := repo.IssueCeilingToken(ctx, IssueCeilingParams{
		PayerUserID:    userID,
		CeilingAmount:  50_00,
		SequenceStart:  0,
		IssuedAt:       now,
		ExpiresAt:      now.Add(30 * time.Minute),
		PayerPublicKey: []byte("payer-pub"),
		BankKeyID:      "bank-key-1",
		BankSignature:  []byte("sig"),
		LienAccountID:  lienAcctID,
	}); err == nil {
		t.Fatal("expected duplicate-active-ceiling to be rejected")
	}

	// 4. Create a payment.
	payment, err := repo.CreatePayment(ctx, CreatePaymentParams{
		CeilingID:        ceiling.ID,
		PayerUserID:      userID,
		PayeeUserID:      payeeID,
		Amount:           25_00,
		SequenceNumber:   1,
		RemainingCeiling: 75_00,
		SignedAt:         now,
		PayerSignature:   []byte("pay-sig"),
		Status:           domain.TxQueued,
	})
	if err != nil {
		t.Fatalf("create payment: %v", err)
	}
	if payment.Amount != 2500 {
		t.Fatalf("amount mismatch: %d", payment.Amount)
	}

	// Idempotency: duplicate (payer, sequence) must fail.
	if _, err := repo.CreatePayment(ctx, CreatePaymentParams{
		CeilingID:        ceiling.ID,
		PayerUserID:      userID,
		PayeeUserID:      payeeID,
		Amount:           25_00,
		SequenceNumber:   1,
		RemainingCeiling: 75_00,
		SignedAt:         now,
		PayerSignature:   []byte("pay-sig"),
		Status:           domain.TxQueued,
	}); err == nil {
		t.Fatal("expected duplicate-sequence insertion to fail")
	}

	// 5. Balanced double-entry ledger succeeds.
	mainAcct, _ := repo.GetAccountID(ctx, userID, sqlcgen.AccountKindMain)
	if err := repo.Tx(ctx, func(tx *Repo) error {
		return tx.PostLedger(ctx, "fund-offline-"+NewID(), []LedgerLeg{
			{AccountID: mainAcct, Direction: "DEBIT", Amount: 100_00, Memo: "fund offline"},
			{AccountID: lienAcctID, Direction: "CREDIT", Amount: 100_00, Memo: "lien hold"},
		})
	}); err != nil {
		t.Fatalf("balanced ledger post: %v", err)
	}

	// 6. Unbalanced ledger must be rejected by the deferred trigger.
	unbalancedErr := repo.Tx(ctx, func(tx *Repo) error {
		return tx.PostLedger(ctx, "unbalanced-"+NewID(), []LedgerLeg{
			{AccountID: mainAcct, Direction: "DEBIT", Amount: 100_00},
			{AccountID: lienAcctID, Direction: "CREDIT", Amount: 90_00}, // mismatch
		})
	})
	if unbalancedErr == nil {
		t.Fatal("expected unbalanced ledger to be rejected by constraint trigger")
	}
	if !strings.Contains(unbalancedErr.Error(), "unbalanced") {
		t.Fatalf("expected 'unbalanced' in error, got %v", unbalancedErr)
	}
}
