// Package fraud records fraud signals against users and aggregates them
// into a decaying risk score that drives ceiling tiering (STANDARD /
// REDUCED / SUSPENDED). Score = logistic(Σ weight·decay(Δt, 30d)).
package fraud

import (
	"context"
	"math"
	"time"

	"github.com/intellect/offlinepay/internal/domain"
)

// Signal weights.
//
// Rationale (all in the nominal [0, 1] range; higher = more damning):
//   - SignatureInvalid (0.7): near-dispositive; only malicious or badly
//     broken clients produce bad Ed25519 signatures.
//   - DoubleSpend (0.5): strong evidence of attempted offline fraud, but
//     can occur from desynced clients; below signature failure.
//   - GeographicAnomaly (0.4): moderately suspicious; legitimate travel
//     exists, so not dispositive alone.
//   - SequenceAnomaly (0.3): gaps/reversals often indicate client bugs or
//     replay attempts; medium weight.
//   - DeviceChange (0.3): users do re-register devices, but unexpected
//     changes warrant attention.
//   - VelocityBreach (0.3): unusual throughput; noisy signal, medium weight.
//   - CeilingExhaustion (0.2): single exhaustion is benign; repeated
//     exhaustion is mildly suspicious.
const (
	WeightSignatureInvalid   = 0.7
	WeightDoubleSpend        = 0.5
	WeightGeographicAnomaly  = 0.4
	WeightSequenceAnomaly    = 0.3
	WeightDeviceChange       = 0.3
	WeightVelocityBreach     = 0.3
	WeightCeilingExhaustion  = 0.2
	WeightDefault            = 0.3
)

// Tier thresholds.
const (
	ThresholdReduced   = 0.3
	ThresholdSuspended = 0.7
)

// Tier labels.
const (
	TierStandard  = "STANDARD"
	TierReduced   = "REDUCED"
	TierSuspended = "SUSPENDED"
)

// Ceiling caps per tier, in kobo.
const (
	ReducedCapKobo   int64 = 500_000 // ₦5,000
	SuspendedCapKobo int64 = 0
)

// HalfLife is the exponential decay half-life applied to signal weights.
const HalfLife = 30 * 24 * time.Hour

// Repository is the narrow persistence interface required by the fraud
// service.
type Repository interface {
	InsertFraudSignal(ctx context.Context, ev domain.FraudEvent, weight float64) (domain.FraudEvent, error)
	ListFraudSignalsForUser(ctx context.Context, userID string) ([]domain.FraudEvent, error)
}

// Clock abstracts time.Now for deterministic tests.
type Clock func() time.Time

// Service implements fraud signal recording and scoring.
type Service struct {
	repo  Repository
	clock Clock
}

// New constructs a Service. If clock is nil, time.Now().UTC() is used.
func New(repo Repository, clock Clock) *Service {
	if clock == nil {
		clock = func() time.Time { return time.Now().UTC() }
	}
	return &Service{repo: repo, clock: clock}
}

// WeightFor returns the configured weight for a signal type.
func WeightFor(t domain.FraudSignalType) float64 {
	switch t {
	case domain.FraudSignatureInvalid:
		return WeightSignatureInvalid
	case domain.FraudDoubleSpend:
		return WeightDoubleSpend
	case domain.FraudGeographicAnomaly:
		return WeightGeographicAnomaly
	case domain.FraudSequenceAnomaly:
		return WeightSequenceAnomaly
	case domain.FraudDeviceChange:
		return WeightDeviceChange
	case domain.FraudVelocityBreach:
		return WeightVelocityBreach
	case domain.FraudCeilingExhaustion:
		return WeightCeilingExhaustion
	default:
		return WeightDefault
	}
}

// RecordSignal persists a fraud event, stamping the canonical weight for
// its signal type.
func (s *Service) RecordSignal(ctx context.Context, event domain.FraudEvent) error {
	if event.CreatedAt.IsZero() {
		event.CreatedAt = s.clock()
	}
	_, err := s.repo.InsertFraudSignal(ctx, event, WeightFor(event.SignalType))
	return err
}

// Score aggregates all fraud signals for userID into a decayed risk score
// in [0, 1] and maps it to a tier.
//
// Aggregation: each event contributes WeightFor(type) * 2^(-age/HalfLife).
// The raw sum is squashed through 1 - exp(-raw) so the result is monotonic,
// bounded in [0, 1), and insensitive to the absolute number of weights.
func (s *Service) Score(ctx context.Context, userID string) (domain.FraudScore, error) {
	events, err := s.repo.ListFraudSignalsForUser(ctx, userID)
	if err != nil {
		return domain.FraudScore{}, err
	}
	now := s.clock()
	out := domain.FraudScore{
		UserID:      userID,
		EventCount:  len(events),
		UpdatedAt:   now,
		CeilingTier: TierStandard,
	}
	if len(events) == 0 {
		return out, nil
	}
	var raw float64
	var latest time.Time
	for _, e := range events {
		age := now.Sub(e.CreatedAt)
		if age < 0 {
			age = 0
		}
		decay := math.Pow(2, -age.Seconds()/HalfLife.Seconds())
		raw += WeightFor(e.SignalType) * decay
		if e.CreatedAt.After(latest) {
			latest = e.CreatedAt
		}
	}
	score := 1 - math.Exp(-raw)
	if score < 0 {
		score = 0
	}
	if score > 1 {
		score = 1
	}
	out.Score = score
	out.CeilingTier = tierFor(score)
	if !latest.IsZero() {
		lt := latest
		out.LastEventAt = &lt
	}
	return out, nil
}

// tierFor maps a [0,1] score to a tier label.
func tierFor(score float64) string {
	switch {
	case score >= ThresholdSuspended:
		return TierSuspended
	case score >= ThresholdReduced:
		return TierReduced
	default:
		return TierStandard
	}
}

// ClampCeiling returns the maximum ceiling amount userID is currently
// allowed to request, given their tier, along with the tier label.
func (s *Service) ClampCeiling(ctx context.Context, userID string, requested int64) (int64, string, error) {
	score, err := s.Score(ctx, userID)
	if err != nil {
		return 0, "", err
	}
	switch score.CeilingTier {
	case TierSuspended:
		return SuspendedCapKobo, TierSuspended, nil
	case TierReduced:
		if requested > ReducedCapKobo {
			return ReducedCapKobo, TierReduced, nil
		}
		return requested, TierReduced, nil
	default:
		return requested, TierStandard, nil
	}
}
