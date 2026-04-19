// Package identity issues the server-signed DisplayCard that every user
// embeds in the PaymentRequests they publish. The card binds a user_id to
// a human-readable display_name + account_number, signed by the active
// bank key so payers can verify it against the already-cached bank pubkey
// without a second round trip.
//
// Cards are stateless — re-issued on demand rather than persisted. Name
// changes are picked up by the next call (the client refreshes via
// GET /v1/identity/display-card).
package identity

import (
	"context"
	"crypto/ed25519"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/intellect/offlinepay/internal/crypto"
	"github.com/intellect/offlinepay/internal/domain"
)

// Clock abstracts time for tests.
type Clock interface{ Now() time.Time }

type systemClock struct{}

func (systemClock) Now() time.Time { return time.Now().UTC() }

// MeRow is the minimal user projection the identity service needs.
// Matches userauthrepo.Me so a pgrepo-wrapping adapter can satisfy both.
type MeRow struct {
	UserID        string
	FirstName     string
	LastName      string
	AccountNumber string
}

// Repository is the narrow repo subset the identity service consumes.
type Repository interface {
	GetMe(ctx context.Context, userID string) (MeRow, error)
	GetActiveBankSigningKey(ctx context.Context) (domain.BankSigningKey, error)
}

// Signer is the optional KMS-backed signer. When nil, the service falls
// back to signing with the bank private key fetched from the repo.
type Signer = crypto.CeilingSigner

// ErrUserNotFound is returned when the caller's user_id doesn't resolve.
var ErrUserNotFound = errors.New("identity: user not found")

// Service issues DisplayCards.
type Service struct {
	Repo   Repository
	Signer Signer
	Clock  Clock
}

// New constructs a Service with production defaults.
func New(repo Repository, signer Signer) *Service {
	return &Service{Repo: repo, Signer: signer, Clock: systemClock{}}
}

// IssueDisplayCard returns a server-signed DisplayCard for userID. The
// display_name is "First Last" (or the non-empty half if either is
// missing). Empty names fall back to the account number.
func (s *Service) IssueDisplayCard(ctx context.Context, userID string) (domain.DisplayCard, error) {
	me, err := s.Repo.GetMe(ctx, userID)
	if err != nil {
		return domain.DisplayCard{}, fmt.Errorf("identity: load user: %w", err)
	}
	if me.UserID == "" {
		return domain.DisplayCard{}, ErrUserNotFound
	}
	bankKey, err := s.Repo.GetActiveBankSigningKey(ctx)
	if err != nil {
		return domain.DisplayCard{}, fmt.Errorf("identity: load bank key: %w", err)
	}

	displayName := strings.TrimSpace(me.FirstName + " " + me.LastName)
	if displayName == "" {
		displayName = me.AccountNumber
	}
	// Truncate to microsecond precision so the signature survives Dart's
	// DateTime round-trip (DateTime carries microseconds, not nanoseconds).
	// Without this, the client's re-serialization drops 3 digits and the
	// server's VerifyDisplayCard fails at Phase 4a.
	payload := domain.DisplayCardPayload{
		UserID:        me.UserID,
		DisplayName:   displayName,
		AccountNumber: me.AccountNumber,
		IssuedAt:      s.now().Truncate(time.Microsecond),
		BankKeyID:     bankKey.KeyID,
	}
	sig, err := s.sign(ctx, bankKey, payload)
	if err != nil {
		return domain.DisplayCard{}, fmt.Errorf("identity: sign: %w", err)
	}
	return domain.DisplayCard{
		UserID:          payload.UserID,
		DisplayName:     payload.DisplayName,
		AccountNumber:   payload.AccountNumber,
		IssuedAt:        payload.IssuedAt,
		BankKeyID:       payload.BankKeyID,
		ServerSignature: sig,
	}, nil
}

func (s *Service) now() time.Time {
	if s.Clock == nil {
		return time.Now().UTC()
	}
	return s.Clock.Now().UTC()
}

func (s *Service) sign(ctx context.Context, bankKey domain.BankSigningKey, payload domain.DisplayCardPayload) ([]byte, error) {
	if s.Signer != nil {
		return crypto.SignDisplayCardWithSigner(ctx, s.Signer, bankKey.KeyID, payload)
	}
	if len(bankKey.PrivateKey) != ed25519.PrivateKeySize {
		return nil, fmt.Errorf("identity: bank key %q has no usable private half and no Signer is configured", bankKey.KeyID)
	}
	return crypto.SignDisplayCard(ed25519.PrivateKey(bankKey.PrivateKey), payload)
}
