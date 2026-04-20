package bff

import (
	"context"

	bffgen "github.com/intellect/offlinepay/internal/transport/http/bff/gen"
)

// PostV1WalletTopUp is a dev-only endpoint that credits the authenticated
// user's main wallet by a given amount. It does NOT create a ledger entry
// (no double-entry bookkeeping) — the money is fake and exists solely to
// unblock E2E testing on-device without psql access.
//
// TODO: replace with real funding integration (bank transfer / card / USSD).
func (h *Handler) PostV1WalletTopUp(ctx context.Context, req bffgen.PostV1WalletTopUpRequestObject) (bffgen.PostV1WalletTopUpResponseObject, error) {
	// Feature gate: disabled by default in production.
	if !h.DevTopUpEnabled || h.Pool == nil {
		return bffgen.PostV1WalletTopUp404JSONResponse{Code: "not_found", Message: "not found"}, nil
	}

	claims, ok := ClaimsFromContext(ctx)
	if !ok || claims.Sub == "" {
		return bffgen.PostV1WalletTopUp401JSONResponse{Code: "unauthorized", Message: "missing claims"}, nil
	}

	if req.Body == nil {
		return bffgen.PostV1WalletTopUp400JSONResponse{Code: "bad_request", Message: "missing body"}, nil
	}

	amount := req.Body.AmountKobo
	if amount <= 0 || amount > 10_000_000 {
		return bffgen.PostV1WalletTopUp400JSONResponse{
			Code:    "invalid_amount",
			Message: "amount_kobo must be between 1 and 10000000 (max 100k naira)",
		}, nil
	}

	// Credit the main account directly. No ledger entry — this is fake
	// dev money. The UPDATE is safe against concurrent calls because
	// balance_kobo + $1 is atomic under PostgreSQL's row-level lock.
	const q = `UPDATE accounts SET balance_kobo = balance_kobo + $1, updated_at = now()
		WHERE user_id = $2 AND kind = 'main'
		RETURNING balance_kobo`

	var newBalance int64
	err := h.Pool.QueryRow(ctx, q, amount, claims.Sub).Scan(&newBalance)
	if err != nil {
		h.Logger.Error("wallet.dev_topup", "err", err, "user_id", claims.Sub)
		return nil, err
	}

	return bffgen.PostV1WalletTopUp200JSONResponse{NewBalanceKobo: newBalance}, nil
}
