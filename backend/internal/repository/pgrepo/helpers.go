package pgrepo

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

// RegisterUserWithID is a variant of RegisterUser that accepts a
// caller-supplied user id. Used by the registration transport where the
// client/KYC flow has already minted a user id and wants to attach a
// device to it. Emits the same users row + five accounts as RegisterUser.
//
// Idempotent: if a user with this id already exists (e.g. created by
// the BFF signup path), the call is a no-op. Device registration is a
// separate concern from user provisioning — this keeps the two
// decoupled so re-registering a device never collides with existing
// user primary data.
//
// `accountNumber` may be empty; one is then derived from the trailing
// 10 digits of the phone (left-padded with '0'). Real signup flows pass
// the BFF-issued account number explicitly.
func (r *Repo) RegisterUserWithID(ctx context.Context, userID, phone, accountNumber, bvn, kycTier string, realmKeyVersion int) error {
	if userID == "" {
		return errors.New("pgrepo: userID required")
	}
	if phone == "" {
		phone = "+registered-" + userID
	}
	if kycTier == "" {
		kycTier = "TIER_0"
	}
	if accountNumber == "" {
		accountNumber = deriveAccountNumberFromPhone(phone)
	}
	return r.Tx(ctx, func(tx *Repo) error {
		if _, err := tx.q.GetUserPhoneByID(ctx, userID); err == nil {
			return nil
		} else if !errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("check user existence: %w", err)
		}
		var bvnPtr *string
		if bvn != "" {
			bvnPtr = &bvn
		}
		if _, err := tx.q.CreateUser(ctx, sqlcgen.CreateUserParams{
			ID:                  userID,
			Phone:               phone,
			AccountNumber:       accountNumber,
			Bvn:                 bvnPtr,
			KycTier:             kycTier,
			DeviceAttestationID: nil,
			RealmKeyVersion:     int32(realmKeyVersion),
			FirstName:           "",
			LastName:            "",
			Email:               placeholderEmail(userID),
			PasswordHash:        "",
		}); err != nil {
			return fmt.Errorf("create user: %w", err)
		}
		for _, kind := range AllAccountKinds {
			if _, err := tx.q.CreateAccount(ctx, sqlcgen.CreateAccountParams{
				ID:          NewID(),
				UserID:      userID,
				Kind:        kind,
				BalanceKobo: 0,
			}); err != nil {
				return fmt.Errorf("create account %s: %w", kind, err)
			}
		}
		return nil
	})
}

// placeholderEmail synthesises a unique email for legacy/test seed
// paths that don't carry a real address. The UNIQUE index on
// lower(email) requires uniqueness; keying on userID guarantees that.
// Bcrypt-compare against an empty password_hash always fails, so rows
// created via this path cannot log in.
func placeholderEmail(userID string) string {
	return "device-" + userID + "@placeholder.local"
}

// deriveAccountNumberFromPhone strips non-digits and returns the trailing
// 10 characters left-padded with '0'. Always returns exactly 10
// characters so the CHAR(10) column accepts the value.
func deriveAccountNumberFromPhone(phone string) string {
	var b strings.Builder
	for _, r := range phone {
		if r >= '0' && r <= '9' {
			b.WriteRune(r)
		}
	}
	digits := b.String()
	if len(digits) >= 10 {
		return digits[len(digits)-10:]
	}
	return strings.Repeat("0", 10-len(digits)) + digits
}

// IsUniqueViolation reports whether err is a Postgres unique-violation
// (SQLSTATE 23505). Falls back to substring match for wrapped/fake errors.
func IsUniqueViolation(err error) bool {
	if err == nil {
		return false
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return pgErr.Code == "23505"
	}
	return strings.Contains(err.Error(), "duplicate key") ||
		strings.Contains(err.Error(), "unique constraint")
}
