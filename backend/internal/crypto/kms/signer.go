// Package kms wraps bank-key signing behind an interface so the Ed25519
// private half can live outside the application process — in a homelab
// HashiCorp Vault Transit instance, a hardware HSM, or a cloud KMS.
//
// Callers (wallet service, opsctl) depend on the Signer interface. The
// concrete backend is chosen at bootstrap from config:
//
//   - LocalSigner reads the encrypted private key from the bank_signing_keys
//     table via a KeyLoader. Suitable for local dev and the existing test
//     harness; not recommended in production because the private key lives
//     in Postgres.
//   - VaultSigner talks to HashiCorp Vault's transit engine. Private keys
//     stay inside Vault; the application only ever sees signatures.
package kms

import (
	"context"
	"crypto/ed25519"
)

// Signer produces Ed25519 signatures over pre-canonicalized bytes without
// exposing the private key to the caller. Implementations are expected to
// be safe for concurrent use.
type Signer interface {
	// Sign produces an Ed25519 signature over msg using the key identified
	// by keyID. msg should already be canonicalized — the signer does not
	// hash or reshape it.
	Sign(ctx context.Context, keyID string, msg []byte) ([]byte, error)
	// PublicKey returns the Ed25519 public half of keyID. May cache.
	PublicKey(ctx context.Context, keyID string) (ed25519.PublicKey, error)
}
