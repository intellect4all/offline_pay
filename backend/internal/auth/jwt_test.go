package auth

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"strings"
	"testing"
	"time"
)

func TestSignParseVerify_RoundTrip(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("genkey: %v", err)
	}
	now := time.Unix(1_700_000_000, 0)
	claims := Claims{
		Sub: "user-1",
		Did: "device-a",
		Iat: now.Unix(),
		Exp: now.Add(15 * time.Minute).Unix(),
		Aud: "offlinepay",
	}
	tok, err := Sign(priv, claims)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	parsed, err := Parse(tok)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if parsed.Header.Kid != "device-a" {
		t.Errorf("kid = %q, want device-a", parsed.Header.Kid)
	}
	if err := parsed.Verify(pub, "offlinepay", now.Add(time.Minute), time.Minute); err != nil {
		t.Errorf("verify: %v", err)
	}
}

func TestVerify_Expired(t *testing.T) {
	pub, priv, _ := ed25519.GenerateKey(rand.Reader)
	now := time.Unix(1_700_000_000, 0)
	tok, _ := Sign(priv, Claims{
		Sub: "u", Did: "d", Iat: now.Unix(), Exp: now.Add(time.Minute).Unix(), Aud: "offlinepay",
	})
	parsed, _ := Parse(tok)
	err := parsed.Verify(pub, "offlinepay", now.Add(10*time.Minute), time.Second)
	if !errors.Is(err, ErrExpired) {
		t.Errorf("err = %v, want ErrExpired", err)
	}
}

func TestVerify_WrongAudience(t *testing.T) {
	pub, priv, _ := ed25519.GenerateKey(rand.Reader)
	now := time.Unix(1_700_000_000, 0)
	tok, _ := Sign(priv, Claims{
		Sub: "u", Did: "d", Iat: now.Unix(), Exp: now.Add(time.Minute).Unix(), Aud: "wrong",
	})
	parsed, _ := Parse(tok)
	err := parsed.Verify(pub, "offlinepay", now, time.Second)
	if !errors.Is(err, ErrWrongAudience) {
		t.Errorf("err = %v, want ErrWrongAudience", err)
	}
}

func TestVerify_BadSignature_WrongKey(t *testing.T) {
	_, priv, _ := ed25519.GenerateKey(rand.Reader)
	now := time.Unix(1_700_000_000, 0)
	tok, _ := Sign(priv, Claims{
		Sub: "u", Did: "d", Iat: now.Unix(), Exp: now.Add(time.Minute).Unix(), Aud: "offlinepay",
	})
	parsed, _ := Parse(tok)
	otherPub, _, _ := ed25519.GenerateKey(rand.Reader)
	err := parsed.Verify(otherPub, "offlinepay", now, time.Second)
	if !errors.Is(err, ErrBadSignature) {
		t.Errorf("err = %v, want ErrBadSignature", err)
	}
}

func TestParse_Malformed(t *testing.T) {
	for _, in := range []string{"", "a.b", "a.b.c.d", "!.!.!"} {
		if _, err := Parse(in); !errors.Is(err, ErrMalformed) {
			t.Errorf("Parse(%q) err = %v, want ErrMalformed", in, err)
		}
	}
}

func TestParse_UnknownAlg(t *testing.T) {
	// Build a token with a non-EdDSA alg header.
	parts := []string{
		base64url(`{"alg":"HS256","typ":"JWT","kid":"d"}`),
		base64url(`{"sub":"u","did":"d","iat":1,"exp":2,"aud":"offlinepay"}`),
		base64url("xx"),
	}
	tok := strings.Join(parts, ".")
	if _, err := Parse(tok); !errors.Is(err, ErrUnknownAlg) {
		t.Errorf("err = %v, want ErrUnknownAlg", err)
	}
}

// base64url keeps tests terse.
func base64url(s string) string {
	return base64.RawURLEncoding.EncodeToString([]byte(s))
}
