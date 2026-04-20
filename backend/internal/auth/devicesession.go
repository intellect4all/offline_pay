// Package auth Device session tokens — Ed25519-signed assertions the device can verify
// purely offline. Issued by the BFF after a fresh online login (or refresh)
// and cached on-device alongside the server's public key.
//
// Why a separate token from the access JWT:
//
//   - Access JWTs are HMAC-signed; only the server can verify them. Useful
//     for protecting BFF endpoints, useless for proving offline that the
//     user is authorised to operate the wallet.
//   - Device session tokens are Ed25519-signed; the device verifies the
//     signature locally against a cached server public key, with no
//     connectivity required. They cap how long the offline-only flows
//     (PIN-gated wallet spend) keep working when the network is gone.
//
// The token mirrors the cryptographic shape of the existing payment ceiling
// token: short header + JSON claims + Ed25519 signature, base64url joined.
//
// Scopes are intentionally narrow. `offline_pay` is the only scope today;
// online-only operations stay gated by the access JWT and re-verify against
// the server.
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

// Errors returned by ParseDeviceSession + VerifyDeviceSession. Distinct
// types so the device-side caller can decide whether to clear the cache or
// just prompt the user to come online.
var (
	ErrDSMalformed    = errors.New("auth: device session token malformed")
	ErrDSBadSignature = errors.New("auth: device session token signature invalid")
	ErrDSExpired      = errors.New("auth: device session token expired")
	ErrDSWrongAud     = errors.New("auth: device session token audience mismatch")
	ErrDSWrongScope   = errors.New("auth: device session token scope unsupported")
	ErrDSWrongDevice  = errors.New("auth: device session token bound to different device")
)

// ScopeOfflinePay authorises the offline wallet spend / verify path on the
// device. The only scope shipped today; we leave the field on the claim set
// so future tiers (e.g. `withdraw_offline`, `view_history_offline`) can be
// added without breaking the wire format.
const ScopeOfflinePay = "offline_pay"

// DeviceSessionHeader is the public envelope. Kid identifies the signing
// key so the device can pick the right pubkey from its cache when rotation
// lands.
type DeviceSessionHeader struct {
	Alg string `json:"alg"`
	Typ string `json:"typ"`
	Kid string `json:"kid"`
}

// DeviceSessionClaims is everything the device needs to gate the offline
// wallet UI without phoning home.
type DeviceSessionClaims struct {
	Sub           string `json:"sub"`           // user_id
	AccountNumber string `json:"acc"`           // 10-digit account number
	DeviceID      string `json:"did"`           // registered device id
	Scope         string `json:"scope"`         // capability bundle
	Iat           int64  `json:"iat"`           // issued-at (unix seconds)
	Exp           int64  `json:"exp"`           // expiry  (unix seconds)
	Aud           string `json:"aud"`           // audience (BFF instance id)
	SessionID     string `json:"sid,omitempty"` // user_sessions row id (for revoke trace)
}

// ParsedDeviceSession captures the decoded blob with the bytes the
// signature covers, ready for verification.
type ParsedDeviceSession struct {
	Header       DeviceSessionHeader
	Claims       DeviceSessionClaims
	SigningInput []byte
	Signature    []byte
}

// SignDeviceSession encodes + signs a token. priv is the Ed25519 private
// key whose public counterpart the device will verify against.
func SignDeviceSession(priv ed25519.PrivateKey, kid string, claims DeviceSessionClaims) (string, error) {
	if len(priv) != ed25519.PrivateKeySize {
		return "", errors.New("auth: device session: bad private key size")
	}
	h := DeviceSessionHeader{Alg: "EdDSA", Typ: "DST", Kid: kid}
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

// ParseDeviceSession splits the token without verifying the signature so
// the caller can pick the right public key by Header.Kid.
func ParseDeviceSession(token string) (*ParsedDeviceSession, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil, ErrDSMalformed
	}
	enc := base64.RawURLEncoding
	hb, err := enc.DecodeString(parts[0])
	if err != nil {
		return nil, fmt.Errorf("%w: header b64: %v", ErrDSMalformed, err)
	}
	cb, err := enc.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("%w: claims b64: %v", ErrDSMalformed, err)
	}
	sig, err := enc.DecodeString(parts[2])
	if err != nil {
		return nil, fmt.Errorf("%w: sig b64: %v", ErrDSMalformed, err)
	}
	var hdr DeviceSessionHeader
	if err := json.Unmarshal(hb, &hdr); err != nil {
		return nil, fmt.Errorf("%w: header json: %v", ErrDSMalformed, err)
	}
	if hdr.Alg != "EdDSA" {
		return nil, fmt.Errorf("%w: alg=%q", ErrDSMalformed, hdr.Alg)
	}
	var claims DeviceSessionClaims
	if err := json.Unmarshal(cb, &claims); err != nil {
		return nil, fmt.Errorf("%w: claims json: %v", ErrDSMalformed, err)
	}
	return &ParsedDeviceSession{
		Header:       hdr,
		Claims:       claims,
		SigningInput: []byte(parts[0] + "." + parts[1]),
		Signature:    sig,
	}, nil
}

// Verify validates the signature, expiry, audience and
// device-id binding. `now` is injected for tests; pass time.Now() in
// production. `skew` tolerates clock drift in either direction (default 30
// minutes mirrors the ceiling-token grace window).
func (p *ParsedDeviceSession) Verify(pub ed25519.PublicKey, audience, expectedDeviceID string, now time.Time, skew time.Duration) error {
	if len(pub) != ed25519.PublicKeySize {
		return ErrDSBadSignature
	}
	if !ed25519.Verify(pub, p.SigningInput, p.Signature) {
		return ErrDSBadSignature
	}
	if audience != "" && p.Claims.Aud != audience {
		return ErrDSWrongAud
	}
	if expectedDeviceID != "" && p.Claims.DeviceID != expectedDeviceID {
		return ErrDSWrongDevice
	}
	if p.Claims.Scope != ScopeOfflinePay {
		return ErrDSWrongScope
	}
	nowUnix := now.Unix()
	skewSec := int64(skew.Seconds())
	if p.Claims.Exp > 0 && nowUnix > p.Claims.Exp+skewSec {
		return ErrDSExpired
	}
	return nil
}
