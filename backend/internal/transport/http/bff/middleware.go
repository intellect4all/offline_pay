package bff

import (
	"context"
	"net/http"
	"strings"

	"github.com/intellect/offlinepay/internal/service/userauth"
	"github.com/intellect/offlinepay/internal/transport/grpc/server"
)

type ctxKey int

const (
	ctxClaims ctxKey = iota + 1
	ctxUserAgent
	ctxClientIP
)

// submitterCountryHeader is the HTTP header clients use to report their
// current country (ISO-3166 alpha-2) when submitting a settlement claim
// batch. The BFF forwards it as the matching gRPC metadata key so the
// settlement service can feed the geographic-anomaly detector.
const submitterCountryHeader = "X-Submitter-Country"

// RequireUserJWT extracts and verifies a bearer access token. On success the
// AccessClaims are stashed in the request context via ClaimsFromContext.
func RequireUserJWT(signer userauth.JWTSigner) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			tok := bearerToken(r)
			if tok == "" {
				writeJSONErr(w, http.StatusUnauthorized, "unauthorized", "missing bearer token")
				return
			}
			claims, err := signer.Verify(tok)
			if err != nil {
				writeJSONErr(w, http.StatusUnauthorized, "unauthorized", err.Error())
				return
			}
			ctx := context.WithValue(r.Context(), ctxClaims, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// ClaimsFromContext retrieves the AccessClaims stored by RequireUserJWT.
func ClaimsFromContext(ctx context.Context) (userauth.AccessClaims, bool) {
	c, ok := ctx.Value(ctxClaims).(userauth.AccessClaims)
	return c, ok
}

// RequestMetadata captures the User-Agent, client IP, and optional
// X-Submitter-Country header on every incoming request so strict-server
// handlers (which only receive ctx) can pull them out for session rows or
// forward them upstream.
func RequestMetadata(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := context.WithValue(r.Context(), ctxUserAgent, r.UserAgent())
		ctx = context.WithValue(ctx, ctxClientIP, clientIP(r))
		if c := r.Header.Get(submitterCountryHeader); strings.TrimSpace(c) != "" {
			ctx = server.WithSubmitterCountry(ctx, c)
		}
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// SubmitterCountryFromContext returns the ISO-3166 alpha-2 country code
// reported by the client on this request, or "" when none was supplied.
func SubmitterCountryFromContext(ctx context.Context) string {
	return server.SubmitterCountryFromContext(ctx)
}

func userAgentFromContext(ctx context.Context) string {
	v, _ := ctx.Value(ctxUserAgent).(string)
	return v
}

func clientIPFromContext(ctx context.Context) string {
	v, _ := ctx.Value(ctxClientIP).(string)
	return v
}

func bearerToken(r *http.Request) string {
	h := r.Header.Get("Authorization")
	if strings.HasPrefix(h, "Bearer ") {
		return strings.TrimPrefix(h, "Bearer ")
	}
	return ""
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
