package auth

import (
	"crypto/ed25519"
	"crypto/rand"
	"errors"
	"strings"
	"testing"
	"time"
)

func freshKeys(t *testing.T) (ed25519.PublicKey, ed25519.PrivateKey) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("ed25519 gen: %v", err)
	}
	return pub, priv
}

func defaultClaims() DeviceSessionClaims {
	now := time.Date(2026, 4, 20, 12, 0, 0, 0, time.UTC)
	return DeviceSessionClaims{
		Sub:           "u_alice",
		AccountNumber: "8108678294",
		DeviceID:      "d_galaxy",
		Scope:         ScopeOfflinePay,
		Iat:           now.Unix(),
		Exp:           now.Add(14 * 24 * time.Hour).Unix(),
		Aud:           "offlinepay-bff",
	}
}

func TestSignAndVerifyHappyPath(t *testing.T) {
	pub, priv := freshKeys(t)
	tok, err := SignDeviceSession(priv, "kid-1", defaultClaims())
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	if strings.Count(tok, ".") != 2 {
		t.Fatalf("expected JWT-shaped token, got %q", tok)
	}
	parsed, err := ParseDeviceSession(tok)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	now := time.Date(2026, 4, 21, 0, 0, 0, 0, time.UTC)
	if err := parsed.Verify(pub, "offlinepay-bff", "d_galaxy", now, time.Minute); err != nil {
		t.Fatalf("verify: %v", err)
	}
	if parsed.Claims.Sub != "u_alice" || parsed.Header.Kid != "kid-1" {
		t.Fatalf("unexpected claims: %+v / kid=%q", parsed.Claims, parsed.Header.Kid)
	}
}

func TestVerifyRejectsBadSignature(t *testing.T) {
	pub, priv := freshKeys(t)
	otherPub, _ := freshKeys(t)
	tok, err := SignDeviceSession(priv, "kid-1", defaultClaims())
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	parsed, _ := ParseDeviceSession(tok)
	now := time.Date(2026, 4, 21, 0, 0, 0, 0, time.UTC)

	// Verifying against the wrong pubkey must fail.
	if err := parsed.Verify(otherPub, "offlinepay-bff", "d_galaxy", now, time.Minute); !errors.Is(err, ErrDSBadSignature) {
		t.Fatalf("expected ErrDSBadSignature, got %v", err)
	}

	// Tampered claims shouldn't verify against the original pubkey either.
	// Re-sign with a different private key to keep the JSON well-formed
	// and the b64 segments well-padded; the only thing changing is the
	// signing material, so the original pubkey must reject.
	_, otherPriv := freshKeys(t)
	tampered, err := SignDeviceSession(otherPriv, "kid-1", defaultClaims())
	if err != nil {
		t.Fatalf("re-sign tampered: %v", err)
	}
	tparsed, err := ParseDeviceSession(tampered)
	if err != nil {
		t.Fatalf("parse tampered: %v", err)
	}
	if err := tparsed.Verify(pub, "offlinepay-bff", "d_galaxy", now, time.Minute); !errors.Is(err, ErrDSBadSignature) {
		t.Fatalf("expected tampered token to fail signature, got %v", err)
	}
}

func TestVerifyExpiry(t *testing.T) {
	pub, priv := freshKeys(t)
	c := defaultClaims()
	c.Exp = time.Date(2026, 4, 19, 0, 0, 0, 0, time.UTC).Unix()
	tok, _ := SignDeviceSession(priv, "kid-1", c)
	parsed, _ := ParseDeviceSession(tok)
	now := time.Date(2026, 4, 22, 0, 0, 0, 0, time.UTC)
	if err := parsed.Verify(pub, "offlinepay-bff", "d_galaxy", now, time.Minute); !errors.Is(err, ErrDSExpired) {
		t.Fatalf("expected ErrDSExpired, got %v", err)
	}
	// 30-minute grace window absorbs a fresh expiry.
	c.Exp = now.Add(-10 * time.Minute).Unix()
	tok2, _ := SignDeviceSession(priv, "kid-1", c)
	p2, _ := ParseDeviceSession(tok2)
	if err := p2.Verify(pub, "offlinepay-bff", "d_galaxy", now, 30*time.Minute); err != nil {
		t.Fatalf("expected fresh-expiry to be tolerated within grace, got %v", err)
	}
}

func TestVerifyDeviceBinding(t *testing.T) {
	pub, priv := freshKeys(t)
	tok, _ := SignDeviceSession(priv, "kid-1", defaultClaims())
	parsed, _ := ParseDeviceSession(tok)
	now := time.Date(2026, 4, 21, 0, 0, 0, 0, time.UTC)
	if err := parsed.Verify(pub, "offlinepay-bff", "d_other", now, time.Minute); !errors.Is(err, ErrDSWrongDevice) {
		t.Fatalf("expected ErrDSWrongDevice, got %v", err)
	}
}

func TestVerifyScopeAndAudience(t *testing.T) {
	pub, priv := freshKeys(t)
	c := defaultClaims()
	c.Scope = "view_history"
	tok, _ := SignDeviceSession(priv, "kid-1", c)
	parsed, _ := ParseDeviceSession(tok)
	now := time.Date(2026, 4, 21, 0, 0, 0, 0, time.UTC)
	if err := parsed.Verify(pub, "offlinepay-bff", "d_galaxy", now, time.Minute); !errors.Is(err, ErrDSWrongScope) {
		t.Fatalf("expected ErrDSWrongScope, got %v", err)
	}

	c.Scope = ScopeOfflinePay
	c.Aud = "wrong-audience"
	tok, _ = SignDeviceSession(priv, "kid-1", c)
	parsed, _ = ParseDeviceSession(tok)
	if err := parsed.Verify(pub, "offlinepay-bff", "d_galaxy", now, time.Minute); !errors.Is(err, ErrDSWrongAud) {
		t.Fatalf("expected ErrDSWrongAud, got %v", err)
	}
}

func TestParseRejectsMalformed(t *testing.T) {
	cases := []string{
		"",
		"only.two",
		"!!!.@@@.###",
		"aaa.bbb",
	}
	for _, c := range cases {
		if _, err := ParseDeviceSession(c); !errors.Is(err, ErrDSMalformed) {
			t.Fatalf("expected ErrDSMalformed for %q, got %v", c, err)
		}
	}
}
