package admin

import (
	"net/http"
)

func (h *Handler) listKYC(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	res, err := h.Svc.ListKYC(r.Context(), id)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, res)
}

func (h *Handler) kycHint(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	res, err := h.Svc.KYCHint(r.Context(), id)
	if err != nil {
		writeErr(w, 404, err.Error())
		return
	}
	writeJSON(w, 200, res)
}
