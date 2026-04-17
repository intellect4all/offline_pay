package domain

import (
	"errors"
	"fmt"
	"time"
)

// SessionNonceSize is the length in bytes of a PaymentRequest session_nonce.
// 16 random bytes is enough to make session collisions cryptographically
// improbable while keeping the encoded form under 32 base64 chars.
const SessionNonceSize = 16

// UnboundAmount is the sentinel value for a PaymentRequest that doesn't
// declare a fixed amount (P2P fallback — the payer enters the amount
// themselves). The server skips the amount-equality check when this is set.
const UnboundAmount = int64(0)

// PaymentRequest is the receiver-issued, receiver-signed invoice that the
// payer scans before signing a PaymentToken. It binds the receiver's
// identity + intended amount (or the unbound sentinel) + a single-use
// session_nonce into a contract the payer counter-signs.
type PaymentRequest struct {
	ReceiverID           string      `json:"receiver_id"`
	ReceiverDisplayCard  DisplayCard `json:"receiver_display_card"`
	Amount               int64       `json:"amount"`        // kobo; 0 = unbound (P2P fallback)
	SessionNonce         []byte      `json:"session_nonce"` // 16B random, single-use
	IssuedAt             time.Time   `json:"issued_at"`
	ExpiresAt            time.Time   `json:"expires_at"`
	ReceiverDevicePubkey []byte      `json:"receiver_device_pubkey"` // Ed25519
	ReceiverSignature    []byte      `json:"receiver_signature"`     // over PaymentRequestPayload
}

// PaymentRequestPayload is the canonical, signable subset.
type PaymentRequestPayload struct {
	ReceiverID           string      `json:"receiver_id"`
	ReceiverDisplayCard  DisplayCard `json:"receiver_display_card"`
	Amount               int64       `json:"amount"`
	SessionNonce         []byte      `json:"session_nonce"`
	IssuedAt             time.Time   `json:"issued_at"`
	ExpiresAt            time.Time   `json:"expires_at"`
	ReceiverDevicePubkey []byte      `json:"receiver_device_pubkey"`
}

// Payload extracts the signable subset.
func (r PaymentRequest) Payload() PaymentRequestPayload {
	return PaymentRequestPayload{
		ReceiverID:           r.ReceiverID,
		ReceiverDisplayCard:  r.ReceiverDisplayCard,
		Amount:               r.Amount,
		SessionNonce:         r.SessionNonce,
		IssuedAt:             r.IssuedAt,
		ExpiresAt:            r.ExpiresAt,
		ReceiverDevicePubkey: r.ReceiverDevicePubkey,
	}
}

var ErrInvalidPaymentRequest = errors.New("invalid payment request")

func (p PaymentRequestPayload) Validate() error {
	var reason string
	switch {
	case p.ReceiverID == "":
		reason = "receiver_id required"
	case p.ReceiverDisplayCard.UserID != p.ReceiverID:
		reason = "display_card.user_id must match receiver_id"
	case p.Amount < 0:
		reason = "amount must be >= 0"
	case len(p.SessionNonce) != SessionNonceSize:
		reason = fmt.Sprintf("session_nonce must be %d bytes", SessionNonceSize)
	case p.IssuedAt.IsZero():
		reason = "issued_at required"
	case p.ExpiresAt.IsZero() || !p.ExpiresAt.After(p.IssuedAt):
		reason = "expires_at must be after issued_at"
	case len(p.ReceiverDevicePubkey) == 0:
		reason = "receiver_device_pubkey required"
	default:
		return p.ReceiverDisplayCard.Payload().Validate()
	}
	return fmt.Errorf("%w: %s", ErrInvalidPaymentRequest, reason)
}

// IsUnbound reports whether this request lets the payer pick the amount.
func (p PaymentRequestPayload) IsUnbound() bool { return p.Amount == UnboundAmount }
