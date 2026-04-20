package bff

import (
	"context"
	"net/http"

	offlinepayv1 "github.com/intellect/offlinepay/internal/transport/grpc/gen/offlinepay/v1"
	bffgen "github.com/intellect/offlinepay/internal/transport/http/bff/gen"
)

func (h *Handler) PostV1SettlementClaims(ctx context.Context, req bffgen.PostV1SettlementClaimsRequestObject) (bffgen.PostV1SettlementClaimsResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1SettlementClaims401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1SettlementClaims400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}

	pb := &offlinepayv1.SubmitClaimRequest{
		ReceiverUserId: claims.Sub,
		ClientBatchId:  req.Body.ClientBatchId,
		Tokens:         make([]*offlinepayv1.PaymentToken, 0, len(req.Body.Tokens)),
		Ceilings:       make([]*offlinepayv1.CeilingToken, 0, len(req.Body.Ceilings)),
		Requests:       make([]*offlinepayv1.PaymentRequest, 0, len(req.Body.Requests)),
	}
	for _, t := range req.Body.Tokens {
		pb.Tokens = append(pb.Tokens, paymentTokenFromInput(t))
	}
	for _, c := range req.Body.Ceilings {
		pb.Ceilings = append(pb.Ceilings, ceilingTokenFromInput(c))
	}
	for _, r := range req.Body.Requests {
		pb.Requests = append(pb.Requests, paymentRequestFromInput(r))
	}

	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Settlement.SubmitClaim(ctx, pb)
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("settlement.submit_claim", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.PostV1SettlementClaims400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusUnauthorized:
			return bffgen.PostV1SettlementClaims401JSONResponse{Code: code, Message: msg}, nil
		case http.StatusForbidden:
			return bffgen.PostV1SettlementClaims403JSONResponse{Code: code, Message: msg}, nil
		case http.StatusConflict:
			return bffgen.PostV1SettlementClaims409JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.PostV1SettlementClaims502JSONResponse{Code: code, Message: msg}, nil
		}
	}

	return bffgen.PostV1SettlementClaims200JSONResponse(batchReceiptFromProto(resp.GetReceipt())), nil
}

func (h *Handler) GetV1SettlementClaimsBatchID(ctx context.Context, req bffgen.GetV1SettlementClaimsBatchIDRequestObject) (bffgen.GetV1SettlementClaimsBatchIDResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.GetV1SettlementClaimsBatchID401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}

	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Settlement.GetBatchReceipt(ctx, &offlinepayv1.GetBatchReceiptRequest{
		BatchId: req.BatchId,
		UserId:  claims.Sub,
	})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("settlement.get_batch_receipt", "code", code, "err", err)
		switch statusCode {
		case http.StatusUnauthorized:
			return bffgen.GetV1SettlementClaimsBatchID401JSONResponse{Code: code, Message: msg}, nil
		case http.StatusForbidden:
			return bffgen.GetV1SettlementClaimsBatchID403JSONResponse{Code: code, Message: msg}, nil
		case http.StatusNotFound:
			return bffgen.GetV1SettlementClaimsBatchID404JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.GetV1SettlementClaimsBatchID502JSONResponse{Code: code, Message: msg}, nil
		}
	}

	return bffgen.GetV1SettlementClaimsBatchID200JSONResponse(batchReceiptFromProto(resp.GetReceipt())), nil
}

func (h *Handler) PostV1SettlementGossip(ctx context.Context, req bffgen.PostV1SettlementGossipRequestObject) (bffgen.PostV1SettlementGossipResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1SettlementGossip401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1SettlementGossip400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}

	pb := &offlinepayv1.GossipUploadRequest{
		UploaderUserId: claims.Sub,
		Blobs:          make([]*offlinepayv1.GossipBlob, 0, len(req.Body.Blobs)),
	}
	for _, b := range req.Body.Blobs {
		pb.Blobs = append(pb.Blobs, gossipBlobFromInput(b))
	}

	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Settlement.GossipUpload(ctx, pb)
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("settlement.gossip_upload", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.PostV1SettlementGossip400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusUnauthorized:
			return bffgen.PostV1SettlementGossip401JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.PostV1SettlementGossip502JSONResponse{Code: code, Message: msg}, nil
		}
	}

	return bffgen.PostV1SettlementGossip200JSONResponse{
		Accepted:   resp.GetAccepted(),
		Duplicates: resp.GetDuplicates(),
		Invalid:    resp.GetInvalid(),
	}, nil
}
