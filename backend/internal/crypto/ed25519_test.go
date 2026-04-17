package crypto

import (
	"testing"
	"time"

	"github.com/intellect/offlinepay/internal/domain"
)

func samplePayment(t *testing.T) domain.PaymentPayload {
	t.Helper()
	nonce := make([]byte, domain.SessionNonceSize)
	for i := range nonce {
		nonce[i] = byte(i + 1)
	}
	hash := make([]byte, 32)
	for i := range hash {
		hash[i] = byte(0xB0 | i)
	}
	return domain.PaymentPayload{
		PayerID:          "user_alice",
		PayeeID:          "user_bob",
		Amount:           250000,
		SequenceNumber:   1,
		RemainingCeiling: 750000,
		Timestamp:        time.Date(2026, 4, 13, 10, 0, 0, 0, time.UTC),
		CeilingTokenID:   "ct_1",
		SessionNonce:     nonce,
		RequestHash:      hash,
	}
}

func sampleCeiling(t *testing.T, payerPub []byte) domain.CeilingTokenPayload {
	t.Helper()
	return domain.CeilingTokenPayload{
		PayerID:        "user_alice",
		CeilingAmount:  1000000,
		IssuedAt:       time.Date(2026, 4, 13, 9, 0, 0, 0, time.UTC),
		ExpiresAt:      time.Date(2026, 4, 14, 9, 0, 0, 0, time.UTC),
		SequenceStart:  0,
		PayerPublicKey: payerPub,
		BankKeyID:      "bank_key_1",
	}
}

func TestPaymentRoundTrip(t *testing.T) {
	kp, err := GenerateKeyPair()
	if err != nil {
		t.Fatal(err)
	}
	p := samplePayment(t)
	sig, err := SignPayment(kp.PrivateKey, p)
	if err != nil {
		t.Fatal(err)
	}
	if err := VerifyPayment(kp.PublicKey, p, sig); err != nil {
		t.Fatalf("verify: %v", err)
	}
}

func TestPaymentTamperDetected(t *testing.T) {
	kp, _ := GenerateKeyPair()
	p := samplePayment(t)
	sig, _ := SignPayment(kp.PrivateKey, p)
	p.Amount = p.Amount + 1
	if err := VerifyPayment(kp.PublicKey, p, sig); err == nil {
		t.Fatal("expected tamper detection")
	}
}

func TestCeilingRoundTrip(t *testing.T) {
	bank, _ := GenerateKeyPair()
	payer, _ := GenerateKeyPair()
	p := sampleCeiling(t, payer.PublicKey)
	sig, err := SignCeiling(bank.PrivateKey, p)
	if err != nil {
		t.Fatal(err)
	}
	if err := VerifyCeiling(bank.PublicKey, p, sig); err != nil {
		t.Fatalf("verify: %v", err)
	}
}

func TestCeilingTamperDetected(t *testing.T) {
	bank, _ := GenerateKeyPair()
	payer, _ := GenerateKeyPair()
	p := sampleCeiling(t, payer.PublicKey)
	sig, _ := SignCeiling(bank.PrivateKey, p)
	p.CeilingAmount = p.CeilingAmount + 1
	if err := VerifyCeiling(bank.PublicKey, p, sig); err == nil {
		t.Fatal("expected tamper detection")
	}
}

func TestVerifyRejectsWrongKey(t *testing.T) {
	bank1, _ := GenerateKeyPair()
	bank2, _ := GenerateKeyPair()
	payer, _ := GenerateKeyPair()
	p := sampleCeiling(t, payer.PublicKey)
	sig, _ := SignCeiling(bank1.PrivateKey, p)
	if err := VerifyCeiling(bank2.PublicKey, p, sig); err == nil {
		t.Fatal("expected verify failure with wrong bank key")
	}
}
