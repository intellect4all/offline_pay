// rotate_realm_key mints a new realm-key version and marks the previous
// active version retired with an overlap window.
//
// The realm key is the AES-256-GCM symmetric key that all registered apps
// share to encrypt/decrypt QR payloads. Rotating it is a three-step ritual
// in a single transaction:
//
//  1. Insert a new row with version = max(version)+1, active_from = now(),
//     retired_at = NULL. This becomes the key clients seal to.
//  2. UPDATE every currently-active row (retired_at IS NULL) that is NOT
//     the new one to retired_at = now() + overlap. Those keys remain
//     decrypt-only so clients who were offline through the rotation can
//     still decode their backlog.
//  3. DELETE any row whose retired_at has already elapsed. At that point
//     QRs sealed under those versions become permanently undecryptable;
//     that is the forward-secrecy property operators bank on.
//
// Usage:
//
//	go run ./cmd/rotate_realm_key \
//	  --dsn=postgres://offlinepay:offlinepay@localhost:5432/offlinepay?sslmode=disable \
//	  --overlap-days=30
package main

import (
	"context"
	"crypto/rand"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"log/slog"
	"os"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"

	"github.com/intellect/offlinepay/internal/cache"
)

func main() {
	var (
		dsn      string
		overlap  int
	)
	flag.StringVar(&dsn, "dsn", os.Getenv("DB_URL"), "Postgres DSN")
	flag.IntVar(&overlap, "overlap-days", 30, "days the previous key remains decrypt-only")
	flag.Parse()

	if dsn == "" {
		log.Fatal("--dsn required (or DB_URL env)")
	}
	if overlap < 0 {
		log.Fatal("--overlap-days must be >= 0")
	}

	if err := run(dsn, overlap); err != nil {
		log.Fatalf("rotate_realm_key: %v", err)
	}
}

func run(dsn string, overlapDays int) error {
	ctx := context.Background()
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return fmt.Errorf("open db: %w", err)
	}
	defer db.Close()
	if err := db.PingContext(ctx); err != nil {
		return fmt.Errorf("ping: %w", err)
	}

	keyBytes := make([]byte, 32)
	if _, err := rand.Read(keyBytes); err != nil {
		return fmt.Errorf("generate key: %w", err)
	}

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	var newVersion int
	if err := tx.QueryRowContext(ctx,
		`SELECT COALESCE(MAX(version), 0) + 1 FROM realm_keys`,
	).Scan(&newVersion); err != nil {
		return fmt.Errorf("next version: %w", err)
	}

	now := time.Now().UTC()
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO realm_keys (version, key_enc, active_from) VALUES ($1, $2, $3)`,
		newVersion, keyBytes, now,
	); err != nil {
		return fmt.Errorf("insert new key: %w", err)
	}

	retiredAt := now.Add(time.Duration(overlapDays) * 24 * time.Hour)
	res, err := tx.ExecContext(ctx,
		`UPDATE realm_keys SET retired_at = $2
		   WHERE retired_at IS NULL AND version <> $1`,
		newVersion, retiredAt,
	)
	if err != nil {
		return fmt.Errorf("retire previous: %w", err)
	}
	retired, _ := res.RowsAffected()

	// Hard-GC anything whose overlap window has already elapsed.
	res, err = tx.ExecContext(ctx,
		`DELETE FROM realm_keys WHERE retired_at IS NOT NULL AND retired_at <= now()`,
	)
	if err != nil {
		return fmt.Errorf("gc expired: %w", err)
	}
	purged, _ := res.RowsAffected()

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit: %w", err)
	}

	log.Printf("rotated realm key: new_version=%d retired_rows=%d purged_rows=%d retired_at=%s",
		newVersion, retired, purged, retiredAt.Format(time.RFC3339))

	// Best-effort invalidation of the realm-key cache entries. If
	// REDIS_URL is unset or Redis is unreachable, the 1h TTL safety
	// net in pgrepo still bounds staleness; we only warn.
	if redisURL := os.Getenv("REDIS_URL"); redisURL != "" {
		rdb, err := cache.NewRedis(ctx, redisURL, slog.Default())
		if err != nil {
			slog.Warn("rotate_realm_key: redis unreachable; cache entries will fall out via TTL", "err", err)
		} else {
			defer rdb.Close()
			// Key names MUST match realmActiveCacheKey / realmActiveListCacheKey
			// in internal/repository/pgrepo/repo.go. Hard-coded here to
			// avoid pulling the full pgrepo dependency into this tiny cmd.
			if err := rdb.Del(ctx, "realm:active", "realm:active:list"); err != nil {
				slog.Warn("rotate_realm_key: cache del failed", "err", err)
			} else {
				log.Printf("rotate_realm_key: invalidated realm-key cache entries")
			}
		}
	}
	return nil
}
