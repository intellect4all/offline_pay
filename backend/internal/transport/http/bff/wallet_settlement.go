package bff

import (
	"context"
	"net/http"

	"google.golang.org/protobuf/types/known/timestamppb"

	offlinepayv1 "github.com/intellect/offlinepay/internal/transport/grpc/gen/offlinepay/v1"
	"github.com/intellect/offlinepay/internal/transport/grpc/server"
	bffgen "github.com/intellect/offlinepay/internal/transport/http/bff/gen"
)

func (h *Handler) PostV1WalletFundOffline(ctx context.Context, req bffgen.PostV1WalletFundOfflineRequestObject) (bffgen.PostV1WalletFundOfflineResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1WalletFundOffline401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1WalletFundOffline400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}

	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Wallet.FundOffline(ctx, &offlinepayv1.FundOfflineRequest{
		UserId:         claims.Sub,
		AmountKobo:     req.Body.AmountKobo,
		TtlSeconds:     req.Body.TtlSeconds,
		PayerPublicKey: req.Body.PayerPublicKey,
	})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("wallet.fund_offline", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.PostV1WalletFundOffline400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusUnauthorized:
			return bffgen.PostV1WalletFundOffline401JSONResponse{Code: code, Message: msg}, nil
		case http.StatusForbidden:
			return bffgen.PostV1WalletFundOffline403JSONResponse{Code: code, Message: msg}, nil
		case http.StatusConflict:
			return bffgen.PostV1WalletFundOffline409JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.PostV1WalletFundOffline502JSONResponse{Code: code, Message: msg}, nil
		}
	}
	return bffgen.PostV1WalletFundOffline200JSONResponse{
		Ceiling: ceilingTokenFromProto(resp.GetCeiling()),
		LienId:  resp.GetLienId(),
	}, nil
}

func (h *Handler) GetV1WalletBalances(ctx context.Context, _ bffgen.GetV1WalletBalancesRequestObject) (bffgen.GetV1WalletBalancesResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.GetV1WalletBalances401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Wallet.GetBalances(ctx, &offlinepayv1.GetBalancesRequest{UserId: claims.Sub})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("wallet.get_balances", "code", code, "err", err)
		if statusCode == http.StatusUnauthorized {
			return bffgen.GetV1WalletBalances401JSONResponse{Code: code, Message: msg}, nil
		}
		return bffgen.GetV1WalletBalances502JSONResponse{Code: code, Message: msg}, nil
	}
	out := bffgen.GetV1WalletBalances200JSONResponse{
		AsOf:     tsToTime(resp.GetAsOf()),
		Balances: make([]bffgen.AccountBalance, 0, len(resp.GetBalances())),
	}
	for _, b := range resp.GetBalances() {
		out.Balances = append(out.Balances, accountBalanceFromProto(b))
	}
	return out, nil
}

func (h *Handler) GetV1WalletCeilingCurrent(ctx context.Context, _ bffgen.GetV1WalletCeilingCurrentRequestObject) (bffgen.GetV1WalletCeilingCurrentResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.GetV1WalletCeilingCurrent401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Wallet.GetCurrentCeiling(ctx, &server.GetCurrentCeilingRequest{UserID: claims.Sub})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("wallet.get_current_ceiling", "code", code, "err", err)
		if statusCode == http.StatusUnauthorized {
			return bffgen.GetV1WalletCeilingCurrent401JSONResponse{Code: code, Message: msg}, nil
		}
		return nil, err
	}
	out := bffgen.GetV1WalletCeilingCurrent200JSONResponse{Present: resp.Present}
	if resp.Present {
		id := resp.CeilingID
		status := resp.Status
		ceiling := resp.CeilingKobo
		settled := resp.SettledKobo
		remaining := resp.RemainingKobo
		issued := resp.IssuedAt
		expires := resp.ExpiresAt
		out.CeilingId = &id
		out.Status = &status
		out.CeilingKobo = &ceiling
		out.SettledKobo = &settled
		out.RemainingKobo = &remaining
		out.IssuedAt = &issued
		out.ExpiresAt = &expires
		if !resp.ReleaseAfter.IsZero() {
			ra := resp.ReleaseAfter
			out.ReleaseAfter = &ra
		}
	}
	return out, nil
}

func (h *Handler) PostV1WalletRecoverOfflineCeiling(ctx context.Context, _ bffgen.PostV1WalletRecoverOfflineCeilingRequestObject) (bffgen.PostV1WalletRecoverOfflineCeilingResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1WalletRecoverOfflineCeiling401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Wallet.RecoverOfflineCeiling(ctx, &server.RecoverOfflineCeilingRequest{UserID: claims.Sub})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("wallet.recover_offline_ceiling", "code", code, "err", err)
		switch statusCode {
		case http.StatusUnauthorized:
			return bffgen.PostV1WalletRecoverOfflineCeiling401JSONResponse{Code: code, Message: msg}, nil
		case http.StatusNotFound:
			return bffgen.PostV1WalletRecoverOfflineCeiling404JSONResponse{Code: "no_active_ceiling", Message: msg}, nil
		case http.StatusConflict:
			return bffgen.PostV1WalletRecoverOfflineCeiling409JSONResponse{Code: "unsettled_claims", Message: msg}, nil
		case http.StatusPreconditionFailed:
			// FailedPrecondition covers both ErrUnsettledClaims and
			// ErrRecoveryRaceLost — both are 409 from the client's POV.
			return bffgen.PostV1WalletRecoverOfflineCeiling409JSONResponse{Code: code, Message: msg}, nil
		default:
			return nil, err
		}
	}
	return bffgen.PostV1WalletRecoverOfflineCeiling200JSONResponse{
		CeilingId:       resp.CeilingID,
		QuarantinedKobo: resp.QuarantinedKobo,
		ReleaseAfter:    resp.ReleaseAfter,
	}, nil
}

func (h *Handler) PostV1WalletMoveToMain(ctx context.Context, _ bffgen.PostV1WalletMoveToMainRequestObject) (bffgen.PostV1WalletMoveToMainResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1WalletMoveToMain401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Wallet.MoveToMain(ctx, &offlinepayv1.MoveToMainRequest{UserId: claims.Sub})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("wallet.move_to_main", "code", code, "err", err)
		switch statusCode {
		case http.StatusUnauthorized:
			return bffgen.PostV1WalletMoveToMain401JSONResponse{Code: code, Message: msg}, nil
		case http.StatusConflict:
			return bffgen.PostV1WalletMoveToMain409JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.PostV1WalletMoveToMain502JSONResponse{Code: code, Message: msg}, nil
		}
	}
	return bffgen.PostV1WalletMoveToMain200JSONResponse{
		ReleasedKobo:       resp.GetReleasedKobo(),
		NewMainBalanceKobo: resp.GetNewMainBalanceKobo(),
	}, nil
}

func (h *Handler) PostV1WalletRefreshCeiling(ctx context.Context, req bffgen.PostV1WalletRefreshCeilingRequestObject) (bffgen.PostV1WalletRefreshCeilingResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1WalletRefreshCeiling401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}
	if req.Body == nil {
		return bffgen.PostV1WalletRefreshCeiling400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}
	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Wallet.RefreshCeiling(ctx, &offlinepayv1.RefreshCeilingRequest{
		UserId:         claims.Sub,
		NewAmountKobo:  req.Body.NewAmountKobo,
		TtlSeconds:     req.Body.TtlSeconds,
		PayerPublicKey: req.Body.PayerPublicKey,
	})
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("wallet.refresh_ceiling", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.PostV1WalletRefreshCeiling400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusUnauthorized:
			return bffgen.PostV1WalletRefreshCeiling401JSONResponse{Code: code, Message: msg}, nil
		case http.StatusConflict:
			return bffgen.PostV1WalletRefreshCeiling409JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.PostV1WalletRefreshCeiling502JSONResponse{Code: code, Message: msg}, nil
		}
	}
	return bffgen.PostV1WalletRefreshCeiling200JSONResponse{
		Ceiling: ceilingTokenFromProto(resp.GetCeiling()),
		LienId:  resp.GetLienId(),
	}, nil
}

func (h *Handler) PostV1SettlementSync(ctx context.Context, req bffgen.PostV1SettlementSyncRequestObject) (bffgen.PostV1SettlementSyncResponseObject, error) {
	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1SettlementSync401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}

	pb := &offlinepayv1.SyncUserRequest{UserId: claims.Sub}
	if req.Body != nil {
		if req.Body.Since != nil && !req.Body.Since.IsZero() {
			pb.Since = timestamppb.New(*req.Body.Since)
		}
		if req.Body.DisputedTransactionIds != nil {
			pb.DisputedTransactionIds = *req.Body.DisputedTransactionIds
		}
		if req.Body.Finalize != nil {
			pb.Finalize = *req.Body.Finalize
		}
	}

	ctx = authCtx(ctx, claims.Sub)
	resp, err := h.Settlement.SyncUser(ctx, pb)
	if err != nil {
		statusCode, code, msg := grpcHTTPStatus(err)
		h.Logger.Warn("settlement.sync_user", "code", code, "err", err)
		switch statusCode {
		case http.StatusBadRequest:
			return bffgen.PostV1SettlementSync400JSONResponse{Code: code, Message: msg}, nil
		case http.StatusUnauthorized:
			return bffgen.PostV1SettlementSync401JSONResponse{Code: code, Message: msg}, nil
		default:
			return bffgen.PostV1SettlementSync502JSONResponse{Code: code, Message: msg}, nil
		}
	}

	fp := resp.GetFinalizePending()
	out := bffgen.PostV1SettlementSync200JSONResponse{
		SyncedAt:        tsToTime(resp.GetSyncedAt()),
		FinalizedCount:  resp.GetFinalizedCount(),
		FinalizePending: &fp,
		PayerSide:       make([]bffgen.SyncedTransaction, 0, len(resp.GetPayerSide())),
		ReceiverSide:    make([]bffgen.SyncedTransaction, 0, len(resp.GetReceiverSide())),
	}
	for _, t := range resp.GetPayerSide() {
		out.PayerSide = append(out.PayerSide, syncedTransactionFromProto(t))
	}
	for _, t := range resp.GetReceiverSide() {
		out.ReceiverSide = append(out.ReceiverSide, syncedTransactionFromProto(t))
	}
	return out, nil
}
