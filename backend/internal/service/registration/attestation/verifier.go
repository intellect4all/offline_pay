// Package attestation verifies hardware-attestation blobs produced by
// registering devices. Real mobile traffic arrives via two backends:
//
//   - Android: Play Integrity API returns a signed JWS from Google. The
//     verifier validates the JWS signature against Google's keys and
//     confirms the integrity verdict contains MEETS_DEVICE_INTEGRITY.
//   - iOS:     DeviceCheck / App Attest returns a CBOR/PKIX assertion
//     signed by Apple. The verifier validates the assertion chain and
//     confirms bundle id / environment.
//
// For homelab / e2e / unit-test deployments those real providers are
// replaced with DevVerifier: the client signs a tiny JSON envelope the
// server can round-trip without external services. Production
// deployments refuse to boot unless both provider verifiers are wired.
package attestation

import (
	"context"
	"errors"
	"fmt"
	"time"
)

// Platform enumerates the attestation providers we support.
type Platform string

const (
	PlatformAndroid Platform = "android"
	PlatformIOS     Platform = "ios"
	PlatformDev     Platform = "dev"
)

// Attestation is the structured outcome of a successful Verify call.
type Attestation struct {
	Platform        Platform
	DevicePublicKey []byte
	Nonce           []byte
	VerifiedAt      time.Time
	Raw             []byte
}

// ErrAttestationFailed is returned when an attestation blob is
// malformed, fails signature verification, or does not meet the required
// integrity verdict.
var ErrAttestationFailed = errors.New("attestation: verification failed")

// ErrNonceMismatch is returned when the attestation blob echoes a nonce
// that was never issued (or was already consumed — attestations are
// one-shot).
var ErrNonceMismatch = errors.New("attestation: nonce mismatch")

// Verifier turns an opaque attestation blob into a VerifiedAttestation.
// Implementations must be safe for concurrent use.
type Verifier interface {
	Verify(ctx context.Context, platform Platform, blob []byte, expectedDevicePubKey []byte, expectedNonce []byte) (Attestation, error)
}

// NonceStore issues and consumes single-use attestation challenges. A
// production deployment backs this with Redis so the challenge survives
// process restarts; a homelab POC is happy with the in-memory default.
type NonceStore interface {
	// Issue returns a fresh random nonce bound to (userID, deviceKeyHint)
	// and stores it with the provided TTL.
	Issue(ctx context.Context, userID string, ttl time.Duration) ([]byte, error)
	// Consume looks up and removes the (userID, nonce) pair. Returns
	// ErrNonceMismatch if the pair was never issued or already consumed.
	Consume(ctx context.Context, userID string, nonce []byte) error
}

// Composite dispatches to the right per-platform verifier based on the
// Platform value passed to Verify. It holds a map; unknown platforms
// return ErrAttestationFailed. Callers can leave per-platform slots nil
// to explicitly disable a platform (e.g. homelab skipping Play Integrity).
type Composite struct {
	ByPlatform map[Platform]Verifier
}

// Verify dispatches to the per-platform verifier.
func (c *Composite) Verify(ctx context.Context, platform Platform, blob []byte, expectedPub []byte, expectedNonce []byte) (Attestation, error) {
	v, ok := c.ByPlatform[platform]
	if !ok || v == nil {
		return Attestation{}, fmt.Errorf("%w: platform %q not configured", ErrAttestationFailed, platform)
	}
	return v.Verify(ctx, platform, blob, expectedPub, expectedNonce)
}
