package bff

import (
	"net/http"
)

// RateLimitByUser returns middleware that enforces per-user rate
// limiting using the provided UserLimiter implementation. It reads the
// user identity from the JWT claims stored in context by RequireUserJWT.
// If no claims are present (keyless/anonymous path), the request is
// passed through — Tyk's global IP-based limit covers anonymous abuse.
//
// On rejection the response is 429 Too Many Requests with a Retry-After
// header.
func RateLimitByUser(limiter UserLimiter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := ClaimsFromContext(r.Context())
			if !ok {
				// No authenticated user — skip per-user limiting.
				next.ServeHTTP(w, r)
				return
			}

			if !limiter.Allow(claims.Sub) {
				w.Header().Set("Retry-After", "1")
				writeJSONErr(w, http.StatusTooManyRequests, "rate_limited", "Too many requests. Please wait and try again.")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
