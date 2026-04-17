package domain

import (
	"errors"
	"fmt"
	"time"
)

// PaymentToken is the payer-signed token for a single offline payment.
// Produced on-device, encoded into an animated QR, scanned by the merchant.
type PaymentToken struct {
	PayerID          string    `json:"payer_id"`
	PayeeID          string    `json:"payee_id"`
	Amount           int64     `json:"amount"`            // kobo
	SequenceNumber   int64     `json:"sequence_number"`   // monotonic per ceiling
	RemainingCeiling int64     `json:"remaining_ceiling"` // kobo, after this txn
	Timestamp        time.Time `json:"timestamp"`         // device clock, audit only
	CeilingTokenID   string    `json:"ceiling_token_id"`
	SessionNonce     []byte    `json:"session_nonce"` // copied from PaymentRequest
	RequestHash      []byte    `json:"request_hash"`  // sha256(canonical(PaymentRequest))
	PayerSignature   []byte    `json:"payer_signature"` // Ed25519 over PaymentPayload
}

// PaymentPayload is the canonical, signable subset of a PaymentToken.
//
// session_nonce + request_hash bind this token to a specific PaymentRequest
// issued by the receiver. The server re-computes the hash from the request
// blob in the envelope and rejects any mismatch.
type PaymentPayload struct {
	PayerID          string    `json:"payer_id"`
	PayeeID          string    `json:"payee_id"`
	Amount           int64     `json:"amount"`
	SequenceNumber   int64     `json:"sequence_number"`
	RemainingCeiling int64     `json:"remaining_ceiling"`
	Timestamp        time.Time `json:"timestamp"`
	CeilingTokenID   string    `json:"ceiling_token_id"`
	SessionNonce     []byte    `json:"session_nonce"`
	RequestHash      []byte    `json:"request_hash"`
}

var ErrInvalidPaymentPayload = errors.New("invalid payment payload")

// Validate checks that required fields are populated and sane. Does NOT
// verify the payer signature — that lives in the crypto layer.
func (p PaymentPayload) Validate() error {
	var reason string
	switch {
	case p.PayerID == "":
		reason = "payer_id required"
	case p.PayeeID == "":
		reason = "payee_id required"
	case p.PayerID == p.PayeeID:
		reason = "payer_id and payee_id must differ"
	case p.Amount <= 0:
		reason = "amount must be positive"
	case p.SequenceNumber <= 0:
		reason = "sequence_number must be positive"
	case p.RemainingCeiling < 0:
		reason = "remaining_ceiling must be non-negative"
	case p.Timestamp.IsZero():
		reason = "timestamp required"
	case p.CeilingTokenID == "":
		reason = "ceiling_token_id required"
	case len(p.SessionNonce) != SessionNonceSize:
		reason = fmt.Sprintf("session_nonce must be %d bytes", SessionNonceSize)
	case len(p.RequestHash) == 0:
		reason = "request_hash required"
	default:
		return nil
	}
	return fmt.Errorf("%w: %s", ErrInvalidPaymentPayload, reason)
}
