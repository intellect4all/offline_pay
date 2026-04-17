package crypto

import (
	"bytes"
	"testing"
)

func TestAESGCMRoundTrip(t *testing.T) {
	key, _ := NewRandomRealmKey()
	nonce, _ := NewRandomBaseNonce()
	ad := []byte("v1")
	pt := []byte("hello world")
	ct, err := Seal(key, nonce, pt, ad)
	if err != nil {
		t.Fatal(err)
	}
	got, err := Open(key, nonce, ct, ad)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, pt) {
		t.Fatalf("got %q, want %q", got, pt)
	}
}

func TestAESGCMTamperFails(t *testing.T) {
	key, _ := NewRandomRealmKey()
	nonce, _ := NewRandomBaseNonce()
	ct, _ := Seal(key, nonce, []byte("data"), nil)
	ct[0] ^= 0xff
	if _, err := Open(key, nonce, ct, nil); err == nil {
		t.Fatal("expected tamper detection")
	}
}

func TestAESGCMWrongADFails(t *testing.T) {
	key, _ := NewRandomRealmKey()
	nonce, _ := NewRandomBaseNonce()
	ct, _ := Seal(key, nonce, []byte("data"), []byte("v1"))
	if _, err := Open(key, nonce, ct, []byte("v2")); err == nil {
		t.Fatal("expected auth failure with wrong AD")
	}
}

func TestDeriveFrameNonceUnique(t *testing.T) {
	base, _ := NewRandomBaseNonce()
	n0, _ := DeriveFrameNonce(base, 0)
	n1, _ := DeriveFrameNonce(base, 1)
	if bytes.Equal(n0, n1) {
		t.Fatal("frame nonces collided")
	}
	// Deriving the same frame index twice must be deterministic.
	n0b, _ := DeriveFrameNonce(base, 0)
	if !bytes.Equal(n0, n0b) {
		t.Fatal("frame nonce derivation not deterministic")
	}
}

func TestBadKey(t *testing.T) {
	if _, err := Seal(make([]byte, 16), make([]byte, 12), nil, nil); err == nil {
		t.Fatal("expected ErrBadKey")
	}
}
