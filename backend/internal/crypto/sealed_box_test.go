package crypto

import (
	"bytes"
	"testing"
)

func TestSealedBoxRoundTrip(t *testing.T) {
	pub, priv, err := GenerateSealedBoxKeyPair()
	if err != nil {
		t.Fatal(err)
	}
	msg := []byte("secret transaction blob")
	ct, err := SealAnonymous(pub, msg)
	if err != nil {
		t.Fatal(err)
	}
	if len(ct) != len(msg)+SealedBoxOverhead {
		t.Fatalf("overhead mismatch: got %d want %d", len(ct)-len(msg), SealedBoxOverhead)
	}
	pt, err := OpenAnonymous(pub, priv, ct)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(pt, msg) {
		t.Fatalf("plaintext mismatch: got %q want %q", pt, msg)
	}
}

func TestSealedBoxWrongRecipient(t *testing.T) {
	pub1, _, _ := GenerateSealedBoxKeyPair()
	pub2, priv2, _ := GenerateSealedBoxKeyPair()
	ct, _ := SealAnonymous(pub1, []byte("hi"))
	if _, err := OpenAnonymous(pub2, priv2, ct); err == nil {
		t.Fatal("expected decrypt failure with wrong recipient")
	}
}

func TestSealedBoxTamper(t *testing.T) {
	pub, priv, _ := GenerateSealedBoxKeyPair()
	ct, _ := SealAnonymous(pub, []byte("hi"))
	ct[len(ct)-1] ^= 0xff
	if _, err := OpenAnonymous(pub, priv, ct); err == nil {
		t.Fatal("expected tamper detection")
	}
}

func TestSealedBoxShortCiphertext(t *testing.T) {
	pub, priv, _ := GenerateSealedBoxKeyPair()
	if _, err := OpenAnonymous(pub, priv, []byte("too short")); err == nil {
		t.Fatal("expected error on short ciphertext")
	}
}

func TestSealedBoxFreshEphemeral(t *testing.T) {
	// Sealing the same plaintext twice must produce different ciphertexts
	// because of the fresh ephemeral keypair per call.
	pub, _, _ := GenerateSealedBoxKeyPair()
	a, _ := SealAnonymous(pub, []byte("same"))
	b, _ := SealAnonymous(pub, []byte("same"))
	if bytes.Equal(a, b) {
		t.Fatal("expected different ciphertexts with fresh ephemeral keypairs")
	}
}
