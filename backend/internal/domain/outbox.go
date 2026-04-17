package domain

import (
	"encoding/json"
	"time"
)

// Outbox aggregate identifiers. Keep these as package-level constants so
// producers and consumers reference the same string — a typo here lands as
// an undispatched row rather than a loud compile error.
const (
	OutboxAggregateTransfer          = "transfer"
	OutboxAggregateSettlementFinalize = "settlement-finalize"
)

// NATS subjects each aggregate dispatches to. Must line up with the
// JetStream stream's subject filter (currently `payments.>`).
const (
	OutboxSubjectTransfer          = "payments.transfer.v1"
	OutboxSubjectSettlementFinalize = "payments.settlement.v1"
)

// OutboxEnvelope is the wrapper payload published to NATS. The JSON form
// carries the enclosing row metadata; the inner payload is aggregate-typed
// (e.g. TransferPayload for aggregate="transfer").
type OutboxEnvelope struct {
	ID          string          `json:"id"`
	Aggregate   string          `json:"aggregate"`
	AggregateID string          `json:"aggregate_id"`
	Payload     json.RawMessage `json:"payload"`
}

// TransferPayload is the aggregate-specific body the transfer processor reads
// from the outbox envelope.
type TransferPayload struct {
	TransferID            string `json:"transfer_id"`
	SenderUserID          string `json:"sender_user_id"`
	ReceiverUserID        string `json:"receiver_user_id"`
	ReceiverAccountNumber string `json:"receiver_account_number"`
	AmountKobo            int64  `json:"amount_kobo"`
	Reference             string `json:"reference"`
}

// FinalizePayerPayload is the aggregate-specific body the settlement
// finalize processor reads from the outbox envelope. It names the payer
// whose PENDING offline-payment rows should be drained through Phase 4b
// (lien_holding → receiver.receiving_available). The handler is otherwise
// stateless: Reason is observability-only; the processing logic is the
// same for every enqueue source.
type FinalizePayerPayload struct {
	PayerUserID string    `json:"payer_user_id"`
	Reason      string    `json:"reason"`
	EnqueuedAt  time.Time `json:"enqueued_at"`
}

// Recognised reasons — enum in name only, free-form string on the wire
// for forward compatibility.
const (
	FinalizeReasonClaimAccepted = "claim_accepted"
	FinalizeReasonSyncRequested = "sync_requested"
	FinalizeReasonSweep         = "sweep"
)
