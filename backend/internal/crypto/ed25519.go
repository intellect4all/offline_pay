package crypto

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"errors"
	"fmt"

	"github.com/intellect/offlinepay/internal/domain"
)

// CeilingSigner is the subset of internal/crypto/kms.Signer used by the
// canonical ceiling-signing helper. Duplicated here to keep crypto
// independent of the kms package (avoiding an import cycle).
type CeilingSigner interface {
	Sign(ctx context.Context, keyID string, msg []byte) ([]byte, error)
}

// SignCeilingWithSigner canonicalizes the ceiling payload and delegates
// signing to signer. Used when bank private keys live outside the process
// (e.g. Vault Transit). For in-process signing use SignCeiling.
func SignCeilingWithSigner(ctx context.Context, signer CeilingSigner, keyID string, p domain.CeilingTokenPayload) ([]byte, error) {
	if err := p.Validate(); err != nil {
		return nil, err
	}
	msg, err := Canonicalize(p)
	if err != nil {
		return nil, err
	}
	return signer.Sign(ctx, keyID, msg)
}

// ErrBadSignature is returned when an Ed25519 signature does not verify.
var ErrBadSignature = errors.New("ed25519: bad signature")

// GenerateKeyPair creates a fresh Ed25519 key pair suitable for either a bank
// signing key or a client payer key. Private keys for clients never leave the
// device; this helper exists for server-side key provisioning and tests.
func GenerateKeyPair() (domain.KeyPair, error) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return domain.KeyPair{}, fmt.Errorf("ed25519: generate: %w", err)
	}
	return domain.KeyPair{PublicKey: pub, PrivateKey: priv}, nil
}

// SignCeiling canonicalises the payload and produces an Ed25519 signature.
func SignCeiling(priv ed25519.PrivateKey, p domain.CeilingTokenPayload) ([]byte, error) {
	if err := p.Validate(); err != nil {
		return nil, err
	}
	msg, err := Canonicalize(p)
	if err != nil {
		return nil, err
	}
	return ed25519.Sign(priv, msg), nil
}

// VerifyCeiling verifies a ceiling token signature against pub.
func VerifyCeiling(pub ed25519.PublicKey, p domain.CeilingTokenPayload, sig []byte) error {
	msg, err := Canonicalize(p)
	if err != nil {
		return err
	}
	if !ed25519.Verify(pub, msg, sig) {
		return ErrBadSignature
	}
	return nil
}

// SignPayment canonicalises the payload and produces an Ed25519 signature.
func SignPayment(priv ed25519.PrivateKey, p domain.PaymentPayload) ([]byte, error) {
	if err := p.Validate(); err != nil {
		return nil, err
	}
	msg, err := Canonicalize(p)
	if err != nil {
		return nil, err
	}
	return ed25519.Sign(priv, msg), nil
}

// VerifyPayment verifies a payment token signature against the payer's
// public key.
func VerifyPayment(pub ed25519.PublicKey, p domain.PaymentPayload, sig []byte) error {
	msg, err := Canonicalize(p)
	if err != nil {
		return err
	}
	if !ed25519.Verify(pub, msg, sig) {
		return ErrBadSignature
	}
	return nil
}

// SignDisplayCard canonicalises the payload and signs it with the active
// bank signing key. Callers needing KMS-delegated signing should use the
// signer-based flavour below.
func SignDisplayCard(priv ed25519.PrivateKey, p domain.DisplayCardPayload) ([]byte, error) {
	if err := p.Validate(); err != nil {
		return nil, err
	}
	msg, err := Canonicalize(p)
	if err != nil {
		return nil, err
	}
	return ed25519.Sign(priv, msg), nil
}

// SignDisplayCardWithSigner is the KMS-delegated variant of SignDisplayCard.
// Shares the CeilingSigner interface — same bank key, same signer.
func SignDisplayCardWithSigner(ctx context.Context, signer CeilingSigner, keyID string, p domain.DisplayCardPayload) ([]byte, error) {
	if err := p.Validate(); err != nil {
		return nil, err
	}
	msg, err := Canonicalize(p)
	if err != nil {
		return nil, err
	}
	return signer.Sign(ctx, keyID, msg)
}

// VerifyDisplayCard verifies the bank-issued signature on a display card.
func VerifyDisplayCard(pub ed25519.PublicKey, p domain.DisplayCardPayload, sig []byte) error {
	msg, err := Canonicalize(p)
	if err != nil {
		return err
	}
	if !ed25519.Verify(pub, msg, sig) {
		return ErrBadSignature
	}
	return nil
}

// SignRequest canonicalises the PaymentRequest payload and produces an
// Ed25519 signature from the receiver's device key.
func SignRequest(priv ed25519.PrivateKey, p domain.PaymentRequestPayload) ([]byte, error) {
	if err := p.Validate(); err != nil {
		return nil, err
	}
	msg, err := Canonicalize(p)
	if err != nil {
		return nil, err
	}
	return ed25519.Sign(priv, msg), nil
}

// VerifyRequest verifies a PaymentRequest signature against the receiver's
// device public key.
func VerifyRequest(pub ed25519.PublicKey, p domain.PaymentRequestPayload, sig []byte) error {
	msg, err := Canonicalize(p)
	if err != nil {
		return err
	}
	if !ed25519.Verify(pub, msg, sig) {
		return ErrBadSignature
	}
	return nil
}

// HashRequest returns sha256(canonical(PaymentRequest)) as the wire form of
// request_hash embedded in the payment payload. Payer and server compute it
// the same way to anchor every PaymentToken to an exact PaymentRequest.
func HashRequest(r domain.PaymentRequest) ([]byte, error) {
	msg, err := Canonicalize(r)
	if err != nil {
		return nil, err
	}
	h := sha256.Sum256(msg)
	return h[:], nil
}
