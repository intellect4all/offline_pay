//go:build integration

// Integration tests for the session-management service layer. Runs with:
//
//	go test -tags=integration ./internal/service/userauth/...
//
// Uses the same testcontainers-backed Postgres helper as pin_test.go
// (startPostgres + migrationsDir in that file).
package userauth

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/intellect/offlinepay/internal/repository/userauthrepo"
)

func TestSessions_ListRevokeRevokeAll(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	svc := &Service{Repo: userauthrepo.New(pool, nil)}
	insertUser(t, pool, "user_sess", "+2348100000042", "8100000042")

	// Three sessions: A (current), B (other active), C (already revoked),
	// D (expired).
	mk := func(id, hash string, expires time.Time, revoked bool) {
		t.Helper()
		if _, err := pool.Exec(ctx, `
			INSERT INTO user_sessions (id, user_id, refresh_hash, user_agent, ip, expires_at, revoked_at)
			VALUES ($1, $2, $3, 'ua-'||$1, '1.1.1.1', $4, $5)`,
			id, "user_sess", hash, expires, func() interface{} {
				if revoked {
					return time.Now()
				}
				return nil
			}()); err != nil {
			t.Fatalf("seed session %s: %v", id, err)
		}
	}
	future := time.Now().Add(24 * time.Hour)
	past := time.Now().Add(-time.Hour)
	mk("sess_A", "hash_A", future, false)
	mk("sess_B", "hash_B", future, false)
	mk("sess_C", "hash_C", future, true)
	mk("sess_D", "hash_D", past, false)

	// ListSessions only surfaces the two active, non-expired rows.
	list, err := svc.ListSessions(ctx, "user_sess")
	if err != nil {
		t.Fatalf("ListSessions: %v", err)
	}
	if len(list) != 2 {
		t.Fatalf("want 2 sessions, got %d: %+v", len(list), list)
	}
	gotIDs := map[string]bool{}
	for _, s := range list {
		gotIDs[s.ID] = true
	}
	if !gotIDs["sess_A"] || !gotIDs["sess_B"] {
		t.Fatalf("want sess_A and sess_B, got %v", gotIDs)
	}

	// Revoking the current session is rejected.
	if err := svc.RevokeSession(ctx, "user_sess", "sess_A", "sess_A"); !errors.Is(err, ErrCannotRevokeCurrent) {
		t.Fatalf("want ErrCannotRevokeCurrent, got %v", err)
	}

	// Revoking a session owned by someone else is indistinguishable from
	// not-found.
	insertUser(t, pool, "user_other", "+2348100000043", "8100000043")
	mk2 := func(id, owner string) {
		if _, err := pool.Exec(ctx, `
			INSERT INTO user_sessions (id, user_id, refresh_hash, expires_at)
			VALUES ($1, $2, $3, $4)`, id, owner, id+"-hash", future); err != nil {
			t.Fatalf("mk2: %v", err)
		}
	}
	mk2("sess_foreign", "user_other")
	if err := svc.RevokeSession(ctx, "user_sess", "sess_foreign", "sess_A"); !errors.Is(err, ErrSessionNotFound) {
		t.Fatalf("want ErrSessionNotFound for foreign row, got %v", err)
	}
	if err := svc.RevokeSession(ctx, "user_sess", "sess_DOES_NOT_EXIST", "sess_A"); !errors.Is(err, ErrSessionNotFound) {
		t.Fatalf("want ErrSessionNotFound for missing row, got %v", err)
	}

	// Revoking the other active session flips its revoked_at and it
	// drops out of ListSessions.
	if err := svc.RevokeSession(ctx, "user_sess", "sess_B", "sess_A"); err != nil {
		t.Fatalf("RevokeSession sess_B: %v", err)
	}
	// Idempotent: calling again is a no-op success (already revoked).
	if err := svc.RevokeSession(ctx, "user_sess", "sess_B", "sess_A"); err != nil {
		t.Fatalf("RevokeSession sess_B (idempotent): %v", err)
	}
	list2, err := svc.ListSessions(ctx, "user_sess")
	if err != nil {
		t.Fatalf("ListSessions 2: %v", err)
	}
	if len(list2) != 1 || list2[0].ID != "sess_A" {
		t.Fatalf("want only sess_A, got %+v", list2)
	}

	// Reset state: add two more active sessions alongside sess_A.
	// sess_D (expired but not revoked) will also fall into the sweep
	// because RevokeAllOtherSessions filters on revoked_at IS NULL rather
	// than on expiry — we only care about refresh viability, which expiry
	// already invalidates, but marking them revoked keeps the ledger tidy.
	mk("sess_E", "hash_E", future, false)
	mk("sess_F", "hash_F", future, false)
	n, err := svc.RevokeAllOtherSessions(ctx, "user_sess", "sess_A")
	if err != nil {
		t.Fatalf("RevokeAllOtherSessions: %v", err)
	}
	if n != 3 {
		t.Fatalf("want 3 revoked (sess_D expired + sess_E + sess_F), got %d", n)
	}
	// Second call revokes zero (everything else already revoked).
	n2, err := svc.RevokeAllOtherSessions(ctx, "user_sess", "sess_A")
	if err != nil {
		t.Fatalf("RevokeAllOtherSessions 2: %v", err)
	}
	if n2 != 0 {
		t.Fatalf("want 0 on second call, got %d", n2)
	}
	list3, err := svc.ListSessions(ctx, "user_sess")
	if err != nil {
		t.Fatalf("ListSessions 3: %v", err)
	}
	if len(list3) != 1 || list3[0].ID != "sess_A" {
		t.Fatalf("want only sess_A, got %+v", list3)
	}
}

// TestSetPIN_RevokesOtherSessions verifies the bank-grade PIN-change
// invariant: rotating the PIN force-revokes every OTHER live session for
// the user, keeping only the caller's own.
func TestSetPIN_RevokesOtherSessions(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	svc := &Service{Repo: userauthrepo.New(pool, nil)}
	insertUser(t, pool, "user_pin_sess", "+2348100000044", "8100000044")

	future := time.Now().Add(24 * time.Hour)
	insert := func(id string) {
		if _, err := pool.Exec(ctx, `
			INSERT INTO user_sessions (id, user_id, refresh_hash, expires_at)
			VALUES ($1, $2, $3, $4)`, id, "user_pin_sess", id+"-hash", future); err != nil {
			t.Fatalf("seed %s: %v", id, err)
		}
	}
	insert("sess_keep")
	insert("sess_evict_1")
	insert("sess_evict_2")

	// SetPIN should succeed and sweep the two non-current sessions.
	if err := svc.SetPIN(ctx, "user_pin_sess", "1234", "sess_keep"); err != nil {
		t.Fatalf("SetPIN: %v", err)
	}
	remaining, err := svc.ListSessions(ctx, "user_pin_sess")
	if err != nil {
		t.Fatalf("ListSessions post-SetPIN: %v", err)
	}
	if len(remaining) != 1 || remaining[0].ID != "sess_keep" {
		t.Fatalf("want only sess_keep, got %+v", remaining)
	}

	// Rotating PIN again with empty sid revokes ALL remaining sessions
	// (including the one we just preserved).
	if err := svc.SetPIN(ctx, "user_pin_sess", "5678", ""); err != nil {
		t.Fatalf("SetPIN rotate with empty sid: %v", err)
	}
	remaining2, err := svc.ListSessions(ctx, "user_pin_sess")
	if err != nil {
		t.Fatalf("ListSessions post-2nd-SetPIN: %v", err)
	}
	if len(remaining2) != 0 {
		t.Fatalf("want zero sessions, got %+v", remaining2)
	}
}
