package userauth

import (
	"testing"
	"time"
)

func TestLast6(t *testing.T) {
	cases := []struct {
		in, want string
	}{
		{"+2348108678294", "678294"},
		{"123456", "123456"},
		{"12345", "12345"},
		{"", ""},
	}
	for _, tc := range cases {
		if got := last6(tc.in); got != tc.want {
			t.Fatalf("last6(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

func TestNormalizePhone(t *testing.T) {
	cases := []struct {
		name, in, want string
		wantErr        bool
	}{
		{"e164", "+2348108678294", "+2348108678294", false},
		{"national", "08108678294", "+2348108678294", false},
		{"with spaces", "+234 810 867 8294", "+2348108678294", false},
		{"short nigerian", "+234810867829", "", true},
		{"us", "+15551234567", "", true},
		{"empty", "", "", true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := normalizePhone(tc.in)
			if tc.wantErr {
				if err == nil {
					t.Fatalf("want err, got %q", got)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected err: %v", err)
			}
			if got != tc.want {
				t.Fatalf("want %q, got %q", tc.want, got)
			}
		})
	}
}

func TestJWTSignerRoundTrip(t *testing.T) {
	s := JWTSigner{
		Secret:   []byte("test-secret"),
		Audience: "offlinepay-user",
		TTL:      time.Minute,
	}
	tok, err := s.Sign("user_123", "8108678294", "sess_xyz")
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	claims, err := s.Verify(tok)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if claims.Sub != "user_123" || claims.Acc != "8108678294" || claims.Aud != "offlinepay-user" {
		t.Fatalf("unexpected claims: %+v", claims)
	}
	if claims.Sid != "sess_xyz" {
		t.Fatalf("want Sid=sess_xyz, got %q", claims.Sid)
	}
}

func TestJWTSignerRejectsTampered(t *testing.T) {
	s := JWTSigner{Secret: []byte("test-secret"), Audience: "offlinepay-user", TTL: time.Minute}
	tok, _ := s.Sign("u", "a", "s")
	if _, err := s.Verify(tok + "x"); err == nil {
		t.Fatal("expected error on tampered token")
	}
}

func TestJWTSignerExpired(t *testing.T) {
	s := JWTSigner{Secret: []byte("test-secret"), Audience: "offlinepay-user", TTL: -time.Second}
	tok, _ := s.Sign("u", "a", "s")
	if _, err := s.Verify(tok); err != ErrExpired {
		t.Fatalf("want ErrExpired, got %v", err)
	}
}

func TestJWTSignerEmptySidOmitted(t *testing.T) {
	s := JWTSigner{Secret: []byte("test-secret"), Audience: "offlinepay-user", TTL: time.Minute}
	tok, err := s.Sign("u", "a", "")
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	claims, err := s.Verify(tok)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if claims.Sid != "" {
		t.Fatalf("want empty sid, got %q", claims.Sid)
	}
}
