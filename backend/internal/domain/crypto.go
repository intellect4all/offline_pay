package domain

import "time"

// KeyPair holds an Ed25519 key pair. Used for both bank signing keys and
// payer signing keys (though payer private keys never reach the server).
type KeyPair struct {
	// PublicKey is the 32-byte Ed25519 public key.
	PublicKey []byte
	// PrivateKey is the 64-byte Ed25519 private key (seed + public).
	PrivateKey []byte
}

// RealmKey is the symmetric AES-256-GCM key shared by all registered app
// instances. Used to encrypt QR payloads so random scanners see noise.
type RealmKey struct {
	// Version is referenced by the 1-byte key_version prefix in QR frames.
	Version int
	// Key is the 32-byte AES-256 key.
	Key []byte
	// ActiveFrom is when this key version became usable.
	ActiveFrom time.Time
	// ExpiresAt is when this key version should be rotated out.
	ExpiresAt time.Time
}

