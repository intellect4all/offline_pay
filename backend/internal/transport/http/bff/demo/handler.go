// Package demo registers the unauthenticated /demo/fund surface on the
// BFF. It is a thin JSON + static-file layer over demomint.Service.
//
// Routes:
//   GET  /demo/fund            → HTML page (embedded)
//   GET  /demo/app.js          → JS (embedded)
//   POST /demo/name-enquiry    → {account_number, bank_code} → {full_name}
//   POST /demo/fund            → {account_number, bank_code, amount_kobo}
//                                 → {txn_id, new_balance_kobo}
//
// The routes are intentionally outside the /v1/* OpenAPI surface and
// not described in api/openapi.yaml — they exist solely to unblock
// demo flows. Gate the mount with cfg.DemoMintEnabled.
package demo

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/intellect/offlinepay/internal/logging"
	"github.com/intellect/offlinepay/internal/service/demomint"
)

// Mount wires the demo routes on r. When enabled is false Mount is a
// no-op — the routes are not registered and requests fall through to
// the 404 handler.
func Mount(r chi.Router, svc *demomint.Service, logger *slog.Logger, enabled bool) {
	if !enabled || svc == nil {
		return
	}
	h := &handler{svc: svc, log: logging.Or(logger)}
	r.Get("/demo/fund", h.serveIndex)
	r.Get("/demo/app.js", h.serveAppJS)
	r.Post("/demo/name-enquiry", h.nameEnquiry)
	r.Post("/demo/fund", h.fund)
}

type handler struct {
	svc *demomint.Service
	log *slog.Logger
}

func (h *handler) serveIndex(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write(indexHTML)
}

func (h *handler) serveAppJS(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/javascript; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write(appJS)
}

type nameEnquiryRequest struct {
	AccountNumber string `json:"account_number"`
	BankCode      string `json:"bank_code"`
}

type nameEnquiryResponse struct {
	FullName      string `json:"full_name"`
	AccountNumber string `json:"account_number"`
}

func (h *handler) nameEnquiry(w http.ResponseWriter, r *http.Request) {
	var req nameEnquiryRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "bad_request", "invalid JSON body")
		return
	}
	res, err := h.svc.NameEnquiry(r.Context(), req.AccountNumber, req.BankCode)
	if err != nil {
		h.renderServiceError(w, err, "name_enquiry")
		return
	}
	writeJSON(w, http.StatusOK, nameEnquiryResponse{
		FullName:      res.FullName,
		AccountNumber: res.AccountNumber,
	})
}

type fundRequest struct {
	AccountNumber string `json:"account_number"`
	BankCode      string `json:"bank_code"`
	AmountKobo    int64  `json:"amount_kobo"`
}

type fundResponse struct {
	TxnID          string `json:"txn_id"`
	NewBalanceKobo int64  `json:"new_balance_kobo"`
}

func (h *handler) fund(w http.ResponseWriter, r *http.Request) {
	var req fundRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "bad_request", "invalid JSON body")
		return
	}
	res, err := h.svc.Fund(r.Context(), req.AccountNumber, req.BankCode, req.AmountKobo)
	if err != nil {
		h.renderServiceError(w, err, "fund")
		return
	}
	writeJSON(w, http.StatusOK, fundResponse{
		TxnID:          res.TxnID,
		NewBalanceKobo: res.NewBalanceKobo,
	})
}

// renderServiceError maps demomint sentinel errors onto HTTP statuses.
// Anything unexpected falls through as a 500 with the error logged.
func (h *handler) renderServiceError(w http.ResponseWriter, err error, op string) {
	switch {
	case errors.Is(err, demomint.ErrAccountNotFound):
		writeErr(w, http.StatusNotFound, "account_not_found", "no account found for the supplied number")
	case errors.Is(err, demomint.ErrAmountOutOfRange):
		writeErr(w, http.StatusBadRequest, "invalid_amount", "amount must be between ₦1 and ₦500,000")
	case errors.Is(err, demomint.ErrUnsupportedBank):
		writeErr(w, http.StatusBadRequest, "unsupported_bank", "only Test Bank is supported")
	case errors.Is(err, demomint.ErrMissingAccountNum):
		writeErr(w, http.StatusBadRequest, "missing_account_number", "account_number is required")
	case errors.Is(err, demomint.ErrTreasuryExhausted):
		writeErr(w, http.StatusServiceUnavailable, "treasury_exhausted", "demo treasury is out of funds")
	default:
		h.log.Error("demo."+op, "err", err)
		writeErr(w, http.StatusInternalServerError, "internal_error", "unexpected error")
	}
}

type errorBody struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func writeErr(w http.ResponseWriter, status int, code, msg string) {
	writeJSON(w, status, errorBody{Code: code, Message: msg})
}
