package domain

import (
	"errors"
	"fmt"
	"time"
)

// DisplayCard is a server-issued identity credential a user embeds in every
// PaymentRequest they publish. The receiving payer verifies the server's
// signature to confirm the display_name really belongs to receiver_user_id
// — this prevents merchants from spoofing friendly names.
//
// Issued at registration and on display-name changes. Signed by the active
// bank signing key so devices can verify it without fetching another key.
type DisplayCard struct {
	UserID          string    `json:"user_id"`
	DisplayName     string    `json:"display_name"`
	AccountNumber   string    `json:"account_number"`
	IssuedAt        time.Time `json:"issued_at"`
	BankKeyID       string    `json:"bank_key_id"`
	ServerSignature []byte    `json:"server_signature"` // Ed25519 over DisplayCardPayload
}

// DisplayCardPayload is the canonical, signable subset.
type DisplayCardPayload struct {
	UserID        string    `json:"user_id"`
	DisplayName   string    `json:"display_name"`
	AccountNumber string    `json:"account_number"`
	IssuedAt      time.Time `json:"issued_at"`
	BankKeyID     string    `json:"bank_key_id"`
}

// Payload extracts the signable subset.
func (d DisplayCard) Payload() DisplayCardPayload {
	return DisplayCardPayload{
		UserID:        d.UserID,
		DisplayName:   d.DisplayName,
		AccountNumber: d.AccountNumber,
		IssuedAt:      d.IssuedAt,
		BankKeyID:     d.BankKeyID,
	}
}

var ErrInvalidDisplayCard = errors.New("invalid display card")

func (p DisplayCardPayload) Validate() error {
	var reason string
	switch {
	case p.UserID == "":
		reason = "user_id required"
	case p.DisplayName == "":
		reason = "display_name required"
	case p.AccountNumber == "":
		reason = "account_number required"
	case p.IssuedAt.IsZero():
		reason = "issued_at required"
	case p.BankKeyID == "":
		reason = "bank_key_id required"
	default:
		return nil
	}
	return fmt.Errorf("%w: %s", ErrInvalidDisplayCard, reason)
}
