package bff

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/intellect/offlinepay/internal/service/userauth"
)

func TestRateLimitByUser_NoClaims_PassThrough(t *testing.T) {
	lim := NewUserRateLimiter(1, 1)
	defer lim.Stop()

	handler := RateLimitByUser(lim)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	// No claims in context — should pass through without limiting.
	for range 10 {
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, httptest.NewRequest("GET", "/health", nil))
		if rec.Code != http.StatusOK {
			t.Fatalf("expected 200 for keyless request, got %d", rec.Code)
		}
	}
}

func TestRateLimitByUser_WithClaims_RateLimits(t *testing.T) {
	lim := NewUserRateLimiter(1, 2) // burst of 2
	defer lim.Stop()

	ok := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	handler := RateLimitByUser(lim)(ok)

	makeReq := func() *httptest.ResponseRecorder {
		req := httptest.NewRequest("GET", "/v1/me", nil)
		ctx := context.WithValue(req.Context(), ctxClaims, userauth.AccessClaims{Sub: "user-1"})
		req = req.WithContext(ctx)
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		return rec
	}

	// First 2 should pass (burst).
	for i := range 2 {
		rec := makeReq()
		if rec.Code != http.StatusOK {
			t.Fatalf("request %d: expected 200, got %d", i, rec.Code)
		}
	}

	// 3rd should be 429.
	rec := makeReq()
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("expected 429, got %d", rec.Code)
	}
	if rec.Header().Get("Retry-After") != "1" {
		t.Fatalf("expected Retry-After: 1, got %q", rec.Header().Get("Retry-After"))
	}
}
