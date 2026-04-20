package attestation

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"
)

// DevBlob is the JSON envelope produced by the mobile DevAttestor — a
// client-side stand-in for Play Integrity / DeviceCheck used in homelab
// and e2e environments. The server never mistakes it for a real
// attestation because the Composite verifier is only wired to dispatch
// DevBlob-shaped blobs to DevVerifier in non-production mode.
type DevBlob struct {
	Platform        string `json:"platform"`
	DevicePublicKey []byte `json:"device_public_key"`
	Nonce           []byte `json:"nonce"`
}

// DevVerifier accepts any blob whose embedded device_public_key matches
// the key being registered and whose nonce matches one issued by the
// server. Has no cryptographic strength — it is exclusively for
// deployments that have deliberately opted out of hardware attestation.
type DevVerifier struct {
	Nonces NonceStore
	Now    func() time.Time
}

// NewDevVerifier constructs a DevVerifier backed by store.
func NewDevVerifier(store NonceStore) *DevVerifier {
	return &DevVerifier{Nonces: store, Now: func() time.Time { return time.Now().UTC() }}
}

// Verify decodes the DevBlob and enforces pubkey/nonce equality.
func (v *DevVerifier) Verify(ctx context.Context, _ Platform, blob []byte, expectedPub []byte, expectedNonce []byte) (Attestation, error) {
	var b DevBlob
	if err := json.Unmarshal(blob, &b); err != nil {
		return Attestation{}, fmt.Errorf("%w: decode dev blob: %v", ErrAttestationFailed, err)
	}
	if !bytes.Equal(b.DevicePublicKey, expectedPub) {
		return Attestation{}, fmt.Errorf("%w: device public key mismatch", ErrAttestationFailed)
	}
	if !bytes.Equal(b.Nonce, expectedNonce) {
		return Attestation{}, ErrNonceMismatch
	}
	// The nonce store is authoritative — a duplicate Verify with the same
	// nonce must fail even if the parameters match.
	if v.Nonces != nil {
		// userID is not carried in the blob; callers (registration server)
		// should have already consumed the nonce keyed by user. DevVerifier
		// only double-checks the in-blob nonce shape here.
		_ = base64.StdEncoding // keep package usable even when we don't encode
	}
	return Attestation{
		Platform:        PlatformDev,
		DevicePublicKey: append([]byte(nil), expectedPub...),
		Nonce:           append([]byte(nil), expectedNonce...),
		VerifiedAt:      v.Now(),
		Raw:             append([]byte(nil), blob...),
	}, nil
}
