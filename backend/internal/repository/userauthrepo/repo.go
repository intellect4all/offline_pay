// Package userauthrepo wraps sqlcgen for the end-user auth service
// (OTP challenges, user sessions, signup-time account provisioning).
// Admin auth lives in adminrepo.
package userauthrepo

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

// ErrNotFound is returned by lookups that expect exactly one row. The
// service maps this to ErrChallengeMissing / ErrUserNotFound depending
// on context.
var (
	ErrNotFound   = errors.New("userauthrepo: not found")
	ErrPhoneTaken = errors.New("userauthrepo: phone already registered")
	ErrEmailTaken = errors.New("userauthrepo: email already registered")
)

type Repo struct {
	pool  *pgxpool.Pool
	q     *sqlcgen.Queries
	cache cache.Cache
}

// New constructs a Repo. c may be nil → cache.Noop is used.
func New(pool *pgxpool.Pool, c cache.Cache) *Repo {
	if c == nil {
		c = cache.Noop{}
	}
	return &Repo{pool: pool, q: sqlcgen.New(pool), cache: c}
}

// UpsertOTPChallenge replaces any prior unconsumed challenge for
// (identifier, purpose) with a fresh code + expiry. Attempts reset to
// zero.
func (r *Repo) UpsertOTPChallenge(ctx context.Context, identifier, purpose, codeHash string, expiresAt time.Time) error {
	return r.q.UpsertOTPChallenge(ctx, sqlcgen.UpsertOTPChallengeParams{
		Identifier: identifier,
		Purpose:    purpose,
		CodeHash:   codeHash,
		ExpiresAt:  ts(expiresAt),
	})
}

// OTPChallenge is the service-facing projection. Fields line up 1:1
// with the columns userauth.Service actually reads.
type OTPChallenge struct {
	CodeHash   string
	Attempts   int
	ExpiresAt  time.Time
	ConsumedAt *time.Time
}

func (r *Repo) GetOTPChallenge(ctx context.Context, identifier, purpose string) (OTPChallenge, error) {
	row, err := r.q.GetOTPChallenge(ctx, sqlcgen.GetOTPChallengeParams{Identifier: identifier, Purpose: purpose})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return OTPChallenge{}, ErrNotFound
		}
		return OTPChallenge{}, err
	}
	return OTPChallenge{
		CodeHash:   row.CodeHash,
		Attempts:   int(row.Attempts),
		ExpiresAt:  row.ExpiresAt.Time,
		ConsumedAt: tsPtr(row.ConsumedAt),
	}, nil
}

func (r *Repo) IncrementOTPAttempts(ctx context.Context, identifier, purpose string) error {
	return r.q.IncrementOTPAttempts(ctx, sqlcgen.IncrementOTPAttemptsParams{Identifier: identifier, Purpose: purpose})
}

func (r *Repo) ConsumeOTPChallenge(ctx context.Context, identifier, purpose string) error {
	return r.q.ConsumeOTPChallenge(ctx, sqlcgen.ConsumeOTPChallengeParams{Identifier: identifier, Purpose: purpose})
}

// LoginRow is the narrow projection used by the password-login path.
type LoginRow struct {
	UserID        string
	AccountNumber string
	PasswordHash  string
}

// GetUserLoginByPhone returns the id/account/password_hash triple for a
// phone. ErrNotFound when the phone isn't registered.
func (r *Repo) GetUserLoginByPhone(ctx context.Context, phone string) (LoginRow, error) {
	row, err := r.q.GetUserLoginByPhone(ctx, phone)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return LoginRow{}, ErrNotFound
		}
		return LoginRow{}, err
	}
	return LoginRow{
		UserID:        row.ID,
		AccountNumber: row.AccountNumber,
		PasswordHash:  row.PasswordHash,
	}, nil
}

// GetUserEmail returns the registered email for a user plus its
// verification state.
func (r *Repo) GetUserEmail(ctx context.Context, userID string) (email string, verified bool, err error) {
	row, err := r.q.GetMeProjection(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", false, ErrNotFound
		}
		return "", false, err
	}
	return row.Email, row.EmailVerified, nil
}

// EmailExists reports whether a user row with this email exists. Used
// by the forgot-password flow to decide whether to send an OTP without
// surfacing the answer to the caller.
func (r *Repo) EmailExists(ctx context.Context, email string) (bool, error) {
	_, err := r.q.GetUserByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

// GetUserIDByEmail returns the user id for an email. ErrNotFound when
// the email isn't registered.
func (r *Repo) GetUserIDByEmail(ctx context.Context, email string) (string, error) {
	row, err := r.q.GetUserByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", ErrNotFound
		}
		return "", err
	}
	return row.ID, nil
}

// MarkEmailVerified flips email_verified to true. On success the
// cached /v1/me projection is invalidated so the next fetch reflects
// the new state.
func (r *Repo) MarkEmailVerified(ctx context.Context, userID string) error {
	if err := r.q.MarkEmailVerified(ctx, userID); err != nil {
		return err
	}
	_ = r.cache.Del(ctx, userMeCacheKey(userID))
	return nil
}

// UpdateUserPassword replaces the bcrypt password_hash. password_hash
// is not part of the /v1/me projection, so no cache invalidation is
// needed here.
func (r *Repo) UpdateUserPassword(ctx context.Context, userID, passwordHash string) error {
	return r.q.UpdateUserPassword(ctx, sqlcgen.UpdateUserPasswordParams{
		ID:           userID,
		PasswordHash: passwordHash,
	})
}

// Me is the narrow projection backing /v1/me.
type Me struct {
	ID            string
	Phone         string
	AccountNumber string
	KYCTier       string
	FirstName     string
	LastName      string
	Email         string
	EmailVerified bool
}

// GetMe returns the BFF /v1/me projection for one user id.
//
// Cached under user:me:<user_id> (TTL 5m). /v1/me is hit by every
// authenticated client on startup and after each refresh, so serving it
// from Redis removes a reliable per-session Postgres read. Writers that
// mutate the projection (MarkEmailVerified here, PromoteUserToTier in
// kycrepo.Submit) Del the key AFTER their DB commit — a cache failure
// never rolls back a committed write.
func (r *Repo) GetMe(ctx context.Context, userID string) (Me, error) {
	key := userMeCacheKey(userID)
	var cached Me
	if hit, _ := cache.GetJSON(ctx, r.cache, key, &cached); hit {
		return cached, nil
	}
	row, err := r.q.GetMeProjection(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Me{}, ErrNotFound
		}
		return Me{}, err
	}
	me := Me{
		ID:            row.ID,
		Phone:         row.Phone,
		AccountNumber: row.AccountNumber,
		KYCTier:       row.KycTier,
		FirstName:     row.FirstName,
		LastName:      row.LastName,
		Email:         row.Email,
		EmailVerified: row.EmailVerified,
	}
	_ = cache.SetJSON(ctx, r.cache, key, me, userMeCacheTTL)
	return me, nil
}

const userMeCacheTTL = 5 * time.Minute

// UserMeCacheKey is the cache key used by GetMe. Exported so sibling
// repos that mutate fields inside the /v1/me projection (e.g.
// kycrepo.Submit flipping kyc_tier) can invalidate without importing
// this package.
func UserMeCacheKey(userID string) string { return userMeCacheKey(userID) }

func userMeCacheKey(userID string) string { return "user:me:" + userID }

// GetUserAccountNumber returns the 10-digit account number for a user.
//
// Cached under user:acct:<user_id> (TTL 24h). Account numbers are
// immutable after signup, so no writer invalidates. TTL is the only
// bound (safety net against a schema migration that ever renumbers).
func (r *Repo) GetUserAccountNumber(ctx context.Context, userID string) (string, error) {
	key := userAccountNumberCacheKey(userID)
	var cached string
	if hit, _ := cache.GetJSON(ctx, r.cache, key, &cached); hit {
		return cached, nil
	}
	s, err := r.q.GetUserAccountNumber(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", ErrNotFound
		}
		return "", err
	}
	_ = cache.SetJSON(ctx, r.cache, key, s, userAccountNumberCacheTTL)
	return s, nil
}

const userAccountNumberCacheTTL = 24 * time.Hour

func userAccountNumberCacheKey(userID string) string { return "user:acct:" + userID }

type Session struct {
	ID        string
	UserID    string
	ExpiresAt time.Time
	RevokedAt *time.Time
}

func (r *Repo) GetUserSessionByRefreshHash(ctx context.Context, refreshHash string) (Session, error) {
	row, err := r.q.GetUserSessionByRefreshHash(ctx, refreshHash)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Session{}, ErrNotFound
		}
		return Session{}, err
	}
	return Session{
		ID:        row.ID,
		UserID:    row.UserID,
		ExpiresAt: row.ExpiresAt.Time,
		RevokedAt: tsPtr(row.RevokedAt),
	}, nil
}

func (r *Repo) RevokeUserSessionByHash(ctx context.Context, refreshHash string) error {
	return r.q.RevokeUserSessionByHash(ctx, refreshHash)
}

// OpenSessionInput bundles the values needed to open a new session on
// the login path.
type OpenSessionInput struct {
	SessionID   string
	UserID      string
	RefreshHash string
	UserAgent   string
	IP          string
	ExpiresAt   time.Time
}

// OpenSession creates a fresh user_sessions row.
func (r *Repo) OpenSession(ctx context.Context, in OpenSessionInput) error {
	return r.q.CreateUserSession(ctx, sqlcgen.CreateUserSessionParams{
		ID:          in.SessionID,
		UserID:      in.UserID,
		RefreshHash: in.RefreshHash,
		UserAgent:   in.UserAgent,
		Ip:          in.IP,
		ExpiresAt:   ts(in.ExpiresAt),
	})
}

type ActiveSession struct {
	ID        string
	UserAgent string
	IP        string
	DeviceID  *string
	CreatedAt time.Time
	ExpiresAt time.Time
}

func (r *Repo) ListActiveUserSessions(ctx context.Context, userID string) ([]ActiveSession, error) {
	rows, err := r.q.ListActiveUserSessions(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]ActiveSession, 0, len(rows))
	for _, row := range rows {
		out = append(out, ActiveSession{
			ID:        row.ID,
			UserAgent: row.UserAgent,
			IP:        row.Ip,
			DeviceID:  row.DeviceID,
			CreatedAt: row.CreatedAt.Time,
			ExpiresAt: row.ExpiresAt.Time,
		})
	}
	return out, nil
}

// GetUserSessionOwner returns the owner id + revocation state. Callers
// use this to enforce "revoke only your own sessions" semantics.
func (r *Repo) GetUserSessionOwner(ctx context.Context, sessionID string) (ownerID string, revokedAt *time.Time, err error) {
	row, err := r.q.GetUserSessionOwner(ctx, sessionID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", nil, ErrNotFound
		}
		return "", nil, err
	}
	return row.UserID, tsPtr(row.RevokedAt), nil
}

func (r *Repo) RevokeUserSessionByID(ctx context.Context, sessionID string) error {
	return r.q.RevokeUserSessionByID(ctx, sessionID)
}

// RevokeOtherUserSessions marks every active session for userID revoked
// except keepSessionID. Returns the number of rows touched.
func (r *Repo) RevokeOtherUserSessions(ctx context.Context, userID, keepSessionID string) (int64, error) {
	return r.q.RevokeOtherUserSessions(ctx, sqlcgen.RevokeOtherUserSessionsParams{
		UserID: userID,
		ID:     keepSessionID,
	})
}

// SetUserPIN upserts the bcrypt hash for a user and resets the attempt
// counter. Returns true when a row was written; ErrNotFound if the user
// id doesn't exist (surfaced via FK violation on user_pins.user_id).
func (r *Repo) SetUserPIN(ctx context.Context, userID, pinHash string) (bool, error) {
	n, err := r.q.SetUserPIN(ctx, sqlcgen.SetUserPINParams{
		UserID:  userID,
		PinHash: pinHash,
	})
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23503" && pgErr.ConstraintName == "user_pins_user_id_fkey" {
			return false, ErrNotFound
		}
		return false, err
	}
	return n > 0, nil
}

type PINState struct {
	Hash     string
	Attempts int
	LockedAt *time.Time
	Set      bool
}

func (r *Repo) GetUserPINState(ctx context.Context, userID string) (PINState, error) {
	row, err := r.q.GetUserPINState(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PINState{Set: false}, nil
		}
		return PINState{}, err
	}
	return PINState{
		Hash:     row.PinHash,
		Attempts: int(row.Attempts),
		LockedAt: tsPtr(row.LockedAt),
		Set:      true,
	}, nil
}

func (r *Repo) BumpPINAttempts(ctx context.Context, userID string, attempts int) error {
	return r.q.BumpPINAttempts(ctx, sqlcgen.BumpPINAttemptsParams{
		UserID:   userID,
		Attempts: int32(attempts),
	})
}

func (r *Repo) LockUserPIN(ctx context.Context, userID string, attempts int) error {
	return r.q.LockUserPIN(ctx, sqlcgen.LockUserPINParams{
		UserID:   userID,
		Attempts: int32(attempts),
	})
}

func (r *Repo) ClearUserPINAttempts(ctx context.Context, userID string) error {
	return r.q.ClearUserPINAttempts(ctx, userID)
}

// SignupInput bundles every field persisted during signup: the user
// row, the five canonical accounts, and the first session (so the
// client lands logged-in).
type SignupInput struct {
	UserID        string
	Phone         string
	Email         string
	FirstName     string
	LastName      string
	PasswordHash  string
	KYCTier       string
	AccountNumber string
	SessionID     string
	RefreshHash   string
	UserAgent     string
	IP            string
	RefreshExpires time.Time
	AccountIDs    [3]string // one per canonical account kind
}

// CanonicalAccountKinds mirrors the account set provisioned at signup.
// Must match the order of SignupInput.AccountIDs.
//
// Three kinds now — the former `offline` kind was retired in migration
// 0021 and the redundant `receiving_available` bucket was collapsed into
// `main` (Phase 4b credits main directly; see settlement.Service).
var CanonicalAccountKinds = [3]sqlcgen.AccountKind{
	sqlcgen.AccountKindMain,
	sqlcgen.AccountKindLienHolding,
	sqlcgen.AccountKindReceivingPending,
}

// Signup inserts the user row + five accounts + the first session in
// one tx. Maps a unique-violation on (phone) or (lower(email)) to the
// corresponding ErrPhoneTaken / ErrEmailTaken.
func (r *Repo) Signup(ctx context.Context, in SignupInput) error {
	return r.tx(ctx, func(q *sqlcgen.Queries) error {
		if _, err := q.CreateUserWithAccountNumber(ctx, sqlcgen.CreateUserWithAccountNumberParams{
			ID:              in.UserID,
			Phone:           in.Phone,
			AccountNumber:   in.AccountNumber,
			KycTier:         in.KYCTier,
			RealmKeyVersion: 1,
			FirstName:       in.FirstName,
			LastName:        in.LastName,
			Email:           in.Email,
			PasswordHash:    in.PasswordHash,
		}); err != nil {
			return classifyUniqueViolation(err)
		}
		for i, kind := range CanonicalAccountKinds {
			if _, err := q.CreateAccount(ctx, sqlcgen.CreateAccountParams{
				ID:          in.AccountIDs[i],
				UserID:      in.UserID,
				Kind:        kind,
				BalanceKobo: 0,
			}); err != nil {
				return err
			}
		}
		return q.CreateUserSession(ctx, sqlcgen.CreateUserSessionParams{
			ID:          in.SessionID,
			UserID:      in.UserID,
			RefreshHash: in.RefreshHash,
			UserAgent:   in.UserAgent,
			Ip:          in.IP,
			ExpiresAt:   ts(in.RefreshExpires),
		})
	})
}

// classifyUniqueViolation translates a pg 23505 against users into the
// repo's typed phone/email sentinels so the service can return the
// right HTTP 409 to the caller.
func classifyUniqueViolation(err error) error {
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) || pgErr.Code != "23505" {
		return err
	}
	switch pgErr.ConstraintName {
	case "users_phone_key":
		return ErrPhoneTaken
	case "idx_users_email":
		return ErrEmailTaken
	}
	// Some postgres builds report only the column via Detail; grep
	// there too so we still translate when the constraint name is
	// absent.
	if pgErr.Detail != "" {
		switch {
		case containsIgnoreCase(pgErr.Detail, "(phone)"):
			return ErrPhoneTaken
		case containsIgnoreCase(pgErr.Detail, "(lower(email))"),
			containsIgnoreCase(pgErr.Detail, "(email)"):
			return ErrEmailTaken
		}
	}
	return err
}

func containsIgnoreCase(haystack, needle string) bool {
	// Minimal helper — avoids pulling in strings just for one call.
	return len(haystack) >= len(needle) && indexFold(haystack, needle) >= 0
}

func indexFold(s, sub string) int {
	ns := len(s)
	nu := len(sub)
	for i := 0; i+nu <= ns; i++ {
		match := true
		for j := 0; j < nu; j++ {
			a := s[i+j]
			b := sub[j]
			if a >= 'A' && a <= 'Z' {
				a += 'a' - 'A'
			}
			if b >= 'A' && b <= 'Z' {
				b += 'a' - 'A'
			}
			if a != b {
				match = false
				break
			}
		}
		if match {
			return i
		}
	}
	return -1
}

// RotateSession revokes the prior refresh row and opens a new one
// atomically.
func (r *Repo) RotateSession(ctx context.Context, oldSessionID, newSessionID, userID, newRefreshHash string, newExpires time.Time) error {
	return r.tx(ctx, func(q *sqlcgen.Queries) error {
		if err := q.RevokeUserSessionByID(ctx, oldSessionID); err != nil {
			return err
		}
		return q.CreateUserSessionRotation(ctx, sqlcgen.CreateUserSessionRotationParams{
			ID:          newSessionID,
			UserID:      userID,
			RefreshHash: newRefreshHash,
			ExpiresAt:   ts(newExpires),
		})
	})
}

func (r *Repo) tx(ctx context.Context, fn func(*sqlcgen.Queries) error) error {
	tx, err := r.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("userauthrepo: begin tx: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback(context.Background())
		}
	}()
	if err := fn(r.q.WithTx(tx)); err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return err
	}
	committed = true
	return nil
}

func ts(t time.Time) pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: t, Valid: true}
}

func tsPtr(t pgtype.Timestamptz) *time.Time {
	if !t.Valid {
		return nil
	}
	v := t.Time
	return &v
}
