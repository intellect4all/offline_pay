package domain

import (
	"testing"
	"time"
)

func validPaymentPayload() PaymentPayload {
	nonce := make([]byte, SessionNonceSize)
	for i := range nonce {
		nonce[i] = byte(i + 1)
	}
	hash := make([]byte, 32)
	for i := range hash {
		hash[i] = byte(0xA0 | i)
	}
	return PaymentPayload{
		PayerID:          "user-1",
		PayeeID:          "merchant-1",
		Amount:           5_000,
		SequenceNumber:   1,
		RemainingCeiling: 95_000,
		Timestamp:        time.Now(),
		CeilingTokenID:   "ceiling-1",
		SessionNonce:     nonce,
		RequestHash:      hash,
	}
}

func TestPaymentPayload_Validate_Happy(t *testing.T) {
	if err := validPaymentPayload().Validate(); err != nil {
		t.Fatalf("expected valid, got %v", err)
	}
}

func TestPaymentPayload_Validate_Errors(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(*PaymentPayload)
	}{
		{"missing payer_id", func(p *PaymentPayload) { p.PayerID = "" }},
		{"missing payee_id", func(p *PaymentPayload) { p.PayeeID = "" }},
		{"payer == payee", func(p *PaymentPayload) { p.PayeeID = p.PayerID }},
		{"zero amount", func(p *PaymentPayload) { p.Amount = 0 }},
		{"negative amount", func(p *PaymentPayload) { p.Amount = -1 }},
		{"zero sequence", func(p *PaymentPayload) { p.SequenceNumber = 0 }},
		{"negative remaining", func(p *PaymentPayload) { p.RemainingCeiling = -1 }},
		{"zero timestamp", func(p *PaymentPayload) { p.Timestamp = time.Time{} }},
		{"missing ceiling id", func(p *PaymentPayload) { p.CeilingTokenID = "" }},
		{"short session nonce", func(p *PaymentPayload) { p.SessionNonce = []byte{1, 2, 3} }},
		{"missing request hash", func(p *PaymentPayload) { p.RequestHash = nil }},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p := validPaymentPayload()
			c.mutate(&p)
			if err := p.Validate(); err == nil {
				t.Fatalf("expected error for %s, got nil", c.name)
			}
		})
	}
}
