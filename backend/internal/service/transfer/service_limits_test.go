//go:build integration

// Integration tests for KYC-tier limit enforcement on the transfer
// accept-side. Spins up a disposable Postgres via testcontainers and
// applies the same migrations the BFF uses in prod.
//
// Run with:
//
//	go test -tags=integration ./internal/service/transfer/...
package transfer

import (
	"context"
	"errors"
	"fmt"
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
)

func migrationsDir(t *testing.T) string {
	t.Helper()
	_, thisFile, _, _ := runtime.Caller(0)
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
		t.Fatalf("pgxpool: %v", err)
	}
	cleanup := func() {
		pool.Close()
		_ = container.Terminate(context.Background())
	}
	return pool, cleanup
}

// insertUser inserts a minimal user row with the given tier, matching the
// shape the signup branch uses. Synthesises placeholder first/last/email
// and an unusable password_hash so the NOT NULL columns from 0019 stay
// satisfied.
func insertUser(t *testing.T, pool *pgxpool.Pool, id, phone, acc, tier string) {
	t.Helper()
	email := id + "@test.local"
	_, err := pool.Exec(context.Background(), `
		INSERT INTO users (id, phone, account_number, kyc_tier, realm_key_version,
		                   first_name, last_name, email, password_hash)
		VALUES ($1, $2, $3, $4, 1, 'Test', 'User', $5, '')`,
		id, phone, acc, tier, email)
	if err != nil {
		t.Fatalf("insert user %s: %v", id, err)
	}
}

// setTier flips a user's kyc_tier so a single test can exercise multiple
// tiers against the same sender row.
func setTier(t *testing.T, pool *pgxpool.Pool, userID, tier string) {
	t.Helper()
	_, err := pool.Exec(context.Background(),
		`UPDATE users SET kyc_tier = $2, updated_at = now() WHERE id = $1`,
		userID, tier)
	if err != nil {
		t.Fatalf("set tier: %v", err)
	}
}

func newRef(t *testing.T, label string) string {
	t.Helper()
	return fmt.Sprintf("%s-%d", label, time.Now().UnixNano())
}

// TestInitiateTransfer_TierLimits exercises the canonical cases:
// TIER_0 blocks all, TIER_2 rejects over-single, TIER_2 accepts under,
// TIER_2 rejects a cumulative over-daily, and TIER_3 has no ceiling.
func TestInitiateTransfer_TierLimits(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	// nil fraud service: this suite exercises tier-limit paths only, and
	// keeping the fraud scorer out of the loop avoids contaminating the
	// CBN-tier assertions with velocity / novel-receiver noise.
	svc := New(pool, nil, nil)

	// Alice sends, Bob receives. Bob's tier is irrelevant (receivers are
	// not rate-limited here).
	insertUser(t, pool, "alice", "+2348100000001", "8100000001", TierZero)
	insertUser(t, pool, "bob", "+2348100000002", "8100000002", TierZero)

	t.Run("unverified blocks", func(t *testing.T) {
		_, err := svc.InitiateTransfer(ctx, InitiateTransferInput{
			SenderUserID:          "alice",
			ReceiverAccountNumber: "8100000002",
			AmountKobo:            100_00, // ₦100
			Reference:             newRef(t, "unverified"),
		})
		if !errors.Is(err, ErrTierBlocked) {
			t.Fatalf("want ErrTierBlocked, got %v", err)
		}
	})

	t.Run("kyc1 rejects over-single", func(t *testing.T) {
		setTier(t, pool, "alice", TierTwo)
		_, err := svc.InitiateTransfer(ctx, InitiateTransferInput{
			SenderUserID:          "alice",
			ReceiverAccountNumber: "8100000002",
			AmountKobo:            60_000_00, // ₦60k > ₦50k cap
			Reference:             newRef(t, "kyc1-over"),
		})
		if !errors.Is(err, ErrExceedsSingleLimit) {
			t.Fatalf("want ErrExceedsSingleLimit, got %v", err)
		}
	})

	t.Run("kyc1 accepts under-single", func(t *testing.T) {
		tr, err := svc.InitiateTransfer(ctx, InitiateTransferInput{
			SenderUserID:          "alice",
			ReceiverAccountNumber: "8100000002",
			AmountKobo:            40_000_00, // ₦40k
			Reference:             newRef(t, "kyc1-under-1"),
		})
		if err != nil {
			t.Fatalf("want accept, got %v", err)
		}
		if tr.AmountKobo != 40_000_00 {
			t.Fatalf("unexpected amount %d", tr.AmountKobo)
		}
	})

	t.Run("kyc1 second same-day hits daily", func(t *testing.T) {
		// Already spent ₦40k today. Another ₦40k would bring to ₦80k —
		// that's well under the ₦300k daily cap. We push until we hit.
		// Issue several ₦40k transfers to edge close to the daily cap
		// (need 7 more to exceed ₦300k: 40*8 = ₦320k > ₦300k).
		for i := 2; i <= 7; i++ {
			if _, err := svc.InitiateTransfer(ctx, InitiateTransferInput{
				SenderUserID:          "alice",
				ReceiverAccountNumber: "8100000002",
				AmountKobo:            40_000_00,
				Reference:             newRef(t, fmt.Sprintf("kyc1-fill-%d", i)),
			}); err != nil {
				t.Fatalf("fill %d: %v", i, err)
			}
		}
		// At this point alice has ₦280k today. Another ₦40k would be
		// ₦320k > ₦300k cap.
		_, err := svc.InitiateTransfer(ctx, InitiateTransferInput{
			SenderUserID:          "alice",
			ReceiverAccountNumber: "8100000002",
			AmountKobo:            40_000_00,
			Reference:             newRef(t, "kyc1-over-daily"),
		})
		if !errors.Is(err, ErrExceedsDailyLimit) {
			t.Fatalf("want ErrExceedsDailyLimit, got %v", err)
		}
	})

	t.Run("kyc3 unlimited", func(t *testing.T) {
		setTier(t, pool, "alice", TierThree)
		tr, err := svc.InitiateTransfer(ctx, InitiateTransferInput{
			SenderUserID:          "alice",
			ReceiverAccountNumber: "8100000002",
			AmountKobo:            1_000_000_00, // ₦1,000,000
			Reference:             newRef(t, "kyc3"),
		})
		if err != nil {
			t.Fatalf("kyc3 should accept, got %v", err)
		}
		if tr.AmountKobo != 1_000_000_00 {
			t.Fatalf("unexpected amount %d", tr.AmountKobo)
		}
	})
}
