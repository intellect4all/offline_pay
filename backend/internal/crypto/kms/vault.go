package kms

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
)

// VaultConfig points a VaultSigner at a HashiCorp Vault instance running
// the transit secrets engine. Token auth is the simplest path for a
// homelab deployment; swap in an AppRole or Kubernetes-auth wrapper later
// by populating Token from an external source before signer construction.
type VaultConfig struct {
	// Addr is the base URL of the Vault API, e.g. "http://vault:8200".
	Addr string
	// Token is a Vault token with `update` on
	// transit/sign/<key> and `read` on transit/keys/<key>.
	Token string
	// Mount is the transit engine mount point. Defaults to "transit".
	Mount string
	// HTTPClient is optional; a default is used if nil. Tests inject one
	// to stub the transport.
	HTTPClient *http.Client
}

// VaultSigner signs via Vault's transit engine:
//
//	POST /v1/<mount>/sign/<keyID>            -- produce a signature
//	GET  /v1/<mount>/keys/<keyID>            -- read the public half
//
// Private keys never leave Vault. Public keys are cached in-process; the
// cache is process-lifetime (no TTL) because keys don't change silently —
// rotations go through the ops path, which restarts this service.
type VaultSigner struct {
	cfg VaultConfig

	mu       sync.RWMutex
	pubCache map[string]ed25519.PublicKey
}

// NewVaultSigner constructs a VaultSigner. It does not validate connectivity
// — callers should ping PublicKey on startup for a fast-fail.
func NewVaultSigner(cfg VaultConfig) (*VaultSigner, error) {
	if cfg.Addr == "" {
		return nil, errors.New("vault signer: Addr is required")
	}
	if cfg.Token == "" {
		return nil, errors.New("vault signer: Token is required")
	}
	if cfg.Mount == "" {
		cfg.Mount = "transit"
	}
	if cfg.HTTPClient == nil {
		cfg.HTTPClient = &http.Client{Timeout: 5 * time.Second}
	}
	return &VaultSigner{cfg: cfg, pubCache: map[string]ed25519.PublicKey{}}, nil
}

// Sign posts the message to Vault's transit sign endpoint and decodes the
// returned signature. Vault returns signatures base64-encoded with a
// "vault:v1:" prefix that identifies the key version used.
func (v *VaultSigner) Sign(ctx context.Context, keyID string, msg []byte) ([]byte, error) {
	// For Ed25519 keys the transit engine ignores signature_algorithm /
	// marshaling_algorithm and returns the raw 64-byte signature base64
	// encoded; don't send those fields to avoid confusing older Vaults.
	body, err := json.Marshal(map[string]any{
		"input":     base64.StdEncoding.EncodeToString(msg),
		"prehashed": false,
	})
	if err != nil {
		return nil, fmt.Errorf("vault signer: encode request: %w", err)
	}
	var out struct {
		Data struct {
			Signature string `json:"signature"`
		} `json:"data"`
	}
	if err := v.do(ctx, http.MethodPost, fmt.Sprintf("/v1/%s/sign/%s", v.cfg.Mount, keyID), body, &out); err != nil {
		return nil, err
	}
	sig := out.Data.Signature
	if i := strings.LastIndex(sig, ":"); i >= 0 {
		sig = sig[i+1:]
	}
	raw, err := base64.StdEncoding.DecodeString(sig)
	if err != nil {
		return nil, fmt.Errorf("vault signer: decode signature: %w", err)
	}
	return raw, nil
}

// PublicKey reads the key's latest version and extracts the 32-byte
// Ed25519 public half.
func (v *VaultSigner) PublicKey(ctx context.Context, keyID string) (ed25519.PublicKey, error) {
	v.mu.RLock()
	if p, ok := v.pubCache[keyID]; ok {
		v.mu.RUnlock()
		return p, nil
	}
	v.mu.RUnlock()

	var out struct {
		Data struct {
			LatestVersion int `json:"latest_version"`
			Keys          map[string]struct {
				PublicKey string `json:"public_key"`
			} `json:"keys"`
		} `json:"data"`
	}
	if err := v.do(ctx, http.MethodGet, fmt.Sprintf("/v1/%s/keys/%s", v.cfg.Mount, keyID), nil, &out); err != nil {
		return nil, err
	}
	latest := fmt.Sprintf("%d", out.Data.LatestVersion)
	entry, ok := out.Data.Keys[latest]
	if !ok {
		return nil, fmt.Errorf("vault signer: key %q latest version %s not present", keyID, latest)
	}
	raw, err := base64.StdEncoding.DecodeString(entry.PublicKey)
	if err != nil {
		return nil, fmt.Errorf("vault signer: decode public key: %w", err)
	}
	if len(raw) != ed25519.PublicKeySize {
		return nil, fmt.Errorf("vault signer: public key size=%d, want %d", len(raw), ed25519.PublicKeySize)
	}
	pub := ed25519.PublicKey(raw)

	v.mu.Lock()
	v.pubCache[keyID] = pub
	v.mu.Unlock()
	return pub, nil
}

func (v *VaultSigner) do(ctx context.Context, method, path string, body []byte, out any) error {
	var rdr io.Reader
	if body != nil {
		rdr = bytes.NewReader(body)
	}
	req, err := http.NewRequestWithContext(ctx, method, v.cfg.Addr+path, rdr)
	if err != nil {
		return fmt.Errorf("vault signer: build request: %w", err)
	}
	req.Header.Set("X-Vault-Token", v.cfg.Token)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := v.cfg.HTTPClient.Do(req)
	if err != nil {
		return fmt.Errorf("vault signer: request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<14))
		return fmt.Errorf("vault signer: %s %s: status=%d body=%s", method, path, resp.StatusCode, string(b))
	}
	if out == nil {
		return nil
	}
	if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
		return fmt.Errorf("vault signer: decode response: %w", err)
	}
	return nil
}
