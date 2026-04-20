package admin

import (
	"testing"
	"time"
)

func TestJWTSignerRoundTrip(t *testing.T) {
	s := JWTSigner{Secret: []byte("0123456789abcdef0123456789abcdef"), Audience: "admin", TTL: time.Minute}
	tok, err := s.Sign("id1", "me@x.io", []string{"SUPERADMIN"})
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	c, err := s.Verify(tok)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if c.Sub != "id1" || c.Email != "me@x.io" || len(c.Roles) != 1 || c.Roles[0] != "SUPERADMIN" {
		t.Fatalf("unexpected claims: %+v", c)
	}
}

func TestJWTSignerTampered(t *testing.T) {
	s := JWTSigner{Secret: []byte("0123456789abcdef0123456789abcdef"), Audience: "admin", TTL: time.Minute}
	tok, _ := s.Sign("id1", "me@x.io", nil)
	if _, err := s.Verify(tok + "x"); err == nil {
		t.Fatal("expected error for tampered token")
	}
}

func TestJWTSignerExpired(t *testing.T) {
	s := JWTSigner{Secret: []byte("0123456789abcdef0123456789abcdef"), Audience: "admin", TTL: -time.Minute}
	tok, _ := s.Sign("id1", "me@x.io", nil)
	if _, err := s.Verify(tok); err != ErrExpired {
		t.Fatalf("expected ErrExpired, got %v", err)
	}
}
