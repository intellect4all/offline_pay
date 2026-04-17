package domain

import "time"

// ReconciliationRecord tracks a single reconciliation check across one of
// the three reconciliation loops (payer, merchant, ledger).
type ReconciliationRecord struct {
	// ID is the unique record identifier.
	ID string
	// Type identifies which reconciliation loop produced this record.
	Type ReconciliationType
	// EntityID is the subject identifier: payer_id, merchant_id, or "system".
	EntityID string
	// RunAt is when the reconciliation was executed.
	RunAt time.Time
	// Status is the outcome.
	Status ReconciliationStatus
	// Discrepancies lists every mismatch found; empty when clean.
	Discrepancies []Discrepancy
	// CreatedAt is the record creation timestamp.
	CreatedAt time.Time
}

// ReconciliationType identifies a reconciliation loop.
type ReconciliationType string

const (
	// ReconPayer compares on-device logs against server-settled transactions.
	ReconPayer ReconciliationType = "PAYER"
	// ReconMerchant reconciles merchant claim submissions and settlements.
	ReconMerchant ReconciliationType = "MERCHANT"
	// ReconLedger is the nightly double-entry balance check.
	ReconLedger ReconciliationType = "LEDGER"
)

// ReconciliationStatus is the outcome of a reconciliation run.
type ReconciliationStatus string

const (
	// ReconClean means no discrepancies were found.
	ReconClean ReconciliationStatus = "CLEAN"
	// ReconDiscrepancy means one or more mismatches were found.
	ReconDiscrepancy ReconciliationStatus = "DISCREPANCY"
	// ReconInProgress means the run is still executing.
	ReconInProgress ReconciliationStatus = "IN_PROGRESS"
)

// Discrepancy describes a single mismatch found during reconciliation.
type Discrepancy struct {
	// TransactionID is the affected transaction, if applicable.
	TransactionID string
	// Field is the specific mismatched field (e.g. "amount", "status").
	Field string
	// Expected is the value the reconciler expected.
	Expected string
	// Actual is the value observed.
	Actual string
	// Severity is one of "INFO", "WARNING", "CRITICAL".
	Severity string
}
