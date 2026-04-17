package domain

import "time"

// SettlementBatch groups transactions a merchant submits together for
// server-side processing.
type SettlementBatch struct {
	// ID is the unique batch identifier.
	ID string
	// ReceiverID is the submitting receiver user's identifier. (The
	// system is C2C — there are no distinct merchant entities.)
	ReceiverID string
	// TotalSubmitted is the number of transactions submitted in this batch.
	TotalSubmitted int
	// TotalSettled is the number fully settled.
	TotalSettled int
	// TotalPartial is the number partially settled (ceiling exhaustion).
	TotalPartial int
	// TotalRejected is the number rejected (invalid, fraud, expired).
	TotalRejected int
	// TotalAmount is the sum of settled and partial amounts in kobo.
	TotalAmount int64
	// Status is the batch's processing status.
	Status SettlementBatchStatus
	// SubmittedAt is when the merchant submitted the batch.
	SubmittedAt time.Time
	// ProcessedAt is when the server finished processing.
	ProcessedAt *time.Time
	// CreatedAt is the record creation timestamp.
	CreatedAt time.Time
}

// SettlementBatchStatus is the lifecycle status of a SettlementBatch.
type SettlementBatchStatus string

const (
	// BatchReceived means the batch has been queued for processing.
	BatchReceived SettlementBatchStatus = "RECEIVED"
	// BatchProcessing means settlement is actively running.
	BatchProcessing SettlementBatchStatus = "PROCESSING"
	// BatchCompleted means all transactions have reached a terminal state.
	BatchCompleted SettlementBatchStatus = "COMPLETED"
	// BatchFailed means the batch could not be processed.
	BatchFailed SettlementBatchStatus = "FAILED"
)

// SettlementResult is the per-transaction outcome within a batch.
type SettlementResult struct {
	// TransactionID identifies the transaction.
	TransactionID string
	// SequenceNumber is the payment token sequence.
	SequenceNumber int64
	// SubmittedAmount is what the merchant claimed, in kobo.
	SubmittedAmount int64
	// SettledAmount is what the server actually credited, in kobo.
	SettledAmount int64
	// Status is the final transaction status after processing.
	Status TransactionStatus
	// Reason explains rejection or partial settlement; empty when fully settled.
	Reason string
	// ReceiverUserID names the receiver that was credited for this txn.
	// Populated by Phase 4b (FinalizeForPayer); empty from Phase 4a
	// sub-results because the receiver is known from the RPC envelope.
	// Used by the settlement-finalize processor to fan out "offline_payment
	// _received" pushes after the ledger moves commit.
	ReceiverUserID string
}

// MerchantBalance tracks a merchant's two-tier balance model.
// Pending balance becomes available after final settlement (Phase 4b).
type MerchantBalance struct {
	// MerchantID is the owning merchant's identifier.
	MerchantID string
	// AvailableBalance is the withdrawable balance in kobo.
	AvailableBalance int64
	// PendingBalance is verified-but-not-settled claims in kobo.
	PendingBalance int64
	// UpdatedAt is the last-modified timestamp.
	UpdatedAt time.Time
}
