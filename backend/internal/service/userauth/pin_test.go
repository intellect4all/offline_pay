//go:build integration

// Integration tests for transaction-PIN behaviour. Runs with:
//
//	go test -tags=integration ./internal/service/userauth/...
//
// Spins up a disposable Postgres via testcontainers and applies the same
// migrations the BFF uses in prod.
package userauth

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

	"github.com/intellect/offlinepay/internal/repository/userauthrepo"
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

// insertUser creates a minimal user row so we can exercise the PIN paths
// without going through the full signup machinery. Satisfies the NOT
// NULL columns added in migration 0019 with placeholder values.
func insertUser(t *testing.T, pool *pgxpool.Pool, id, phone, acc string) {
	t.Helper()
	_, err := pool.Exec(context.Background(), `
		INSERT INTO users (id, phone, account_number, kyc_tier, realm_key_version,
		                   first_name, last_name, email, password_hash)
		VALUES ($1, $2, $3, 'TIER_0', 1, 'Test', 'User', $4, '')`,
		id, phone, acc, id+"@test.local")
	if err != nil {
		t.Fatalf("insert user: %v", err)
	}
}

func TestPIN_HappyAndLockout(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	svc := &Service{Repo: userauthrepo.New(pool, nil)}
	insertUser(t, pool, "user_a", "+2348100000001", "8100000001")

	// VerifyPIN before SetPIN -> ErrPINNotSet.
	if err := svc.VerifyPIN(ctx, "user_a", "1234"); err != ErrPINNotSet {
		t.Fatalf("want ErrPINNotSet, got %v", err)
	}

	// Invalid format is rejected for Set and Verify alike.
	if err := svc.SetPIN(ctx, "user_a", "abcd", ""); err != ErrInvalidPIN {
		t.Fatalf("want ErrInvalidPIN for non-numeric, got %v", err)
	}
	if err := svc.SetPIN(ctx, "user_a", "12345", ""); err != ErrInvalidPIN {
		t.Fatalf("want ErrInvalidPIN for 5 digits, got %v", err)
	}

	// Happy path: set + verify.
	if err := svc.SetPIN(ctx, "user_a", "1234", ""); err != nil {
		t.Fatalf("SetPIN: %v", err)
	}
	if err := svc.VerifyPIN(ctx, "user_a", "1234"); err != nil {
		t.Fatalf("VerifyPIN happy: %v", err)
	}

	// 5 consecutive wrong PINs -> 5th returns ErrPINLocked, subsequent
	// calls (even with the correct PIN) also return ErrPINLocked within
	// the rolling window.
	for i := 0; i < 4; i++ {
		if err := svc.VerifyPIN(ctx, "user_a", "0000"); err != ErrBadPIN {
			t.Fatalf("attempt %d: want ErrBadPIN, got %v", i+1, err)
		}
	}
	if err := svc.VerifyPIN(ctx, "user_a", "0000"); err != ErrPINLocked {
		t.Fatalf("attempt 5: want ErrPINLocked, got %v", err)
	}
	// Correct PIN during lockout window is still rejected as locked.
	if err := svc.VerifyPIN(ctx, "user_a", "1234"); err != ErrPINLocked {
		t.Fatalf("correct pin during lock: want ErrPINLocked, got %v", err)
	}

	// Reset (simulates admin clearing the lock) and confirm success path
	// zeros the counter.
	if _, err := pool.Exec(ctx,
		`UPDATE user_pins SET attempts = 0, locked_at = NULL WHERE user_id = $1`,
		"user_a"); err != nil {
		t.Fatalf("reset lock: %v", err)
	}
	if err := svc.VerifyPIN(ctx, "user_a", "1234"); err != nil {
		t.Fatalf("VerifyPIN after unlock: %v", err)
	}

	// SetPIN also clears any counter/lockout.
	if _, err := pool.Exec(ctx,
		`UPDATE user_pins SET attempts = 3, locked_at = now() WHERE user_id = $1`,
		"user_a"); err != nil {
		t.Fatalf("seed lock: %v", err)
	}
	if err := svc.SetPIN(ctx, "user_a", "123456", ""); err != nil {
		t.Fatalf("SetPIN reset: %v", err)
	}
	if err := svc.VerifyPIN(ctx, "user_a", "123456"); err != nil {
		t.Fatalf("VerifyPIN after SetPIN reset: %v", err)
	}

	// SetPIN on nonexistent user -> ErrUserNotFound.
	if err := svc.SetPIN(ctx, "nope", "1234", ""); err != ErrUserNotFound {
		t.Fatalf("want ErrUserNotFound, got %v", err)
	}
}
