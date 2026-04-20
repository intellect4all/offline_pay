// Package admin provides the HTTP handlers for the backoffice admin-api.
// Uses stdlib net/http with the Go 1.22+ ServeMux path-pattern syntax.
package admin

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	svc "github.com/intellect/offlinepay/internal/service/admin"
)

type ctxKey int

const ctxClaims ctxKey = 1

// Handler holds dependencies shared across HTTP handlers.
type Handler struct {
	Svc *svc.Service
}

func NewHandler(s *svc.Service) *Handler { return &Handler{Svc: s} }

// Mux builds the admin HTTP mux: /healthz + /v1/* JSON endpoints with CORS
// and auth middleware wired in.
func (h *Handler) Mux(allowedOrigin string) http.Handler {
	mux := http.NewServeMux()

	// Unauthenticated.
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("POST /v1/auth/login", h.login)
	mux.HandleFunc("POST /v1/auth/refresh", h.refresh)
	mux.HandleFunc("POST /v1/auth/logout", h.logout)

	// Authenticated (all roles).
	mux.Handle("GET /v1/me", h.authed(h.me))
	mux.Handle("GET /v1/overview/stats", h.authed(h.overview))
	mux.Handle("GET /v1/overview/volume", h.authed(h.volume))

	mux.Handle("GET /v1/users", h.authed(h.listUsers))
	mux.Handle("GET /v1/users/{id}", h.authed(h.getUser))
	mux.Handle("GET /v1/users/{id}/kyc", h.authed(h.listKYC))
	mux.Handle("GET /v1/users/{id}/kyc/hint", h.authed(h.kycHint))

	mux.Handle("GET /v1/transactions", h.authed(h.listTransactions))
	mux.Handle("GET /v1/transactions/{id}", h.authed(h.getTransaction))

	mux.Handle("GET /v1/settlements", h.authed(h.listSettlements))
	mux.Handle("GET /v1/settlements/{id}", h.authed(h.getSettlement))

	mux.Handle("GET /v1/fraud", h.authed(h.listFraud))

	mux.Handle("GET /v1/audit", h.authed(h.requireRole(svc.RoleSuperAdmin, h.listAudit)))

	return cors(allowedOrigin, logReq(mux))
}

func cors(origin string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if origin != "" {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Credentials", "true")
			w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization,Content-Type")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func logReq(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sw := &statusRecorder{ResponseWriter: w, status: 200}
		next.ServeHTTP(sw, r)
		slog.Info("admin http", "method", r.Method, "path", r.URL.Path,
			"status", sw.status, "dur_ms", time.Since(start).Milliseconds())
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(c int) { s.status = c; s.ResponseWriter.WriteHeader(c) }

func (h *Handler) authed(next http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tok := bearerToken(r)
		if tok == "" {
			writeErr(w, http.StatusUnauthorized, "missing bearer token")
			return
		}
		claims, err := h.Svc.Signer.Verify(tok)
		if err != nil {
			writeErr(w, http.StatusUnauthorized, err.Error())
			return
		}
		ctx := context.WithValue(r.Context(), ctxClaims, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (h *Handler) requireAnyRole(roles []string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		c, ok := r.Context().Value(ctxClaims).(svc.AccessClaims)
		if !ok {
			writeErr(w, http.StatusForbidden, "no claims")
			return
		}
		for _, needed := range roles {
			if hasRole(c.Roles, needed) {
				next.ServeHTTP(w, r)
				return
			}
		}
		writeErr(w, http.StatusForbidden, "requires one of: "+strings.Join(roles, ","))
	}
}

func (h *Handler) requireRole(role string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		c, ok := r.Context().Value(ctxClaims).(svc.AccessClaims)
		if !ok || !hasRole(c.Roles, role) {
			writeErr(w, http.StatusForbidden, "requires role: "+role)
			return
		}
		next.ServeHTTP(w, r)
	}
}

func hasRole(roles []string, needed string) bool {
	for _, r := range roles {
		if r == needed {
			return true
		}
	}
	return false
}

func bearerToken(r *http.Request) string {
	h := r.Header.Get("Authorization")
	if strings.HasPrefix(h, "Bearer ") {
		return strings.TrimPrefix(h, "Bearer ")
	}
	return ""
}

type loginReq struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (h *Handler) login(w http.ResponseWriter, r *http.Request) {
	var req loginReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "bad json")
		return
	}
	res, err := h.Svc.Login(r.Context(), req.Email, req.Password, r.UserAgent(), clientIP(r))
	if err != nil {
		writeErr(w, http.StatusUnauthorized, err.Error())
		return
	}
	h.Svc.Audit(r.Context(), svc.AuditEntry{
		ActorID: res.User.ID, ActorEmail: res.User.Email, Action: "auth.login",
		IP: clientIP(r), UserAgent: r.UserAgent(),
	})
	writeJSON(w, http.StatusOK, res)
}

type refreshReq struct {
	Refresh string `json:"refresh_token"`
}

func (h *Handler) refresh(w http.ResponseWriter, r *http.Request) {
	var req refreshReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "bad json")
		return
	}
	res, err := h.Svc.Refresh(r.Context(), req.Refresh)
	if err != nil {
		writeErr(w, http.StatusUnauthorized, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, res)
}

func (h *Handler) logout(w http.ResponseWriter, r *http.Request) {
	var req refreshReq
	_ = json.NewDecoder(r.Body).Decode(&req)
	if req.Refresh != "" {
		_ = h.Svc.Logout(r.Context(), req.Refresh)
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) me(w http.ResponseWriter, r *http.Request) {
	c := r.Context().Value(ctxClaims).(svc.AccessClaims)
	writeJSON(w, 200, map[string]any{
		"id": c.Sub, "email": c.Email, "roles": c.Roles,
	})
}

func (h *Handler) overview(w http.ResponseWriter, r *http.Request) {
	res, err := h.Svc.Overview(r.Context())
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, res)
}

func (h *Handler) volume(w http.ResponseWriter, r *http.Request) {
	days := intQuery(r, "days", 14)
	res, err := h.Svc.VolumeSeries(r.Context(), days)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, res)
}

func (h *Handler) listUsers(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	page := intQuery(r, "page", 1)
	pp := intQuery(r, "per_page", 25)
	res, err := h.Svc.ListUsers(r.Context(), q, page, pp)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, res)
}

func (h *Handler) getUser(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	res, err := h.Svc.GetUser(r.Context(), id)
	if err != nil {
		writeErr(w, 404, err.Error())
		return
	}
	writeJSON(w, 200, res)
}

func (h *Handler) listTransactions(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	res, err := h.Svc.ListTransactions(r.Context(),
		q.Get("state"), q.Get("payer"), q.Get("payee"),
		intQuery(r, "page", 1), intQuery(r, "per_page", 25))
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, res)
}

func (h *Handler) getTransaction(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	res, err := h.Svc.GetTransaction(r.Context(), id)
	if err != nil {
		writeErr(w, 404, err.Error())
		return
	}
	writeJSON(w, 200, res)
}

func (h *Handler) listSettlements(w http.ResponseWriter, r *http.Request) {
	res, err := h.Svc.ListSettlements(r.Context(),
		intQuery(r, "page", 1), intQuery(r, "per_page", 25))
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, res)
}

func (h *Handler) getSettlement(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	res, err := h.Svc.GetSettlement(r.Context(), id)
	if err != nil {
		writeErr(w, 404, err.Error())
		return
	}
	writeJSON(w, 200, res)
}

func (h *Handler) listFraud(w http.ResponseWriter, r *http.Request) {
	res, err := h.Svc.ListFraudSignals(r.Context(),
		intQuery(r, "page", 1), intQuery(r, "per_page", 50))
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, res)
}

func (h *Handler) listAudit(w http.ResponseWriter, r *http.Request) {
	res, err := h.Svc.ListAudit(r.Context(),
		intQuery(r, "page", 1), intQuery(r, "per_page", 50))
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, res)
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func intQuery(r *http.Request, key string, def int) int {
	v := r.URL.Query().Get(key)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return def
	}
	return n
}

func clientIP(r *http.Request) string {
	if xf := r.Header.Get("X-Forwarded-For"); xf != "" {
		if i := strings.IndexByte(xf, ','); i > 0 {
			return strings.TrimSpace(xf[:i])
		}
		return strings.TrimSpace(xf)
	}
	return r.RemoteAddr
}

