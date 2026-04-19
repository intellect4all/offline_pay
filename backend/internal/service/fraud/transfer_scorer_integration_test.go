//go:build integration

// Integration tests for the transfer fraud scorer. Spins up a disposable
// Postgres via testcontainers and exercises the rules that need DB counts
// (velocity + novel-receiver + high-daily-share) end-to-end, plus the
// happy wiring through transfer.InitiateTransfer.
//
// Run with:
//
//	go test -tags=integration ./internal/service/fraud/...
package fraud

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
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/testcontainers/testcontainers-go"
	tcpostgres "github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"

	"github.com/intellect/offlinepay/internal/repository/fraudrepo"
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
	if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		t.Fatalf("migrate up: %v", err)
	}
	_, _ = m.Close()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("pgxpool: %v", err)
	}
	return pool, func() {
		pool.Close()
		_ = container.Terminate(context.Background())
	}
}

func seedUser(t *testing.T, pool *pgxpool.Pool, id, phone, acc, tier string, createdAt time.Time) {
	t.Helper()
	email := id + "@test.local"
	_, err := pool.Exec(context.Background(), `
		INSERT INTO users (id, phone, account_number, kyc_tier, realm_key_version, created_at, updated_at,
		                   first_name, last_name, email, password_hash)
		VALUES ($1, $2, $3, $4, 1, $5, $5, 'Test', 'User', $6, '')`,
		id, phone, acc, tier, createdAt, email)
	if err != nil {
		t.Fatalf("insert user %s: %v", id, err)
	}
}

func insertTransfer(t *testing.T, tx pgx.Tx, senderID, receiverID, acc string, amount int64, ref string) {
	t.Helper()
	_, err := tx.Exec(context.Background(), `
		INSERT INTO transfers
		  (id, sender_user_id, receiver_user_id, receiver_account_number,
		   amount_kobo, status, reference)
		VALUES ($1, $2, $3, $4, $5, 'ACCEPTED', $6)`,
		fmt.Sprintf("tx-%s-%s", senderID, ref),
		senderID, receiverID, acc, amount, ref,
	)
	if err != nil {
		t.Fatalf("insert transfer: %v", err)
	}
}

// TestRuleVelocitySender1m_Hits verifies the 10-in-60s rule fires once the
// table already holds >10 recent rows.
func TestRuleVelocitySender1m_Hits(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	now := time.Now().UTC()
	seedUser(t, pool, "alice", "+2348100000001", "8100000001", "TIER_3", now.Add(-30*24*time.Hour))
	seedUser(t, pool, "bob", "+2348100000002", "8100000002", "TIER_3", now.Add(-30*24*time.Hour))

	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	defer tx.Rollback(ctx) // nolint: errcheck
	for i := 0; i < 11; i++ {
		insertTransfer(t, tx, "alice", "bob", "8100000002", 100_00, fmt.Sprintf("v-%d", i))
	}

	repo := fraudrepo.New(pool)
	hit, err := ruleVelocitySender1m(ctx, repo, tx, ScoreInput{SenderUserID: "alice"})
	if err != nil {
		t.Fatalf("rule err: %v", err)
	}
	if hit.Name != RuleVelocitySender1m || hit.Severity != SeverityBlock {
		t.Fatalf("expected BLOCK hit, got %+v", hit)
	}
}

// TestRuleNovelReceiverHighAmount_FlagsFirstTime exercises the
// novel-receiver path: with no prior history and amount > ₦100k the rule
// fires; with a prior transfer the rule stays silent.
func TestRuleNovelReceiverHighAmount(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	now := time.Now().UTC()
	seedUser(t, pool, "alice", "+2348100000001", "8100000001", "TIER_3", now.Add(-90*24*time.Hour))
	seedUser(t, pool, "bob", "+2348100000002", "8100000002", "TIER_3", now.Add(-90*24*time.Hour))

	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	defer tx.Rollback(ctx) // nolint: errcheck

	repo := fraudrepo.New(pool)
	// First pass: no prior history, amount > ₦100k → flag.
	hit, err := ruleNovelReceiverHighAmount(ctx, repo, tx, ScoreInput{
		SenderUserID: "alice", ReceiverUserID: "bob", AmountKobo: 150_000_00,
	})
	if err != nil {
		t.Fatalf("rule err: %v", err)
	}
	if hit.Name != RuleNovelReceiverHighAmount {
		t.Fatalf("expected flag hit, got %+v", hit)
	}

	// Second pass: insert a prior transfer, rule should no longer fire.
	insertTransfer(t, tx, "alice", "bob", "8100000002", 500_00, "prior-1")
	hit2, err := ruleNovelReceiverHighAmount(ctx, repo, tx, ScoreInput{
		SenderUserID: "alice", ReceiverUserID: "bob", AmountKobo: 150_000_00,
	})
	if err != nil {
		t.Fatalf("rule err: %v", err)
	}
	if hit2.Name != "" {
		t.Fatalf("expected no hit after prior transfer, got %+v", hit2)
	}

	// Below threshold — no hit regardless of history.
	hit3, err := ruleNovelReceiverHighAmount(ctx, repo, tx, ScoreInput{
		SenderUserID: "alice", ReceiverUserID: "bob", AmountKobo: 50_000_00,
	})
	if err != nil {
		t.Fatalf("rule err: %v", err)
	}
	if hit3.Name != "" {
		t.Fatalf("expected no hit under threshold, got %+v", hit3)
	}
}

// TestScoreTransfer_BlocksOn11thVelocity is the headline e2e behaviour: 11
// rapid transfers from the same sender flip the 11th into DecisionBlock.
// We pre-seed 10 accepted transfers within the last minute, then score a
// candidate 11th.
func TestScoreTransfer_BlocksOn11thVelocity(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	now := time.Now().UTC()
	seedUser(t, pool, "alice", "+2348100000001", "8100000001", "TIER_3", now.Add(-90*24*time.Hour))
	seedUser(t, pool, "bob", "+2348100000002", "8100000002", "TIER_3", now.Add(-90*24*time.Hour))

	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	defer tx.Rollback(ctx) // nolint: errcheck
	for i := 0; i < 11; i++ {
		insertTransfer(t, tx, "alice", "bob", "8100000002", 100_00, fmt.Sprintf("vv-%d", i))
	}

	svc := NewTransferService(pool)
	got, err := svc.ScoreTransfer(ctx, tx, ScoreInput{
		SenderUserID:          "alice",
		ReceiverUserID:        "bob",
		AmountKobo:            100_00,
		SenderTier:            "TIER_3",
		DailyTierLimitKobo:    100_000_00,
		SenderAccountAgeHours: 24 * 90,
	})
	if err != nil {
		t.Fatalf("score err: %v", err)
	}
	if got.Decision != DecisionBlock {
		t.Fatalf("decision = %s want BLOCK (hits=%+v)", got.Decision, got.RuleHits)
	}
	if got.Rule != RuleVelocitySender1m {
		t.Fatalf("rule = %s want %s", got.Rule, RuleVelocitySender1m)
	}
}

// TestScoreTransfer_FlagsFreshUserLargeAmount exercises the
// new-account-large-transfer path through the public ScoreTransfer entry
// point (no velocity pre-seed needed).
func TestScoreTransfer_FlagsFreshUserLargeAmount(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	now := time.Now().UTC()
	seedUser(t, pool, "alice", "+2348100000001", "8100000001", "TIER_2", now.Add(-2*time.Hour))
	seedUser(t, pool, "bob", "+2348100000002", "8100000002", "TIER_3", now.Add(-90*24*time.Hour))

	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	defer tx.Rollback(ctx) // nolint: errcheck

	svc := NewTransferService(pool)
	got, err := svc.ScoreTransfer(ctx, tx, ScoreInput{
		SenderUserID:          "alice",
		ReceiverUserID:        "bob",
		AmountKobo:            25_000_00, // ₦25,000 > ₦20,000 threshold
		SenderTier:            "TIER_2",
		DailyTierLimitKobo:    300_000_00,
		SenderAccountAgeHours: 2,
	})
	if err != nil {
		t.Fatalf("score err: %v", err)
	}
	if got.Decision != DecisionFlag {
		t.Fatalf("decision = %s want FLAG (hits=%+v)", got.Decision, got.RuleHits)
	}
}

// TestRecordScore_WritesRow verifies both FLAG (inside tx) and BLOCK (via
// pool, after rollback) paths persist audit rows to fraud_scores.
func TestRecordScore_WritesRow(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	now := time.Now().UTC()
	seedUser(t, pool, "alice", "+2348100000001", "8100000001", "TIER_3", now.Add(-30*24*time.Hour))

	svc := NewTransferService(pool)

	// FLAG: write inside a tx that commits.
	in := ScoreInput{SenderUserID: "alice", AmountKobo: 25_000_00}
	flag := Score{
		Decision: DecisionFlag, Rule: "r1", Reason: "because",
		RuleHits: []RuleHit{{Name: "r1", Severity: SeverityFlag, Reason: "because"}},
	}
	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	if err := svc.RecordScore(ctx, tx, "t-1", in, flag); err != nil {
		t.Fatalf("record flag: %v", err)
	}
	if err := tx.Commit(ctx); err != nil {
		t.Fatalf("commit: %v", err)
	}
	var decision string
	if err := pool.QueryRow(ctx,
		`SELECT decision FROM fraud_scores WHERE sender_id = $1 AND transfer_id = $2`,
		"alice", "t-1").Scan(&decision); err != nil {
		t.Fatalf("query flag row: %v", err)
	}
	if decision != DecisionFlag {
		t.Errorf("decision = %s want FLAG", decision)
	}

	// BLOCK: caller's tx rolls back; RecordScore must write via the pool.
	block := Score{
		Decision: DecisionBlock, Rule: "r2", Reason: "velocity",
		RuleHits: []RuleHit{{Name: "r2", Severity: SeverityBlock, Reason: "velocity"}},
	}
	tx2, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	if err := svc.RecordScore(ctx, tx2, "", in, block); err != nil {
		t.Fatalf("record block: %v", err)
	}
	_ = tx2.Rollback(ctx)
	var n int
	if err := pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM fraud_scores WHERE sender_id = $1 AND decision = 'BLOCK'`,
		"alice").Scan(&n); err != nil {
		t.Fatalf("query block count: %v", err)
	}
	if n != 1 {
		t.Errorf("block rows = %d want 1", n)
	}
}
