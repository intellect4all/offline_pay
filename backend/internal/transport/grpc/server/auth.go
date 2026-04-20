package server

import (
	"context"
	"strings"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// AuthUser is the authenticated principal. Populated by the HTTP JWT
// middleware in the BFF and read by in-process handler methods via
// MustAuthUser / MustMatchUser.
type AuthUser struct {
	UserID   string
	DeviceID string
}

type authCtxKey struct{}
type submitterCountryCtxKey struct{}

// WithAuthUser stashes an AuthUser in ctx. The BFF calls this before
// dispatching to a server handler method so the handler's auth guards
// resolve without a gRPC interceptor.
func WithAuthUser(ctx context.Context, u AuthUser) context.Context {
	return context.WithValue(ctx, authCtxKey{}, u)
}

func authUserFromContext(ctx context.Context) (AuthUser, bool) {
	u, ok := ctx.Value(authCtxKey{}).(AuthUser)
	return u, ok
}

// MustAuthUser returns the authenticated user or an Unauthenticated status.
func MustAuthUser(ctx context.Context) (AuthUser, error) {
	u, ok := authUserFromContext(ctx)
	if !ok {
		return AuthUser{}, status.Error(codes.Unauthenticated, "missing auth context")
	}
	return u, nil
}

// MustMatchUser asserts the authenticated user matches the request's user id.
func MustMatchUser(ctx context.Context, requestUserID string) (AuthUser, error) {
	u, err := MustAuthUser(ctx)
	if err != nil {
		return AuthUser{}, err
	}
	if requestUserID != "" && requestUserID != u.UserID {
		return AuthUser{}, status.Error(codes.PermissionDenied, "auth user does not match request user")
	}
	return u, nil
}

// WithSubmitterCountry stashes the ISO-3166 alpha-2 country the client
// reported at claim-upload time. Read by the settlement handler to feed
// the fraud detector's geographic-anomaly signal.
func WithSubmitterCountry(ctx context.Context, country string) context.Context {
	c := strings.ToUpper(strings.TrimSpace(country))
	if c == "" {
		return ctx
	}
	return context.WithValue(ctx, submitterCountryCtxKey{}, c)
}

// SubmitterCountryFromContext returns the country stored by
// WithSubmitterCountry, or "" when none was supplied.
func SubmitterCountryFromContext(ctx context.Context) string {
	v, _ := ctx.Value(submitterCountryCtxKey{}).(string)
	return v
}
