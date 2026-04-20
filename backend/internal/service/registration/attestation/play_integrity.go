package attestation

import (
	"context"
	"errors"
)

// PlayIntegrityConfig holds the Google Cloud bits required to verify a
// Play Integrity token. A homelab deployment will not have these;
// NewPlayIntegrityVerifier returns an error and the Composite falls back
// to rejecting android attestations until the operator wires it up.
type PlayIntegrityConfig struct {
	ProjectNumber int64
	PackageName   string
	// CredentialsJSON is the service-account key used to call Google's
	// playintegrity.googleapis.com API. Empty disables the verifier.
	CredentialsJSON []byte
}

// PlayIntegrityVerifier is a stub that refuses every blob until a real
// implementation lands. Shaping it as an explicit "not implemented" keeps
// production deployments honest: they'll fail shut rather than silently
// accept unverified attestations.
type PlayIntegrityVerifier struct{ cfg PlayIntegrityConfig }

// NewPlayIntegrityVerifier constructs a PlayIntegrityVerifier or returns
// an error if the config is incomplete.
func NewPlayIntegrityVerifier(cfg PlayIntegrityConfig) (*PlayIntegrityVerifier, error) {
	if cfg.ProjectNumber == 0 || cfg.PackageName == "" || len(cfg.CredentialsJSON) == 0 {
		return nil, errors.New("play integrity: ProjectNumber + PackageName + CredentialsJSON required")
	}
	return &PlayIntegrityVerifier{cfg: cfg}, nil
}

// Verify is intentionally not yet implemented — rejecting every blob so
// operators know to plug in the real decode-and-verify path before
// running in production. The signature matches the interface so a future
// patch swapping in the real logic doesn't require any call-site changes.
func (*PlayIntegrityVerifier) Verify(_ context.Context, _ Platform, _, _, _ []byte) (Attestation, error) {
	return Attestation{}, errors.New("play integrity: verifier not yet implemented; use DevVerifier or wire the real API call")
}
