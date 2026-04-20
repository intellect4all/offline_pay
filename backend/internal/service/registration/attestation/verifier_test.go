package attestation

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"
)

func TestDevVerifier_HappyPath(t *testing.T) {
	store := NewMemoryNonceStore()
	v := NewDevVerifier(store)
	v.Now = func() time.Time { return time.Date(2026, 4, 14, 0, 0, 0, 0, time.UTC) }

	pub := []byte{0x01, 0x02, 0x03, 0x04}
	nonce, err := store.Issue(context.Background(), "user-1", time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	blob, _ := json.Marshal(DevBlob{Platform: "dev", DevicePublicKey: pub, Nonce: nonce})

	att, err := v.Verify(context.Background(), PlatformDev, blob, pub, nonce)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if att.Platform != PlatformDev {
		t.Fatalf("platform = %s", att.Platform)
	}
}

func TestDevVerifier_RejectsPubKeyMismatch(t *testing.T) {
	v := NewDevVerifier(nil)
	blob, _ := json.Marshal(DevBlob{DevicePublicKey: []byte{1}, Nonce: []byte{2}})
	_, err := v.Verify(context.Background(), PlatformDev, blob, []byte{9}, []byte{2})
	if !errors.Is(err, ErrAttestationFailed) {
		t.Fatalf("err = %v, want ErrAttestationFailed", err)
	}
}

func TestDevVerifier_RejectsNonceMismatch(t *testing.T) {
	v := NewDevVerifier(nil)
	blob, _ := json.Marshal(DevBlob{DevicePublicKey: []byte{1}, Nonce: []byte{2}})
	_, err := v.Verify(context.Background(), PlatformDev, blob, []byte{1}, []byte{9})
	if !errors.Is(err, ErrNonceMismatch) {
		t.Fatalf("err = %v, want ErrNonceMismatch", err)
	}
}

func TestMemoryNonceStore_ConsumeOnce(t *testing.T) {
	s := NewMemoryNonceStore()
	ctx := context.Background()
	n, err := s.Issue(ctx, "u", time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	if err := s.Consume(ctx, "u", n); err != nil {
		t.Fatalf("first consume: %v", err)
	}
	if err := s.Consume(ctx, "u", n); !errors.Is(err, ErrNonceMismatch) {
		t.Fatalf("second consume err = %v, want ErrNonceMismatch", err)
	}
}

func TestMemoryNonceStore_Expires(t *testing.T) {
	s := NewMemoryNonceStore()
	// pin clock so we can step past the TTL.
	ts := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	s.now = func() time.Time { return ts }
	n, err := s.Issue(context.Background(), "u", time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	ts = ts.Add(2 * time.Minute)
	if err := s.Consume(context.Background(), "u", n); !errors.Is(err, ErrNonceMismatch) {
		t.Fatalf("err = %v, want ErrNonceMismatch after TTL", err)
	}
}

func TestComposite_UnknownPlatform(t *testing.T) {
	c := &Composite{ByPlatform: map[Platform]Verifier{}}
	_, err := c.Verify(context.Background(), PlatformAndroid, nil, nil, nil)
	if !errors.Is(err, ErrAttestationFailed) {
		t.Fatalf("err = %v, want ErrAttestationFailed", err)
	}
}
