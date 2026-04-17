package domain

import "time"

// TransactionKind enumerates the business events that produce a row in
// the transactions table. Each value matches the Postgres
// `transaction_kind` enum exactly.
type TransactionKind string

const (
	TxKindOfflineFund            TransactionKind = "OFFLINE_FUND"
	TxKindOfflineDrain           TransactionKind = "OFFLINE_DRAIN"
	TxKindOfflineExpiryRelease   TransactionKind = "OFFLINE_EXPIRY_RELEASE"
	TxKindOfflineRecoveryRelease TransactionKind = "OFFLINE_RECOVERY_RELEASE"
	TxKindOfflinePaymentSent     TransactionKind = "OFFLINE_PAYMENT_SENT"
	TxKindOfflinePaymentReceived TransactionKind = "OFFLINE_PAYMENT_RECEIVED"
	TxKindTransferSent           TransactionKind = "TRANSFER_SENT"
	TxKindTransferReceived       TransactionKind = "TRANSFER_RECEIVED"
	TxKindDemoMint               TransactionKind = "DEMO_MINT"
)

// TransactionLifecycleStatus is the four-state machine for business
// events. Distinct from domain.TransactionStatus (which models the
// offline-payment-token lifecycle: QUEUED → SUBMITTED → PENDING → ...).
type TransactionLifecycleStatus string

const (
	TxStatusPending   TransactionLifecycleStatus = "PENDING"
	TxStatusCompleted TransactionLifecycleStatus = "COMPLETED"
	TxStatusFailed    TransactionLifecycleStatus = "FAILED"
	TxStatusReversed  TransactionLifecycleStatus = "REVERSED"
)

// UserTransaction is one row in the transactions table — a single
// user's view of a business event. Two-party events have two rows
// (paired via GroupID); single-party events have one (GroupID == ID).
//
// Direction is from this user's POV: DEBIT means money left the user,
// CREDIT means it arrived. CounterpartyUserID is the other party (nil
// for single-party events).
type UserTransaction struct {
	ID                 string
	GroupID            string
	UserID             string
	CounterpartyUserID *string
	Kind               TransactionKind
	Status             TransactionLifecycleStatus
	Direction          string // "DEBIT" | "CREDIT"
	AmountKobo         int64
	SettledAmountKobo  *int64
	Memo               string
	PaymentTokenID     *string
	TransferID         *string
	CeilingID          *string
	FailureReason      *string
	CreatedAt          time.Time
	UpdatedAt          time.Time
}
