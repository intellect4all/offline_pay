package userauth

import (
	"context"
	"errors"
	"regexp"
	"time"

	"golang.org/x/crypto/bcrypt"

	"github.com/intellect/offlinepay/internal/repository/userauthrepo"
)

// Transaction-PIN errors. Exported so transport handlers can map them to
// HTTP codes (pin_bad / pin_locked / pin_not_set).
var (
	ErrInvalidPIN = errors.New("userauth: pin must be 4 or 6 digits")
	ErrBadPIN     = errors.New("userauth: wrong pin")
	ErrPINLocked  = errors.New("userauth: pin locked")
	ErrPINNotSet  = errors.New("userauth: pin not set")
)

const (
	// pinMaxAttempts is the number of consecutive wrong PINs that triggers a
	// lockout. Matches the OTP attempt cap for consistency.
	pinMaxAttempts = 5

	// pinLockWindow is the rolling window during which a recorded
	// pin_locked_at still counts as "locked". Callers can unlock by waiting
	// out the window (or an admin can clear pin_locked_at).
	pinLockWindow = 15 * time.Minute

	// pinBcryptCost matches the cost used elsewhere (OTP).
	pinBcryptCost = 10
)

var pinRe = regexp.MustCompile(`^[0-9]{4}$|^[0-9]{6}$`)

// SetPIN validates, hashes, and stores a user's transaction PIN. It resets
// the attempt counter and clears any prior lockout so the user can start
// fresh immediately after a reset.
//
// As a bank-grade safety hook, SetPIN ALSO force-revokes every other
// active session for the user, keeping only the one identified by
// currentSessionID (typically the caller's claims.Sid). This ensures:
//
//   - If an attacker somehow sets a new PIN on a stolen session, all other
//     devices drop out (refresh returns 401 on next attempt).
//   - If the legitimate user changes their PIN on device A, devices B and
//     C are evicted too; they will naturally prompt for re-login.
//
// currentSessionID may be empty — in that case EVERY session for the user
// (including the caller's) is revoked. Callers that want to preserve the
// caller's session must pass a valid sid.
func (s *Service) SetPIN(ctx context.Context, userID, pin, currentSessionID string) error {
	if userID == "" {
		return errors.New("userauth: user_id required")
	}
	if !pinRe.MatchString(pin) {
		return ErrInvalidPIN
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(pin), pinBcryptCost)
	if err != nil {
		return err
	}
	ok, err := s.Repo.SetUserPIN(ctx, userID, string(hash))
	if err != nil {
		if errors.Is(err, userauthrepo.ErrNotFound) {
			return ErrUserNotFound
		}
		return err
	}
	if !ok {
		return ErrUserNotFound
	}
	// Revoke every other active session for this user. We do this
	// post-commit (not in the same tx) because the PIN update has to
	// succeed even if the session sweep is later retried.
	if _, err := s.Repo.RevokeOtherUserSessions(ctx, userID, currentSessionID); err != nil {
		return err
	}
	return nil
}

// VerifyPIN checks a candidate PIN against the stored bcrypt hash,
// incrementing the attempt counter on mismatch and latching pin_locked_at
// at the configured cap. Success resets the counter. Returns
// ErrPINNotSet if the user never set a PIN, ErrPINLocked if currently
// locked (or if this call was the lockout trigger), and ErrBadPIN for a
// plain wrong-PIN below the lockout threshold.
func (s *Service) VerifyPIN(ctx context.Context, userID, pin string) error {
	if userID == "" {
		return errors.New("userauth: user_id required")
	}
	if !pinRe.MatchString(pin) {
		return ErrInvalidPIN
	}
	st, err := s.Repo.GetUserPINState(ctx, userID)
	if err != nil {
		return err
	}
	if !st.Set || st.Hash == "" {
		return ErrPINNotSet
	}
	if st.LockedAt != nil && time.Since(*st.LockedAt) < pinLockWindow {
		return ErrPINLocked
	}
	if bcrypt.CompareHashAndPassword([]byte(st.Hash), []byte(pin)) != nil {
		newAttempts := st.Attempts + 1
		if newAttempts >= pinMaxAttempts {
			if err := s.Repo.LockUserPIN(ctx, userID, newAttempts); err != nil {
				return err
			}
			return ErrPINLocked
		}
		if err := s.Repo.BumpPINAttempts(ctx, userID, newAttempts); err != nil {
			return err
		}
		return ErrBadPIN
	}
	// Success — clear attempt counter. (pin_locked_at was already past the
	// window or null; reset it too so the row is clean.)
	return s.Repo.ClearUserPINAttempts(ctx, userID)
}
