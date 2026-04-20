package userauth

import (
	"context"
	"crypto/ed25519"
	"errors"
	"time"

	"github.com/intellect/offlinepay/internal/auth"
)

// Errors specific to device-session-token issuance. Mapped by the BFF
// handler to stable HTTP codes (400 / 403).
var (
	ErrDeviceNotOwned    = errors.New("userauth: device not owned by caller")
	ErrDeviceInactive    = errors.New("userauth: device deactivated")
	ErrDeviceUnknown     = errors.New("userauth: device unknown")
	ErrUnsupportedScope  = errors.New("userauth: unsupported scope")
	ErrDeviceSessionUnav = errors.New("userauth: device session signer not configured")
)

// DeviceLookup returns the owning user id and active flag for a device id.
// Implemented in BFF main.go by closing over pgrepo.LookupDeviceForAuth so
// the service layer doesn't import the persistence package directly.
type DeviceLookup func(ctx context.Context, deviceID string) (userID string, active bool, err error)

// DeviceSessionSigner bundles the Ed25519 keypair the BFF uses to sign
// device session tokens together with the key id (`kid`) and the audience
// claim. Audience is shared with the access-JWT signer so a future
// multi-tenant deployment can reuse one identity per BFF instance.
type DeviceSessionSigner struct {
	KeyID      string
	PrivateKey ed25519.PrivateKey
	PublicKey  ed25519.PublicKey
	Audience   string
	TTL        time.Duration
	// activated is set lazily by activeFrom() to record the moment this
	// signer first surfaced through the public-keys endpoint. Pure
	// metadata; not part of the signing material.
	activated time.Time
}

// HasDeviceSessionSigner reports whether the service was wired with a non-nil device
// session signer. Tests and dev runs without offline-auth keys can leave
// it unset; the issuer just returns ErrDeviceSessionUnav.
func (s *Service) HasDeviceSessionSigner() bool {
	return s.DeviceSession != nil && len(s.DeviceSession.PrivateKey) == ed25519.PrivateKeySize
}

// DeviceSessionToken is the projection returned to the BFF handler. The
// device caches token + ServerPublicKey + ExpiresAt.
type DeviceSessionToken struct {
	Token           string
	ServerPublicKey []byte
	KeyID           string
	IssuedAt        time.Time
	ExpiresAt       time.Time
	Scope           string
}

// IssueDeviceSession verifies the device belongs to userID, is still
// active, and mints an Ed25519-signed session token for the requested
// scope. sessionID, when non-empty, is recorded in the `sid` claim so a
// later /auth/sessions revoke can be cross-referenced.
func (s *Service) IssueDeviceSession(ctx context.Context, userID, deviceID, sessionID, scope string) (DeviceSessionToken, error) {
	var zero DeviceSessionToken
	if !s.HasDeviceSessionSigner() {
		return zero, ErrDeviceSessionUnav
	}
	if scope == "" {
		scope = auth.ScopeOfflinePay
	}
	if scope != auth.ScopeOfflinePay {
		return zero, ErrUnsupportedScope
	}
	if s.DeviceLookup == nil {
		return zero, ErrDeviceSessionUnav
	}
	owner, active, err := s.DeviceLookup(ctx, deviceID)
	if err != nil {
		return zero, ErrDeviceUnknown
	}
	if owner != userID {
		return zero, ErrDeviceNotOwned
	}
	if !active {
		return zero, ErrDeviceInactive
	}
	accountNumber, err := s.Repo.GetUserAccountNumber(ctx, userID)
	if err != nil {
		return zero, err
	}

	now := time.Now().UTC()
	exp := now.Add(s.DeviceSession.TTL)
	claims := auth.DeviceSessionClaims{
		Sub:           userID,
		AccountNumber: accountNumber,
		DeviceID:      deviceID,
		Scope:         scope,
		Iat:           now.Unix(),
		Exp:           exp.Unix(),
		Aud:           s.DeviceSession.Audience,
		SessionID:     sessionID,
	}
	tok, err := auth.SignDeviceSession(s.DeviceSession.PrivateKey, s.DeviceSession.KeyID, claims)
	if err != nil {
		return zero, err
	}
	return DeviceSessionToken{
		Token:           tok,
		ServerPublicKey: append([]byte(nil), s.DeviceSession.PublicKey...),
		KeyID:           s.DeviceSession.KeyID,
		IssuedAt:        now,
		ExpiresAt:       exp,
		Scope:           scope,
	}, nil
}

// DeviceSessionPublicKey is what the device pulls down at registration so
// it can verify a freshly minted token offline.
type DeviceSessionPublicKey struct {
	KeyID      string
	PublicKey  []byte
	ActiveFrom time.Time
	RetiredAt  *time.Time
}

// ListDeviceSessionPublicKeys returns the current active key bundle. We
// only ship one key today; rotation lands by appending entries here and
// having the device pick the matching one by `kid`.
func (s *Service) ListDeviceSessionPublicKeys(_ context.Context) []DeviceSessionPublicKey {
	if !s.HasDeviceSessionSigner() {
		return nil
	}
	return []DeviceSessionPublicKey{{
		KeyID:      s.DeviceSession.KeyID,
		PublicKey:  append([]byte(nil), s.DeviceSession.PublicKey...),
		ActiveFrom: s.DeviceSession.activeFrom(),
	}}
}

// activeFrom is a placeholder until the key bundle moves to persistence.
// The current process-startup time is good enough — it conveys "this key
// has been live since this binary booted" and lets the device sort by
// freshness.
func (k *DeviceSessionSigner) activeFrom() time.Time {
	if k == nil {
		return time.Time{}
	}
	if k.activated.IsZero() {
		k.activated = time.Now().UTC()
	}
	return k.activated
}
