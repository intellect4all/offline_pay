package domain

import "time"

type Transaction struct {
	// ID is the unique transaction identifier (server-assigned).
	ID string
	// PayerID is the paying user's identifier.
	PayerID string
	// PayeeID is the merchant's identifier.
	PayeeID string
	// Amount is the transaction amount in kobo.
	Amount int64
	// SequenceNumber is the monotonic sequence per ceiling token.
	SequenceNumber int64
	// CeilingTokenID is the ceiling authorizing this payment.
	CeilingTokenID string
	// PaymentToken is the serialized PaymentToken (JSON bytes).
	PaymentToken []byte
	// CeilingToken is the serialized CeilingToken for verification (JSON bytes).
	CeilingToken []byte
	// Status is the current state-machine position.
	Status TransactionStatus
	// SettledAmount is the amount actually settled in kobo. Differs from
	// Amount when partially settled due to ceiling exhaustion.
	SettledAmount int64
	// SettlementBatchID links to the SettlementBatch that processed this txn.
	SettlementBatchID *string
	// RejectionReason is populated when Status is TxRejected.
	RejectionReason *string
	// SubmittedAt is when the merchant submitted the claim.
	SubmittedAt *time.Time
	// SettledAt is when final settlement completed.
	SettledAt *time.Time
	// CreatedAt is the record creation timestamp.
	CreatedAt time.Time
	// UpdatedAt is the last-modified timestamp.
	UpdatedAt time.Time
}

// TransactionStatus is a position in the transaction state machine.
type TransactionStatus string

const (
	// TxQueued means the txn sits on-device awaiting merchant connectivity.
	TxQueued TransactionStatus = "QUEUED"
	// TxSubmitted means the merchant has submitted the claim to the server.
	TxSubmitted TransactionStatus = "SUBMITTED"
	// TxPending means the claim was verified and merchant credited pending.
	TxPending TransactionStatus = "PENDING"
	// TxSettled means funds have moved and merchant has been credited available.
	TxSettled TransactionStatus = "SETTLED"
	// TxPartiallySettled means ceiling exhausted; only a portion was credited.
	TxPartiallySettled TransactionStatus = "PARTIALLY_SETTLED"
	// TxRejected means the claim was rejected (bad signature, fraud, expired).
	TxRejected TransactionStatus = "REJECTED"
	// TxExpired means the txn was never submitted within the ceiling TTL.
	TxExpired TransactionStatus = "EXPIRED"
)

// ValidTransitions declares the legal state-machine edges. Terminal states
// (TxSettled, TxPartiallySettled, TxRejected, TxExpired) have no outgoing edges.
var ValidTransitions = map[TransactionStatus][]TransactionStatus{
	TxQueued:    {TxSubmitted, TxExpired},
	TxSubmitted: {TxPending, TxRejected},
	TxPending:   {TxSettled, TxPartiallySettled, TxRejected},
}

// CanTransitionTo reports whether moving from s to target is legal.
func (s TransactionStatus) CanTransitionTo(target TransactionStatus) bool {
	valid, ok := ValidTransitions[s]
	if !ok {
		return false
	}
	for _, v := range valid {
		if v == target {
			return true
		}
	}
	return false
}

// IsTerminal reports whether s has no outgoing transitions.
func (s TransactionStatus) IsTerminal() bool {
	_, ok := ValidTransitions[s]
	return !ok
}
