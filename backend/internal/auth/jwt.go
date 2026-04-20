// Package auth provides device-signed JWT encoding and verification for the
// gRPC auth interceptor. Tokens are self-issued by the device: the device's
// registered Ed25519 keypair signs the token, the server looks up the device
// by the `kid` header, confirms it's active, and verifies the signature.
//
// No server issuance or handshake is needed — rotation is handled purely by
// flipping `devices.active` to false, which causes the interceptor to reject
// any subsequent JWT referencing the old device.
package auth

import (
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
)

// Errors surfaced by ParseAndVerify.
var (
	ErrMalformed     = errors.New("auth: malformed token")
	ErrUnknownAlg    = errors.New("auth: unknown alg")
	ErrBadSignature  = errors.New("auth: bad signature")
	ErrExpired       = errors.New("auth: token expired")
	ErrNotYetValid   = errors.New("auth: token not yet valid")
	ErrWrongAudience = errors.New("auth: wrong audience")
)

// Header is the JWT header. Kid carries the device_id.
type Header struct {
	Alg string `json:"alg"`
	Typ string `json:"typ"`
	Kid string `json:"kid"`
}

// Claims is the minimal claim set: subject=user_id, did=device_id.
type Claims struct {
	Sub string `json:"sub"`
	Did string `json:"did"`
	Iat int64  `json:"iat"`
	Exp int64  `json:"exp"`
	Aud string `json:"aud"`
	Jti string `json:"jti,omitempty"`
}

// Parsed captures both header + claims so the caller (the interceptor) can
// use Header.Kid to look up the device before signature verification.
type Parsed struct {
	Header          Header
	Claims          Claims
	SigningInput    []byte // bytes the signature covers (header.claims)
	Signature       []byte
}

// Parse splits the JWT and decodes header + claims without verifying the
// signature. The interceptor calls Parse first so it can look up the device
// by Header.Kid, then passes the device's public key to Verify.
func Parse(token string) (*Parsed, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil, ErrMalformed
	}
	headerB, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, fmt.Errorf("%w: header b64: %v", ErrMalformed, err)
	}
	claimsB, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("%w: claims b64: %v", ErrMalformed, err)
	}
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return nil, fmt.Errorf("%w: sig b64: %v", ErrMalformed, err)
	}
	var h Header
	if err := json.Unmarshal(headerB, &h); err != nil {
		return nil, fmt.Errorf("%w: header json: %v", ErrMalformed, err)
	}
	var c Claims
	if err := json.Unmarshal(claimsB, &c); err != nil {
		return nil, fmt.Errorf("%w: claims json: %v", ErrMalformed, err)
	}
	if h.Alg != "EdDSA" {
		return nil, ErrUnknownAlg
	}
	return &Parsed{
		Header:       h,
		Claims:       c,
		SigningInput: []byte(parts[0] + "." + parts[1]),
		Signature:    sig,
	}, nil
}

// Verify checks the Ed25519 signature, expiry, not-before (iat), and
// audience. `now` is injected so tests are deterministic; pass time.Now()
// in production. `skew` tolerates clock drift in both directions.
func (p *Parsed) Verify(pubKey ed25519.PublicKey, audience string, now time.Time, skew time.Duration) error {
	if len(pubKey) != ed25519.PublicKeySize {
		return ErrBadSignature
	}
	if !ed25519.Verify(pubKey, p.SigningInput, p.Signature) {
		return ErrBadSignature
	}
	if p.Claims.Aud != audience {
		return ErrWrongAudience
	}
	nowUnix := now.Unix()
	if p.Claims.Exp > 0 && nowUnix > p.Claims.Exp+int64(skew.Seconds()) {
		return ErrExpired
	}
	if p.Claims.Iat > 0 && nowUnix+int64(skew.Seconds()) < p.Claims.Iat {
		return ErrNotYetValid
	}
	return nil
}

// Sign builds and signs a JWT. Used by tests and (once Ed25519-in-HSM is
// wired up) by the mobile client side. On-device, the equivalent Dart
// implementation will call the same steps with Keystore.sign for the final
// Ed25519 signature.
func Sign(priv ed25519.PrivateKey, claims Claims) (string, error) {
	if len(priv) != ed25519.PrivateKeySize {
		return "", errors.New("auth: bad private key size")
	}
	h := Header{Alg: "EdDSA", Typ: "JWT", Kid: claims.Did}
	hb, err := json.Marshal(h)
	if err != nil {
		return "", err
	}
	cb, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	enc := base64.RawURLEncoding
	signingInput := enc.EncodeToString(hb) + "." + enc.EncodeToString(cb)
	sig := ed25519.Sign(priv, []byte(signingInput))
	return signingInput + "." + enc.EncodeToString(sig), nil
}
