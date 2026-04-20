// Package admin implements the backoffice admin-api service: authentication,
// RBAC, audit logging, and read/write handlers for the internal dashboard.
//
// Admin auth is separate from device-bound JWTs used by mobile clients:
// here we use email+password with bcrypt, issuing short-lived HMAC-SHA256
// access tokens and long-lived opaque refresh tokens persisted in
// admin_sessions.
package admin

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
)

var (
	ErrInvalidToken = errors.New("admin: invalid token")
	ErrExpired      = errors.New("admin: token expired")
)

// AccessClaims is what sits in the short-lived access JWT.
type AccessClaims struct {
	Sub   string   `json:"sub"`
	Email string   `json:"email"`
	Roles []string `json:"roles"`
	Iat   int64    `json:"iat"`
	Exp   int64    `json:"exp"`
	Aud   string   `json:"aud"`
}

// JWTSigner signs + verifies HMAC-SHA256 access tokens.
type JWTSigner struct {
	Secret   []byte
	Audience string
	TTL      time.Duration
}

func (s JWTSigner) Sign(sub, email string, roles []string) (string, error) {
	now := time.Now().UTC()
	c := AccessClaims{
		Sub: sub, Email: email, Roles: roles,
		Iat: now.Unix(), Exp: now.Add(s.TTL).Unix(), Aud: s.Audience,
	}
	header := map[string]string{"alg": "HS256", "typ": "JWT"}
	hb, _ := json.Marshal(header)
	cb, _ := json.Marshal(c)
	signingInput := b64(hb) + "." + b64(cb)
	mac := hmac.New(sha256.New, s.Secret)
	mac.Write([]byte(signingInput))
	sig := mac.Sum(nil)
	return signingInput + "." + b64(sig), nil
}

func (s JWTSigner) Verify(tok string) (AccessClaims, error) {
	var zero AccessClaims
	parts := strings.Split(tok, ".")
	if len(parts) != 3 {
		return zero, ErrInvalidToken
	}
	mac := hmac.New(sha256.New, s.Secret)
	mac.Write([]byte(parts[0] + "." + parts[1]))
	expected := mac.Sum(nil)
	got, err := b64d(parts[2])
	if err != nil {
		return zero, ErrInvalidToken
	}
	if !hmac.Equal(expected, got) {
		return zero, ErrInvalidToken
	}
	cb, err := b64d(parts[1])
	if err != nil {
		return zero, ErrInvalidToken
	}
	var c AccessClaims
	if err := json.Unmarshal(cb, &c); err != nil {
		return zero, ErrInvalidToken
	}
	now := time.Now().UTC().Unix()
	if c.Exp != 0 && now > c.Exp {
		return zero, ErrExpired
	}
	if s.Audience != "" && c.Aud != s.Audience {
		return zero, fmt.Errorf("admin: wrong audience")
	}
	return c, nil
}

func b64(b []byte) string  { return base64.RawURLEncoding.EncodeToString(b) }
func b64d(s string) ([]byte, error) { return base64.RawURLEncoding.DecodeString(s) }
