package attestation

import (
	"context"
	"errors"
)

// DeviceCheckConfig carries the Apple App Attest / DeviceCheck identifiers
// required to validate iOS attestation assertions. Like Play Integrity,
// populating this requires an Apple developer account, which homelab
// deployments generally skip.
type DeviceCheckConfig struct {
	TeamID      string
	BundleID    string
	Environment string // "development" or "production"
}

// DeviceCheckVerifier is a stub mirroring PlayIntegrityVerifier; refuses
// every blob until a real implementation lands.
type DeviceCheckVerifier struct{ cfg DeviceCheckConfig }

// NewDeviceCheckVerifier constructs a DeviceCheckVerifier or returns an
// error when the config is incomplete.
func NewDeviceCheckVerifier(cfg DeviceCheckConfig) (*DeviceCheckVerifier, error) {
	if cfg.TeamID == "" || cfg.BundleID == "" || cfg.Environment == "" {
		return nil, errors.New("device check: TeamID + BundleID + Environment required")
	}
	return &DeviceCheckVerifier{cfg: cfg}, nil
}

// Verify is intentionally not yet implemented — rejects every blob so
// operators don't ship unverified attestations in production. Swap in a
// real App Attest assertion validator when taking Apple live.
func (*DeviceCheckVerifier) Verify(_ context.Context, _ Platform, _, _, _ []byte) (Attestation, error) {
	return Attestation{}, errors.New("device check: verifier not yet implemented; use DevVerifier or wire App Attest")
}
