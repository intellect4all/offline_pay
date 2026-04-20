package bff

import (
	"net/http"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	offlinepayv1 "github.com/intellect/offlinepay/internal/transport/grpc/gen/offlinepay/v1"
	bffgen "github.com/intellect/offlinepay/internal/transport/http/bff/gen"
)

func tsToTime(ts *timestamppb.Timestamp) time.Time {
	if ts == nil {
		return time.Time{}
	}
	return ts.AsTime()
}

func tsToTimePtr(ts *timestamppb.Timestamp) *time.Time {
	if ts == nil {
		return nil
	}
	t := ts.AsTime()
	return &t
}

func ceilingStatusToREST(s offlinepayv1.CeilingStatus) bffgen.CeilingTokenStatus {
	return bffgen.CeilingTokenStatus(s.String())
}

func accountKindToREST(k offlinepayv1.AccountKind) bffgen.AccountBalanceKind {
	return bffgen.AccountBalanceKind(k.String())
}

func txStatusToREST(s offlinepayv1.TransactionStatus) bffgen.SyncedTransactionStatus {
	return bffgen.SyncedTransactionStatus(s.String())
}

func ceilingTokenFromProto(c *offlinepayv1.CeilingToken) bffgen.CeilingToken {
	if c == nil {
		return bffgen.CeilingToken{}
	}
	return bffgen.CeilingToken{
		Id:                c.GetId(),
		PayerId:           c.GetPayerId(),
		CeilingAmountKobo: c.GetCeilingAmountKobo(),
		IssuedAt:          tsToTime(c.GetIssuedAt()),
		ExpiresAt:         tsToTime(c.GetExpiresAt()),
		SequenceStart:     c.GetSequenceStart(),
		PayerPublicKey:    c.GetPayerPublicKey(),
		BankKeyId:         c.GetBankKeyId(),
		BankSignature:     c.GetBankSignature(),
		Status:            ceilingStatusToREST(c.GetStatus()),
	}
}

func accountBalanceFromProto(b *offlinepayv1.AccountBalance) bffgen.AccountBalance {
	if b == nil {
		return bffgen.AccountBalance{}
	}
	return bffgen.AccountBalance{
		Kind:        accountKindToREST(b.GetKind()),
		BalanceKobo: b.GetBalanceKobo(),
		Currency:    b.GetCurrency(),
		UpdatedAt:   tsToTime(b.GetUpdatedAt()),
	}
}

func syncedTransactionFromProto(t *offlinepayv1.SyncedTransaction) bffgen.SyncedTransaction {
	if t == nil {
		return bffgen.SyncedTransaction{}
	}
	out := bffgen.SyncedTransaction{
		TransactionId:     t.GetTransactionId(),
		PayerId:           t.GetPayerId(),
		PayeeId:           t.GetPayeeId(),
		AmountKobo:        t.GetAmountKobo(),
		SettledAmountKobo: t.GetSettledAmountKobo(),
		SequenceNumber:    t.GetSequenceNumber(),
		CeilingTokenId:    t.GetCeilingTokenId(),
		Status:            txStatusToREST(t.GetStatus()),
		SubmittedAt:       tsToTimePtr(t.GetSubmittedAt()),
		SettledAt:         tsToTimePtr(t.GetSettledAt()),
	}
	if reason := t.GetRejectionReason(); reason != "" {
		out.RejectionReason = &reason
	}
	return out
}

func bankPublicKeyFromProto(k *offlinepayv1.BankPublicKey) bffgen.BankPublicKey {
	if k == nil {
		return bffgen.BankPublicKey{}
	}
	out := bffgen.BankPublicKey{
		KeyId:      k.GetKeyId(),
		PublicKey:  k.GetPublicKey(),
		ActiveFrom: tsToTime(k.GetActiveFrom()),
	}
	if r := k.GetRetiredAt(); r != nil && r.AsTime().Unix() != 0 {
		t := r.AsTime()
		out.RetiredAt = &t
	}
	return out
}

func realmKeyFromProto(k *offlinepayv1.RealmKey) bffgen.RealmKey {
	if k == nil {
		return bffgen.RealmKey{}
	}
	out := bffgen.RealmKey{
		Version:    k.GetVersion(),
		Key:        k.GetKey(),
		ActiveFrom: tsToTime(k.GetActiveFrom()),
	}
	if r := k.GetRetiredAt(); r != nil && r.AsTime().Unix() != 0 {
		t := r.AsTime()
		out.RetiredAt = &t
	}
	return out
}

func timeToTS(t time.Time) *timestamppb.Timestamp {
	if t.IsZero() {
		return nil
	}
	return timestamppb.New(t)
}

func batchStatusToREST(s offlinepayv1.SettlementBatchStatus) bffgen.BatchReceiptStatus {
	return bffgen.BatchReceiptStatus(s.String())
}

func settlementResultStatusToREST(s offlinepayv1.TransactionStatus) bffgen.SettlementResultStatus {
	return bffgen.SettlementResultStatus(s.String())
}

func settlementResultFromProto(r *offlinepayv1.SettlementResult) bffgen.SettlementResult {
	if r == nil {
		return bffgen.SettlementResult{}
	}
	out := bffgen.SettlementResult{
		TransactionId:       r.GetTransactionId(),
		SequenceNumber:      r.GetSequenceNumber(),
		SubmittedAmountKobo: r.GetSubmittedAmountKobo(),
		SettledAmountKobo:   r.GetSettledAmountKobo(),
		Status:              settlementResultStatusToREST(r.GetStatus()),
	}
	if reason := r.GetReason(); reason != "" {
		out.Reason = &reason
	}
	return out
}

func batchReceiptFromProto(b *offlinepayv1.BatchReceipt) bffgen.BatchReceipt {
	if b == nil {
		return bffgen.BatchReceipt{}
	}
	out := bffgen.BatchReceipt{
		BatchId:         b.GetBatchId(),
		ReceiverUserId:  b.GetReceiverUserId(),
		TotalSubmitted:  b.GetTotalSubmitted(),
		TotalSettled:    b.GetTotalSettled(),
		TotalPartial:    b.GetTotalPartial(),
		TotalRejected:   b.GetTotalRejected(),
		TotalAmountKobo: b.GetTotalAmountKobo(),
		Status:          batchStatusToREST(b.GetStatus()),
		SubmittedAt:     tsToTime(b.GetSubmittedAt()),
		ProcessedAt:     tsToTimePtr(b.GetProcessedAt()),
		Results:         make([]bffgen.SettlementResult, 0, len(b.GetResults())),
	}
	for _, r := range b.GetResults() {
		out.Results = append(out.Results, settlementResultFromProto(r))
	}
	return out
}

func paymentTokenFromInput(in bffgen.PaymentTokenInput) *offlinepayv1.PaymentToken {
	return &offlinepayv1.PaymentToken{
		PayerId:              in.PayerId,
		PayeeId:              in.PayeeId,
		AmountKobo:           in.AmountKobo,
		SequenceNumber:       in.SequenceNumber,
		RemainingCeilingKobo: in.RemainingCeilingKobo,
		Timestamp:            timeToTS(in.Timestamp),
		CeilingTokenId:       in.CeilingTokenId,
		PayerSignature:       in.PayerSignature,
		SessionNonce:         in.SessionNonce,
		RequestHash:          in.RequestHash,
	}
}

func displayCardFromInput(in bffgen.DisplayCardInput) *offlinepayv1.DisplayCard {
	return &offlinepayv1.DisplayCard{
		UserId:          in.UserId,
		DisplayName:     in.DisplayName,
		AccountNumber:   in.AccountNumber,
		IssuedAt:        timeToTS(in.IssuedAt),
		BankKeyId:       in.BankKeyId,
		ServerSignature: in.ServerSignature,
	}
}

func displayCardToInput(c *offlinepayv1.DisplayCard) bffgen.DisplayCardInput {
	if c == nil {
		return bffgen.DisplayCardInput{}
	}
	return bffgen.DisplayCardInput{
		UserId:          c.GetUserId(),
		DisplayName:     c.GetDisplayName(),
		AccountNumber:   c.GetAccountNumber(),
		IssuedAt:        tsToTime(c.GetIssuedAt()),
		BankKeyId:       c.GetBankKeyId(),
		ServerSignature: c.GetServerSignature(),
	}
}

func paymentRequestFromInput(in bffgen.PaymentRequestInput) *offlinepayv1.PaymentRequest {
	return &offlinepayv1.PaymentRequest{
		ReceiverId:           in.ReceiverId,
		ReceiverDisplayCard:  displayCardFromInput(in.ReceiverDisplayCard),
		AmountKobo:           in.AmountKobo,
		SessionNonce:         in.SessionNonce,
		IssuedAt:             timeToTS(in.IssuedAt),
		ExpiresAt:            timeToTS(in.ExpiresAt),
		ReceiverDevicePubkey: in.ReceiverDevicePubkey,
		ReceiverSignature:    in.ReceiverSignature,
	}
}

func ceilingTokenFromInput(in bffgen.CeilingTokenInput) *offlinepayv1.CeilingToken {
	status := offlinepayv1.CeilingStatus(offlinepayv1.CeilingStatus_value[string(in.Status)])
	return &offlinepayv1.CeilingToken{
		Id:                in.Id,
		PayerId:           in.PayerId,
		CeilingAmountKobo: in.CeilingAmountKobo,
		IssuedAt:          timeToTS(in.IssuedAt),
		ExpiresAt:         timeToTS(in.ExpiresAt),
		SequenceStart:     in.SequenceStart,
		PayerPublicKey:    in.PayerPublicKey,
		BankKeyId:         in.BankKeyId,
		BankSignature:     in.BankSignature,
		Status:            status,
	}
}

func gossipBlobFromInput(in bffgen.GossipBlobInput) *offlinepayv1.GossipBlob {
	return &offlinepayv1.GossipBlob{
		TransactionHash:  in.TransactionHash,
		EncryptedBlob:    in.EncryptedBlob,
		BankSignature:    in.BankSignature,
		CeilingTokenHash: in.CeilingTokenHash,
		HopCount:         in.HopCount,
		BlobSize:         in.BlobSize,
	}
}

// grpcHTTPStatus maps gRPC status codes to HTTP status codes for the REST mirror.
func grpcHTTPStatus(err error) (int, string, string) {
	st, ok := status.FromError(err)
	if !ok {
		return http.StatusBadGateway, "upstream_error", err.Error()
	}
	switch st.Code() {
	case codes.OK:
		return http.StatusOK, "", ""
	case codes.NotFound:
		return http.StatusNotFound, "not_found", st.Message()
	case codes.InvalidArgument:
		return http.StatusBadRequest, "invalid_request", st.Message()
	case codes.FailedPrecondition:
		return http.StatusConflict, "precondition_failed", st.Message()
	case codes.AlreadyExists:
		return http.StatusConflict, "already_exists", st.Message()
	case codes.PermissionDenied:
		return http.StatusForbidden, "forbidden", st.Message()
	case codes.Unauthenticated:
		return http.StatusUnauthorized, "unauthorized", st.Message()
	case codes.DeadlineExceeded:
		return http.StatusGatewayTimeout, "deadline_exceeded", st.Message()
	case codes.Canceled:
		// 499 is non-standard (nginx) but commonly used for client-canceled.
		return 499, "canceled", st.Message()
	case codes.Unavailable:
		return http.StatusBadGateway, "upstream_unavailable", st.Message()
	default:
		return http.StatusBadGateway, "upstream_error", st.Message()
	}
}
