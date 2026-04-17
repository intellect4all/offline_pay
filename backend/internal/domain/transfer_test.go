package domain

import (
	"errors"
	"strings"
	"testing"
)

func TestValidateAmount(t *testing.T) {
	cases := []struct {
		name    string
		in      int64
		wantErr error
	}{
		{"zero", 0, ErrInvalidAmount},
		{"negative", -1, ErrInvalidAmount},
		{"one kobo", 1, nil},
		{"normal", 5000_00, nil},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := ValidateAmount(tc.in)
			if !errors.Is(err, tc.wantErr) {
				t.Fatalf("got %v want %v", err, tc.wantErr)
			}
		})
	}
}

func TestValidateReference(t *testing.T) {
	cases := []struct {
		name    string
		in      string
		wantErr error
	}{
		{"empty", "", ErrInvalidReference},
		{"short", "a", nil},
		{"at-limit", strings.Repeat("x", 64), nil},
		{"too-long", strings.Repeat("x", 65), ErrInvalidReference},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := ValidateReference(tc.in)
			if !errors.Is(err, tc.wantErr) {
				t.Fatalf("got %v want %v", err, tc.wantErr)
			}
		})
	}
}

func TestValidateAccountNumber(t *testing.T) {
	cases := []struct {
		name    string
		in      string
		wantErr error
	}{
		{"exact-10", "8012345678", nil},
		{"9-digits", "801234567", ErrInvalidAccountNumber},
		{"11-digits", "80123456789", ErrInvalidAccountNumber},
		{"non-digits", "80123abcde", ErrInvalidAccountNumber},
		{"empty", "", ErrInvalidAccountNumber},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := ValidateAccountNumber(tc.in)
			if !errors.Is(err, tc.wantErr) {
				t.Fatalf("got %v want %v", err, tc.wantErr)
			}
		})
	}
}
