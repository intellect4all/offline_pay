package kms

import (
	"context"
	"crypto/ed25519"
	"fmt"

	"github.com/intellect/offlinepay/internal/domain"
)

// KeyLoader resolves a bank signing key by its id. *pgrepo.Repo satisfies
// this interface via its existing GetBankSigningKey method.
type KeyLoader interface {
	GetBankSigningKey(ctx context.Context, keyID string) (domain.BankSigningKey, error)
}

// LocalSigner is a Signer that pulls the bank private key out of Postgres
// and signs in-process with crypto/ed25519. It is the historical behavior
// — safe for local dev, not suitable when regulatory requirements mandate
// private keys never leave a secure enclave.
type LocalSigner struct {
	Loader KeyLoader
}

// NewLocalSigner constructs a LocalSigner backed by loader.
func NewLocalSigner(loader KeyLoader) *LocalSigner {
	return &LocalSigner{Loader: loader}
}

// Sign loads the private key for keyID and produces an Ed25519 signature
// over msg. The private key is held on the stack only for the duration of
// this call.
func (s *LocalSigner) Sign(ctx context.Context, keyID string, msg []byte) ([]byte, error) {
	k, err := s.Loader.GetBankSigningKey(ctx, keyID)
	if err != nil {
		return nil, fmt.Errorf("local signer: load key %q: %w", keyID, err)
	}
	if len(k.PrivateKey) != ed25519.PrivateKeySize {
		return nil, fmt.Errorf("local signer: key %q has no usable private half", keyID)
	}
	return ed25519.Sign(k.PrivateKey, msg), nil
}

// PublicKey returns the public half of keyID from the loader.
func (s *LocalSigner) PublicKey(ctx context.Context, keyID string) (ed25519.PublicKey, error) {
	k, err := s.Loader.GetBankSigningKey(ctx, keyID)
	if err != nil {
		return nil, fmt.Errorf("local signer: load key %q: %w", keyID, err)
	}
	if len(k.PublicKey) != ed25519.PublicKeySize {
		return nil, fmt.Errorf("local signer: key %q has malformed public half", keyID)
	}
	return k.PublicKey, nil
}
