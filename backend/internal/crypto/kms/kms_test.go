package kms

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/intellect/offlinepay/internal/domain"
)

type fakeLoader struct {
	keys map[string]domain.BankSigningKey
}

func (f *fakeLoader) GetBankSigningKey(_ context.Context, keyID string) (domain.BankSigningKey, error) {
	k, ok := f.keys[keyID]
	if !ok {
		return domain.BankSigningKey{}, io.EOF
	}
	return k, nil
}

func TestLocalSigner_SignVerifyRoundTrip(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	loader := &fakeLoader{keys: map[string]domain.BankSigningKey{
		"bank-key-1": {KeyID: "bank-key-1", PublicKey: pub, PrivateKey: priv},
	}}
	s := NewLocalSigner(loader)

	msg := []byte("canonical ceiling payload bytes")
	sig, err := s.Sign(context.Background(), "bank-key-1", msg)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	if !ed25519.Verify(pub, msg, sig) {
		t.Fatalf("signature did not verify")
	}

	gotPub, err := s.PublicKey(context.Background(), "bank-key-1")
	if err != nil {
		t.Fatalf("pub: %v", err)
	}
	if !gotPub.Equal(pub) {
		t.Fatalf("pub mismatch")
	}
}

func TestVaultSigner_SignRoundTrip(t *testing.T) {
	// Stand up a minimal Vault-compatible HTTP stub. The VaultSigner speaks
	// POST /v1/<mount>/sign/<keyID> — we honor that and return a real
	// ed25519 signature the caller can verify.
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/v1/transit/sign/", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Vault-Token") != "dev-root-token" {
			t.Errorf("missing token: %v", r.Header)
		}
		var req struct {
			Input string `json:"input"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Fatal(err)
		}
		msg, err := base64.StdEncoding.DecodeString(req.Input)
		if err != nil {
			t.Fatal(err)
		}
		sig := ed25519.Sign(priv, msg)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"data": map[string]any{
				"signature": "vault:v1:" + base64.StdEncoding.EncodeToString(sig),
			},
		})
	})
	mux.HandleFunc("/v1/transit/keys/", func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"data": map[string]any{
				"latest_version": 1,
				"keys": map[string]any{
					"1": map[string]any{"public_key": base64.StdEncoding.EncodeToString(pub)},
				},
			},
		})
	})
	srv := httptest.NewServer(mux)
	defer srv.Close()

	vs, err := NewVaultSigner(VaultConfig{
		Addr: srv.URL, Token: "dev-root-token", Mount: "transit",
	})
	if err != nil {
		t.Fatal(err)
	}

	msg := []byte("canonical ceiling payload bytes")
	sig, err := vs.Sign(context.Background(), "bank-key-1", msg)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	if !ed25519.Verify(pub, msg, sig) {
		t.Fatalf("signature did not verify")
	}

	gotPub, err := vs.PublicKey(context.Background(), "bank-key-1")
	if err != nil {
		t.Fatalf("pub: %v", err)
	}
	if !gotPub.Equal(pub) {
		t.Fatalf("pub mismatch")
	}

	// Second call should hit the cache; we can detect this by shutting the
	// server down and ensuring PublicKey still returns.
	srv.Close()
	gotPub2, err := vs.PublicKey(context.Background(), "bank-key-1")
	if err != nil {
		t.Fatalf("cache miss after server close: %v", err)
	}
	if !gotPub2.Equal(pub) {
		t.Fatalf("pub mismatch post-cache")
	}
}

func TestVaultSigner_Construct(t *testing.T) {
	if _, err := NewVaultSigner(VaultConfig{}); err == nil {
		t.Fatal("expected error for empty config")
	}
	if _, err := NewVaultSigner(VaultConfig{Addr: "x"}); err == nil {
		t.Fatal("expected error for missing token")
	}
}
