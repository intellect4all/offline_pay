package domain

import (
	"errors"
	"fmt"
	"time"
)

// CeilingToken is the bank-signed authorization for offline spending,
// issued when a user funds their offline wallet.
type CeilingToken struct {
	ID             string
	PayerID        string
	CeilingAmount  int64 // kobo
	IssuedAt       time.Time
	ExpiresAt      time.Time
	SequenceStart  int64
	NextSequence   int64 // client-side bookkeeping
	PayerPublicKey []byte
	BankKeyID      string
	BankSignature  []byte
	Status         CeilingStatus
	// ReleaseAfter is populated only for RECOVERY_PENDING rows. When set,
	// the expiry sweep holds off releasing the lien back to main until
	// this instant — long enough for any offline merchant still carrying
	// a signed payment against this ceiling to get online and settle.
	ReleaseAfter *time.Time
	CreatedAt    time.Time
}

type CeilingStatus string

const (
	CeilingActive           CeilingStatus = "ACTIVE"
	CeilingExpired          CeilingStatus = "EXPIRED"
	CeilingExhausted        CeilingStatus = "EXHAUSTED"
	CeilingRevoked          CeilingStatus = "REVOKED"
	// CeilingRecoveryPending marks a ceiling whose device-side token was
	// lost. The lien stays locked until release_after passes, allowing
	// any gossip-carried claims to land first. On sweep, the remaining
	// lien balance is returned to the main wallet.
	CeilingRecoveryPending  CeilingStatus = "RECOVERY_PENDING"
)

// CeilingTokenPayload is the canonical, signable subset of a CeilingToken.
// DB metadata is excluded — only what the bank signs.
type CeilingTokenPayload struct {
	PayerID        string    `json:"payer_id"`
	CeilingAmount  int64     `json:"ceiling_amount"`
	IssuedAt       time.Time `json:"issued_at"`
	ExpiresAt      time.Time `json:"expires_at"`
	SequenceStart  int64     `json:"sequence_start"`
	PayerPublicKey []byte    `json:"public_key"`
	BankKeyID      string    `json:"bank_key_id"`
}

var ErrInvalidCeilingPayload = errors.New("invalid ceiling token payload")

// Validate checks required fields. Does NOT verify the bank signature —
// that is a crypto-layer concern.
func (p CeilingTokenPayload) Validate() error {
	var reason string
	switch {
	case p.PayerID == "":
		reason = "payer_id required"
	case p.CeilingAmount <= 0:
		reason = "ceiling_amount must be positive"
	case p.IssuedAt.IsZero():
		reason = "issued_at required"
	case p.ExpiresAt.IsZero():
		reason = "expires_at required"
	case !p.ExpiresAt.After(p.IssuedAt):
		reason = "expires_at must be after issued_at"
	case p.SequenceStart < 0:
		reason = "sequence_start must be non-negative"
	case len(p.PayerPublicKey) == 0:
		reason = "public_key required"
	case p.BankKeyID == "":
		reason = "bank_key_id required"
	default:
		return nil
	}
	return fmt.Errorf("%w: %s", ErrInvalidCeilingPayload, reason)
}

// BankSigningKey is a bank-side Ed25519 key pair used to sign ceiling
// tokens. The private key never leaves the server. ActiveTo == nil means
// currently active.
type BankSigningKey struct {
	KeyID      string
	PublicKey  []byte
	PrivateKey []byte
	ActiveFrom time.Time
	ActiveTo   *time.Time
	CreatedAt  time.Time
}
