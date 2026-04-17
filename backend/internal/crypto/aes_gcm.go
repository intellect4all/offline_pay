package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/binary"
	"errors"
	"fmt"
)

// RealmKeySize is the AES-256-GCM key length in bytes.
const RealmKeySize = 32

// NonceSize is the AES-GCM nonce length in bytes.
const NonceSize = 12

// ErrBadKey is returned when a realm key is not exactly RealmKeySize bytes.
var ErrBadKey = errors.New("aes-gcm: key must be 32 bytes")

// ErrBadNonce is returned for malformed nonces.
var ErrBadNonce = errors.New("aes-gcm: nonce must be 12 bytes")

// Seal encrypts plaintext under key with the supplied nonce. The caller is
// responsible for nonce uniqueness per (key, plaintext) pair. For animated-QR
// frames derive per-frame nonces with DeriveFrameNonce.
func Seal(key, nonce, plaintext, associatedData []byte) ([]byte, error) {
	if len(key) != RealmKeySize {
		return nil, ErrBadKey
	}
	if len(nonce) != NonceSize {
		return nil, ErrBadNonce
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("aes-gcm: new cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("aes-gcm: new gcm: %w", err)
	}
	return gcm.Seal(nil, nonce, plaintext, associatedData), nil
}

// Open decrypts ciphertext under key with the supplied nonce, verifying the
// GCM auth tag and the associated data.
func Open(key, nonce, ciphertext, associatedData []byte) ([]byte, error) {
	if len(key) != RealmKeySize {
		return nil, ErrBadKey
	}
	if len(nonce) != NonceSize {
		return nil, ErrBadNonce
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("aes-gcm: new cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("aes-gcm: new gcm: %w", err)
	}
	pt, err := gcm.Open(nil, nonce, ciphertext, associatedData)
	if err != nil {
		return nil, fmt.Errorf("aes-gcm: open: %w", err)
	}
	return pt, nil
}

// NewRandomRealmKey returns a 32-byte AES-256 key from crypto/rand.
func NewRandomRealmKey() ([]byte, error) {
	k := make([]byte, RealmKeySize)
	if _, err := rand.Read(k); err != nil {
		return nil, fmt.Errorf("aes-gcm: read rand: %w", err)
	}
	return k, nil
}

// NewRandomBaseNonce returns a 12-byte nonce prefix suitable as a base for
// frame-level nonce derivation. The last 4 bytes are left as zeros for the
// frame index to populate.
func NewRandomBaseNonce() ([]byte, error) {
	n := make([]byte, NonceSize)
	if _, err := rand.Read(n[:NonceSize-4]); err != nil {
		return nil, fmt.Errorf("aes-gcm: read rand: %w", err)
	}
	return n, nil
}

// DeriveFrameNonce copies base and overwrites the last 4 bytes with frameIndex
// (big-endian). Guarantees a unique nonce per frame within a single QR stream
// provided base is drawn from NewRandomBaseNonce.
func DeriveFrameNonce(base []byte, frameIndex uint32) ([]byte, error) {
	if len(base) != NonceSize {
		return nil, ErrBadNonce
	}
	out := make([]byte, NonceSize)
	copy(out, base)
	binary.BigEndian.PutUint32(out[NonceSize-4:], frameIndex)
	return out, nil
}
