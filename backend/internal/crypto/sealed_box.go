package crypto

import (
	"crypto/rand"
	"errors"
	"fmt"
	"io"

	"golang.org/x/crypto/blake2b"
	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/nacl/box"
)

// curve25519ScalarBaseMult thinly wraps curve25519.ScalarBaseMult so tests
// and callers can stay agnostic of the underlying library.
func curve25519ScalarBaseMult(dst, src *[32]byte) {
	curve25519.ScalarBaseMult(dst, src)
}

// SealedBoxPubKeySize is the length of an X25519 public key in bytes.
const SealedBoxPubKeySize = 32

// SealedBoxPrivKeySize is the length of an X25519 private key in bytes.
const SealedBoxPrivKeySize = 32

// SealedBoxOverhead is the number of bytes added to plaintext in a sealed
// envelope: 32 bytes of ephemeral public key + 16 bytes of Poly1305 tag.
const SealedBoxOverhead = 32 + box.Overhead

// ErrBadSealedBox is returned when a sealed-box ciphertext is malformed or
// cannot be decrypted by the supplied recipient key.
var ErrBadSealedBox = errors.New("sealed-box: decrypt failed")

// DerivePublicFromSealedBoxPrivate derives an X25519 public key from a
// supplied private key. Useful when the server's private key is loaded from
// a secrets store and only the public half needs to be exposed.
func DerivePublicFromSealedBoxPrivate(priv *[32]byte) (*[32]byte, error) {
	if priv == nil {
		return nil, errors.New("sealed-box: nil private key")
	}
	var pub [32]byte
	curve25519ScalarBaseMult(&pub, priv)
	return &pub, nil
}

// GenerateSealedBoxKeyPair returns a fresh X25519 (Curve25519) key pair for
// sealed-box use. The private key is server-side; the public key is published
// to clients via GetServerSealedBoxPubkey.
func GenerateSealedBoxKeyPair() (pub, priv *[32]byte, err error) {
	pub, priv, err = box.GenerateKey(rand.Reader)
	if err != nil {
		return nil, nil, fmt.Errorf("sealed-box: generate: %w", err)
	}
	return pub, priv, nil
}

// SealAnonymous is libsodium-compatible crypto_box_seal. It generates an
// ephemeral X25519 key pair per call, derives a nonce from blake2b(eph_pk ||
// recipient_pk), encrypts via NaCl box (Curve25519 + XSalsa20 + Poly1305),
// and prepends the ephemeral public key to the output.
//
// Only the holder of recipientPriv can decrypt. Forward-secure with respect to
// the sender because the ephemeral private key is discarded immediately.
func SealAnonymous(recipientPub *[32]byte, plaintext []byte) ([]byte, error) {
	ephPub, ephPriv, err := box.GenerateKey(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("sealed-box: eph keygen: %w", err)
	}
	nonce, err := sealedBoxNonce(ephPub, recipientPub)
	if err != nil {
		return nil, err
	}
	out := make([]byte, 0, 32+len(plaintext)+box.Overhead)
	out = append(out, ephPub[:]...)
	out = box.Seal(out, plaintext, nonce, recipientPub, ephPriv)
	return out, nil
}

// OpenAnonymous is the inverse of SealAnonymous. It extracts the ephemeral
// public key from the first 32 bytes, rederives the nonce, and decrypts the
// remainder under recipientPub/recipientPriv.
func OpenAnonymous(recipientPub, recipientPriv *[32]byte, ciphertext []byte) ([]byte, error) {
	if len(ciphertext) < SealedBoxOverhead {
		return nil, ErrBadSealedBox
	}
	var ephPub [32]byte
	copy(ephPub[:], ciphertext[:32])
	nonce, err := sealedBoxNonce(&ephPub, recipientPub)
	if err != nil {
		return nil, err
	}
	pt, ok := box.Open(nil, ciphertext[32:], nonce, &ephPub, recipientPriv)
	if !ok {
		return nil, ErrBadSealedBox
	}
	return pt, nil
}

func sealedBoxNonce(ephPub, recipientPub *[32]byte) (*[24]byte, error) {
	h, err := blake2b.New(24, nil)
	if err != nil {
		return nil, fmt.Errorf("sealed-box: blake2b: %w", err)
	}
	if _, err := io.Copy(h, &bytesReader{b: ephPub[:]}); err != nil {
		return nil, err
	}
	if _, err := io.Copy(h, &bytesReader{b: recipientPub[:]}); err != nil {
		return nil, err
	}
	sum := h.Sum(nil)
	var out [24]byte
	copy(out[:], sum)
	return &out, nil
}

// bytesReader is a minimal io.Reader over a []byte without pulling bytes.Reader.
type bytesReader struct {
	b []byte
	i int
}

func (r *bytesReader) Read(p []byte) (int, error) {
	if r.i >= len(r.b) {
		return 0, io.EOF
	}
	n := copy(p, r.b[r.i:])
	r.i += n
	return n, nil
}
