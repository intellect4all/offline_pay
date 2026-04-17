package domain

import (
	"testing"
	"time"
)

func validCeilingPayload() CeilingTokenPayload {
	issued := time.Now()
	return CeilingTokenPayload{
		PayerID:        "user-1",
		CeilingAmount:  100_000,
		IssuedAt:       issued,
		ExpiresAt:      issued.Add(24 * time.Hour),
		SequenceStart:  1,
		PayerPublicKey: []byte{0x01, 0x02, 0x03},
		BankKeyID:      "bank-key-2026-01",
	}
}

func TestCeilingTokenPayload_Validate_Happy(t *testing.T) {
	if err := validCeilingPayload().Validate(); err != nil {
		t.Fatalf("expected valid, got %v", err)
	}
}

func TestCeilingTokenPayload_Validate_Errors(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(*CeilingTokenPayload)
	}{
		{"missing payer_id", func(p *CeilingTokenPayload) { p.PayerID = "" }},
		{"zero amount", func(p *CeilingTokenPayload) { p.CeilingAmount = 0 }},
		{"negative amount", func(p *CeilingTokenPayload) { p.CeilingAmount = -1 }},
		{"zero issued_at", func(p *CeilingTokenPayload) { p.IssuedAt = time.Time{} }},
		{"zero expires_at", func(p *CeilingTokenPayload) { p.ExpiresAt = time.Time{} }},
		{"expires before issued", func(p *CeilingTokenPayload) { p.ExpiresAt = p.IssuedAt.Add(-time.Hour) }},
		{"negative sequence_start", func(p *CeilingTokenPayload) { p.SequenceStart = -1 }},
		{"empty public_key", func(p *CeilingTokenPayload) { p.PayerPublicKey = nil }},
		{"empty bank_key_id", func(p *CeilingTokenPayload) { p.BankKeyID = "" }},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p := validCeilingPayload()
			c.mutate(&p)
			if err := p.Validate(); err == nil {
				t.Fatalf("expected error for %s, got nil", c.name)
			}
		})
	}
}
