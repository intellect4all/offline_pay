// Package server contains gRPC handler implementations for the offlinepay
// v1 services. Handlers adapt proto messages to/from domain types and
// delegate all business logic to the service layer.
package server

import (
	"time"

	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
	pb "github.com/intellect/offlinepay/internal/transport/grpc/gen/offlinepay/v1"
	"github.com/intellect/offlinepay/internal/service/settlement"
)

// tsOrNil returns a proto timestamp, or nil if t is zero.
func tsOrNil(t time.Time) *timestamppb.Timestamp {
	if t.IsZero() {
		return nil
	}
	return timestamppb.New(t)
}

// fromTs returns a time.Time, or zero if ts is nil.
func fromTs(ts *timestamppb.Timestamp) time.Time {
	if ts == nil {
		return time.Time{}
	}
	return ts.AsTime()
}

// CeilingToProto converts a domain.CeilingToken to its wire form.
func CeilingToProto(c domain.CeilingToken) *pb.CeilingToken {
	return &pb.CeilingToken{
		Id:                c.ID,
		PayerId:           c.PayerID,
		CeilingAmountKobo: c.CeilingAmount,
		IssuedAt:          tsOrNil(c.IssuedAt),
		ExpiresAt:         tsOrNil(c.ExpiresAt),
		SequenceStart:     c.SequenceStart,
		PayerPublicKey:    c.PayerPublicKey,
		BankKeyId:         c.BankKeyID,
		BankSignature:     c.BankSignature,
		Status:            ceilingStatusToProto(c.Status),
	}
}

// CeilingFromProto converts a wire CeilingToken to its domain form.
func CeilingFromProto(c *pb.CeilingToken) domain.CeilingToken {
	if c == nil {
		return domain.CeilingToken{}
	}
	return domain.CeilingToken{
		ID:             c.GetId(),
		PayerID:        c.GetPayerId(),
		CeilingAmount:  c.GetCeilingAmountKobo(),
		IssuedAt:       fromTs(c.GetIssuedAt()),
		ExpiresAt:      fromTs(c.GetExpiresAt()),
		SequenceStart:  c.GetSequenceStart(),
		PayerPublicKey: c.GetPayerPublicKey(),
		BankKeyID:      c.GetBankKeyId(),
		BankSignature:  c.GetBankSignature(),
		Status:         ceilingStatusFromProto(c.GetStatus()),
	}
}

// PaymentToProto converts a domain.PaymentToken to its wire form.
func PaymentToProto(p domain.PaymentToken) *pb.PaymentToken {
	return &pb.PaymentToken{
		PayerId:              p.PayerID,
		PayeeId:              p.PayeeID,
		AmountKobo:           p.Amount,
		SequenceNumber:       p.SequenceNumber,
		RemainingCeilingKobo: p.RemainingCeiling,
		Timestamp:            tsOrNil(p.Timestamp),
		CeilingTokenId:       p.CeilingTokenID,
		PayerSignature:       p.PayerSignature,
		SessionNonce:         p.SessionNonce,
		RequestHash:          p.RequestHash,
	}
}

// PaymentFromProto converts a wire PaymentToken to its domain form.
func PaymentFromProto(p *pb.PaymentToken) domain.PaymentToken {
	if p == nil {
		return domain.PaymentToken{}
	}
	return domain.PaymentToken{
		PayerID:          p.GetPayerId(),
		PayeeID:          p.GetPayeeId(),
		Amount:           p.GetAmountKobo(),
		SequenceNumber:   p.GetSequenceNumber(),
		RemainingCeiling: p.GetRemainingCeilingKobo(),
		Timestamp:        fromTs(p.GetTimestamp()),
		CeilingTokenID:   p.GetCeilingTokenId(),
		PayerSignature:   p.GetPayerSignature(),
		SessionNonce:     p.GetSessionNonce(),
		RequestHash:      p.GetRequestHash(),
	}
}

// DisplayCardToProto converts a domain.DisplayCard to the wire form.
func DisplayCardToProto(d domain.DisplayCard) *pb.DisplayCard {
	return &pb.DisplayCard{
		UserId:          d.UserID,
		DisplayName:     d.DisplayName,
		AccountNumber:   d.AccountNumber,
		IssuedAt:        tsOrNil(d.IssuedAt),
		BankKeyId:       d.BankKeyID,
		ServerSignature: d.ServerSignature,
	}
}

// DisplayCardFromProto converts the wire DisplayCard to domain.
func DisplayCardFromProto(d *pb.DisplayCard) domain.DisplayCard {
	if d == nil {
		return domain.DisplayCard{}
	}
	return domain.DisplayCard{
		UserID:          d.GetUserId(),
		DisplayName:     d.GetDisplayName(),
		AccountNumber:   d.GetAccountNumber(),
		IssuedAt:        fromTs(d.GetIssuedAt()),
		BankKeyID:       d.GetBankKeyId(),
		ServerSignature: d.GetServerSignature(),
	}
}

// PaymentRequestToProto converts a domain.PaymentRequest to the wire form.
func PaymentRequestToProto(r domain.PaymentRequest) *pb.PaymentRequest {
	return &pb.PaymentRequest{
		ReceiverId:           r.ReceiverID,
		ReceiverDisplayCard:  DisplayCardToProto(r.ReceiverDisplayCard),
		AmountKobo:           r.Amount,
		SessionNonce:         r.SessionNonce,
		IssuedAt:             tsOrNil(r.IssuedAt),
		ExpiresAt:            tsOrNil(r.ExpiresAt),
		ReceiverDevicePubkey: r.ReceiverDevicePubkey,
		ReceiverSignature:    r.ReceiverSignature,
	}
}

// PaymentRequestFromProto converts the wire PaymentRequest to domain.
func PaymentRequestFromProto(r *pb.PaymentRequest) domain.PaymentRequest {
	if r == nil {
		return domain.PaymentRequest{}
	}
	return domain.PaymentRequest{
		ReceiverID:           r.GetReceiverId(),
		ReceiverDisplayCard:  DisplayCardFromProto(r.GetReceiverDisplayCard()),
		Amount:               r.GetAmountKobo(),
		SessionNonce:         r.GetSessionNonce(),
		IssuedAt:             fromTs(r.GetIssuedAt()),
		ExpiresAt:            fromTs(r.GetExpiresAt()),
		ReceiverDevicePubkey: r.GetReceiverDevicePubkey(),
		ReceiverSignature:    r.GetReceiverSignature(),
	}
}

// GossipBlobFromProto converts the wire form to domain.
func GossipBlobFromProto(b *pb.GossipBlob) domain.GossipBlob {
	if b == nil {
		return domain.GossipBlob{}
	}
	return domain.GossipBlob{
		TransactionHash:  b.GetTransactionHash(),
		EncryptedBlob:    b.GetEncryptedBlob(),
		BankSignature:    b.GetBankSignature(),
		CeilingTokenHash: b.GetCeilingTokenHash(),
		HopCount:         int(b.GetHopCount()),
		BlobSize:         int(b.GetBlobSize()),
	}
}

// SettlementResultToProto converts a domain.SettlementResult.
func SettlementResultToProto(r domain.SettlementResult) *pb.SettlementResult {
	return &pb.SettlementResult{
		TransactionId:       r.TransactionID,
		SequenceNumber:      r.SequenceNumber,
		SubmittedAmountKobo: r.SubmittedAmount,
		SettledAmountKobo:   r.SettledAmount,
		Status:              txStatusToProto(r.Status),
		Reason:              r.Reason,
	}
}

// BatchReceiptToProto combines a batch + per-txn results.
func BatchReceiptToProto(b domain.SettlementBatch, results []domain.SettlementResult) *pb.BatchReceipt {
	out := &pb.BatchReceipt{
		BatchId:         b.ID,
		ReceiverUserId:  b.ReceiverID,
		TotalSubmitted:  int32(b.TotalSubmitted),
		TotalSettled:    int32(b.TotalSettled),
		TotalPartial:    int32(b.TotalPartial),
		TotalRejected:   int32(b.TotalRejected),
		TotalAmountKobo: b.TotalAmount,
		Status:          batchStatusToProto(b.Status),
		SubmittedAt:     tsOrNil(b.SubmittedAt),
	}
	if b.ProcessedAt != nil {
		out.ProcessedAt = tsOrNil(*b.ProcessedAt)
	}
	out.Results = make([]*pb.SettlementResult, 0, len(results))
	for _, r := range results {
		out.Results = append(out.Results, SettlementResultToProto(r))
	}
	return out
}

// ClaimItemsFromProto pairs parallel token + ceiling + request slices
// into ClaimItems. PaymentRequests are matched to their PaymentToken by
// equal session_nonce (a 16B opaque ID shared across the signed pair).
// Tokens with no matching request arrive with a zero-valued Request —
// settlement will reject those at the binding checks.
func ClaimItemsFromProto(tokens []*pb.PaymentToken, ceilings []*pb.CeilingToken, requests []*pb.PaymentRequest) []settlement.ClaimItem {
	byID := make(map[string]domain.CeilingToken, len(ceilings))
	for _, c := range ceilings {
		d := CeilingFromProto(c)
		byID[d.ID] = d
	}
	byNonce := make(map[string]domain.PaymentRequest, len(requests))
	for _, r := range requests {
		d := PaymentRequestFromProto(r)
		byNonce[string(d.SessionNonce)] = d
	}
	items := make([]settlement.ClaimItem, 0, len(tokens))
	for _, t := range tokens {
		pm := PaymentFromProto(t)
		items = append(items, settlement.ClaimItem{
			Payment: pm,
			Ceiling: byID[pm.CeilingTokenID],
			Request: byNonce[string(pm.SessionNonce)],
		})
	}
	return items
}

// TxnToSyncedProto emits the SyncedTransaction wire form.
func TxnToSyncedProto(t domain.Transaction) *pb.SyncedTransaction {
	reason := ""
	if t.RejectionReason != nil {
		reason = *t.RejectionReason
	}
	return &pb.SyncedTransaction{
		TransactionId:     t.ID,
		PayerId:           t.PayerID,
		PayeeId:           t.PayeeID,
		AmountKobo:        t.Amount,
		SettledAmountKobo: t.SettledAmount,
		SequenceNumber:    t.SequenceNumber,
		CeilingTokenId:    t.CeilingTokenID,
		Status:            txStatusToProto(t.Status),
		RejectionReason:   reason,
		SubmittedAt:       tsPtrOrNil(t.SubmittedAt),
		SettledAt:         tsPtrOrNil(t.SettledAt),
	}
}

func tsPtrOrNil(t *time.Time) *timestamppb.Timestamp {
	if t == nil || t.IsZero() {
		return nil
	}
	return timestamppb.New(*t)
}

func ceilingStatusToProto(s domain.CeilingStatus) pb.CeilingStatus {
	switch s {
	case domain.CeilingActive:
		return pb.CeilingStatus_CEILING_STATUS_ACTIVE
	case domain.CeilingExpired:
		return pb.CeilingStatus_CEILING_STATUS_EXPIRED
	case domain.CeilingExhausted:
		return pb.CeilingStatus_CEILING_STATUS_EXHAUSTED
	case domain.CeilingRevoked:
		return pb.CeilingStatus_CEILING_STATUS_REVOKED
	}
	return pb.CeilingStatus_CEILING_STATUS_UNSPECIFIED
}

func ceilingStatusFromProto(s pb.CeilingStatus) domain.CeilingStatus {
	switch s {
	case pb.CeilingStatus_CEILING_STATUS_ACTIVE:
		return domain.CeilingActive
	case pb.CeilingStatus_CEILING_STATUS_EXPIRED:
		return domain.CeilingExpired
	case pb.CeilingStatus_CEILING_STATUS_EXHAUSTED:
		return domain.CeilingExhausted
	case pb.CeilingStatus_CEILING_STATUS_REVOKED:
		return domain.CeilingRevoked
	}
	return ""
}

func txStatusToProto(s domain.TransactionStatus) pb.TransactionStatus {
	switch s {
	case domain.TxQueued:
		return pb.TransactionStatus_TRANSACTION_STATUS_QUEUED
	case domain.TxSubmitted:
		return pb.TransactionStatus_TRANSACTION_STATUS_SUBMITTED
	case domain.TxPending:
		return pb.TransactionStatus_TRANSACTION_STATUS_PENDING
	case domain.TxSettled:
		return pb.TransactionStatus_TRANSACTION_STATUS_SETTLED
	case domain.TxPartiallySettled:
		return pb.TransactionStatus_TRANSACTION_STATUS_PARTIALLY_SETTLED
	case domain.TxRejected:
		return pb.TransactionStatus_TRANSACTION_STATUS_REJECTED
	case domain.TxExpired:
		return pb.TransactionStatus_TRANSACTION_STATUS_EXPIRED
	}
	return pb.TransactionStatus_TRANSACTION_STATUS_UNSPECIFIED
}

func txStatusFromProto(s pb.TransactionStatus) domain.TransactionStatus {
	switch s {
	case pb.TransactionStatus_TRANSACTION_STATUS_QUEUED:
		return domain.TxQueued
	case pb.TransactionStatus_TRANSACTION_STATUS_SUBMITTED:
		return domain.TxSubmitted
	case pb.TransactionStatus_TRANSACTION_STATUS_PENDING:
		return domain.TxPending
	case pb.TransactionStatus_TRANSACTION_STATUS_SETTLED:
		return domain.TxSettled
	case pb.TransactionStatus_TRANSACTION_STATUS_PARTIALLY_SETTLED:
		return domain.TxPartiallySettled
	case pb.TransactionStatus_TRANSACTION_STATUS_REJECTED:
		return domain.TxRejected
	case pb.TransactionStatus_TRANSACTION_STATUS_EXPIRED:
		return domain.TxExpired
	}
	return ""
}

func batchStatusToProto(s domain.SettlementBatchStatus) pb.SettlementBatchStatus {
	switch s {
	case domain.BatchReceived:
		return pb.SettlementBatchStatus_SETTLEMENT_BATCH_STATUS_RECEIVED
	case domain.BatchProcessing:
		return pb.SettlementBatchStatus_SETTLEMENT_BATCH_STATUS_PROCESSING
	case domain.BatchCompleted:
		return pb.SettlementBatchStatus_SETTLEMENT_BATCH_STATUS_COMPLETED
	case domain.BatchFailed:
		return pb.SettlementBatchStatus_SETTLEMENT_BATCH_STATUS_FAILED
	}
	return pb.SettlementBatchStatus_SETTLEMENT_BATCH_STATUS_UNSPECIFIED
}

func accountKindToProto(k sqlcgen.AccountKind) pb.AccountKind {
	switch k {
	case sqlcgen.AccountKindMain:
		return pb.AccountKind_ACCOUNT_KIND_MAIN
	case sqlcgen.AccountKindLienHolding:
		return pb.AccountKind_ACCOUNT_KIND_LIEN_HOLDING
	case sqlcgen.AccountKindReceivingPending:
		return pb.AccountKind_ACCOUNT_KIND_RECEIVING_PENDING
	}
	return pb.AccountKind_ACCOUNT_KIND_UNSPECIFIED
}

// compile-time silencers
var (
	_ = txStatusFromProto
	_ = accountKindToProto
)
