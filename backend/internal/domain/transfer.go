package domain

import (
	"errors"
	"regexp"
	"time"
)

// TransferStatus mirrors the CHECK constraint on transfers.status.
type TransferStatus string

const (
	StatusAccepted   TransferStatus = "ACCEPTED"
	StatusProcessing TransferStatus = "PROCESSING"
	StatusSettled    TransferStatus = "SETTLED"
	StatusFailed     TransferStatus = "FAILED"
)

// Transfer is the canonical domain view of a user-to-user transfer row.
type Transfer struct {
	ID                    string         `json:"id"`
	SenderUserID          string         `json:"sender_user_id"`
	ReceiverUserID        string         `json:"receiver_user_id"`
	SenderDisplayName     *string        `json:"sender_display_name,omitempty"`
	ReceiverDisplayName   *string        `json:"receiver_display_name,omitempty"`
	ReceiverAccountNumber string         `json:"receiver_account_number"`
	AmountKobo            int64          `json:"amount_kobo"`
	Status                TransferStatus `json:"status"`
	Reference             string         `json:"reference"`
	FailureReason         *string        `json:"failure_reason,omitempty"`
	CreatedAt             time.Time      `json:"created_at"`
	SettledAt             *time.Time     `json:"settled_at,omitempty"`
}

// Validation errors surfaced by the transfer service.
var (
	ErrInvalidAmount        = errors.New("domain: amount must be positive")
	ErrInvalidReference     = errors.New("domain: reference must be 1..64 chars")
	ErrInvalidAccountNumber = errors.New("domain: account number must be exactly 10 digits")
)

const maxReferenceLen = 64

var accountNumberRe = regexp.MustCompile(`^[0-9]{10}$`)

// ValidateAmount rejects zero and negative kobo amounts.
func ValidateAmount(amount int64) error {
	if amount <= 0 {
		return ErrInvalidAmount
	}
	return nil
}

// ValidateReference enforces the client idempotency key length.
func ValidateReference(ref string) error {
	if ref == "" || len(ref) > maxReferenceLen {
		return ErrInvalidReference
	}
	return nil
}

// ValidateAccountNumber requires exactly 10 decimal digits.
func ValidateAccountNumber(n string) error {
	if !accountNumberRe.MatchString(n) {
		return ErrInvalidAccountNumber
	}
	return nil
}
