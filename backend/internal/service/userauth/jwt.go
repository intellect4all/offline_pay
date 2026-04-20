// Package userauth implements phone + OTP authentication for end-user
// mobile clients: signup, login, refresh, logout. Access tokens are
// short-lived HMAC-SHA256 JWTs; refresh tokens are opaque random strings
// persisted (hashed) in user_sessions and rotated on use.
package userauth

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
	ErrInvalidToken = errors.New("userauth: invalid token")
	ErrExpired      = errors.New("userauth: token expired")
)

// AccessClaims is what sits in the short-lived access JWT. The Sid claim
// binds an access token to the user_sessions row that issued it so callers
// (e.g. session-management endpoints) can reason about "the current
// session" without consulting the refresh token.
type AccessClaims struct {
	Sub string `json:"sub"`
	Acc string `json:"acc"`
	Sid string `json:"sid,omitempty"`
	Iat int64  `json:"iat"`
	Exp int64  `json:"exp"`
	Aud string `json:"aud"`
}

// JWTSigner signs + verifies HMAC-SHA256 access tokens.
type JWTSigner struct {
	Secret   []byte
	Audience string
	TTL      time.Duration
}

// Sign mints an access JWT. sid is the user_sessions.id the token is bound
// to (empty string is tolerated for legacy callers and tests).
func (s JWTSigner) Sign(sub, accountNumber, sid string) (string, error) {
	now := time.Now().UTC()
	c := AccessClaims{
		Sub: sub, Acc: accountNumber, Sid: sid,
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
		return zero, fmt.Errorf("userauth: wrong audience")
	}
	return c, nil
}

func b64(b []byte) string           { return base64.RawURLEncoding.EncodeToString(b) }
func b64d(s string) ([]byte, error) { return base64.RawURLEncoding.DecodeString(s) }
