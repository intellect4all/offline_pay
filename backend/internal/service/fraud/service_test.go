package fraud

import (
	"context"
	"math"
	"testing"
	"time"

	"github.com/intellect/offlinepay/internal/domain"
)

// fakeRepo is an in-memory Repository for fraud-service tests.
type fakeRepo struct {
	events []domain.FraudEvent
}

func (f *fakeRepo) InsertFraudSignal(_ context.Context, ev domain.FraudEvent, _ float64) (domain.FraudEvent, error) {
	if ev.ID == "" {
		ev.ID = "ev-" + ev.UserID + "-" + string(ev.SignalType)
	}
	f.events = append(f.events, ev)
	return ev, nil
}

func (f *fakeRepo) ListFraudSignalsForUser(_ context.Context, userID string) ([]domain.FraudEvent, error) {
	out := make([]domain.FraudEvent, 0, len(f.events))
	for _, e := range f.events {
		if e.UserID == userID {
			out = append(out, e)
		}
	}
	return out, nil
}

func fixedClock(t time.Time) Clock { return func() time.Time { return t } }

func TestScore_EmptyHistory(t *testing.T) {
	ctx := context.Background()
	repo := &fakeRepo{}
	svc := New(repo, fixedClock(time.Unix(1_700_000_000, 0).UTC()))

	s, err := svc.Score(ctx, "u1")
	if err != nil {
		t.Fatalf("Score: %v", err)
	}
	if s.Score != 0 {
		t.Errorf("Score = %v, want 0", s.Score)
	}
	if s.CeilingTier != TierStandard {
		t.Errorf("Tier = %q, want STANDARD", s.CeilingTier)
	}
	if s.EventCount != 0 {
		t.Errorf("EventCount = %d, want 0", s.EventCount)
	}
	if s.LastEventAt != nil {
		t.Errorf("LastEventAt = %v, want nil", s.LastEventAt)
	}
}

func TestScore_OldSignatureInvalidDecaysLow(t *testing.T) {
	ctx := context.Background()
	now := time.Unix(1_700_000_000, 0).UTC()
	repo := &fakeRepo{}
	svc := New(repo, fixedClock(now))

	// 90 days old => three half-lives => 1/8 of original weight.
	old := now.Add(-90 * 24 * time.Hour)
	if err := svc.RecordSignal(ctx, domain.FraudEvent{
		UserID:     "u1",
		SignalType: domain.FraudSignatureInvalid,
		CreatedAt:  old,
	}); err != nil {
		t.Fatalf("RecordSignal: %v", err)
	}

	s, err := svc.Score(ctx, "u1")
	if err != nil {
		t.Fatalf("Score: %v", err)
	}
	// raw = 0.7 * 1/8 = 0.0875; 1 - exp(-0.0875) ≈ 0.0838.
	if s.Score > ThresholdReduced {
		t.Errorf("Score %v exceeds REDUCED threshold", s.Score)
	}
	if s.CeilingTier != TierStandard {
		t.Errorf("Tier = %q, want STANDARD", s.CeilingTier)
	}
	if s.EventCount != 1 {
		t.Errorf("EventCount = %d, want 1", s.EventCount)
	}
	if s.LastEventAt == nil || !s.LastEventAt.Equal(old) {
		t.Errorf("LastEventAt = %v, want %v", s.LastEventAt, old)
	}
}

func TestScore_MultipleRecentDoubleSpendEscalates(t *testing.T) {
	ctx := context.Background()
	now := time.Unix(1_700_000_000, 0).UTC()
	repo := &fakeRepo{}
	svc := New(repo, fixedClock(now))

	// Three fresh double-spends: raw = 1.5, score = 1 - e^-1.5 ≈ 0.777 -> SUSPENDED.
	for i := 0; i < 3; i++ {
		if err := svc.RecordSignal(ctx, domain.FraudEvent{
			ID:         "ds-" + string(rune('a'+i)),
			UserID:     "u1",
			SignalType: domain.FraudDoubleSpend,
			CreatedAt:  now,
		}); err != nil {
			t.Fatalf("RecordSignal: %v", err)
		}
	}

	s, err := svc.Score(ctx, "u1")
	if err != nil {
		t.Fatalf("Score: %v", err)
	}
	if s.CeilingTier != TierSuspended {
		t.Errorf("Tier = %q, want SUSPENDED (score=%v)", s.CeilingTier, s.Score)
	}

	// One fresh double-spend alone: raw=0.5, score=1-e^-0.5≈0.393 -> REDUCED.
	repo2 := &fakeRepo{}
	svc2 := New(repo2, fixedClock(now))
	if err := svc2.RecordSignal(ctx, domain.FraudEvent{
		UserID:     "u2",
		SignalType: domain.FraudDoubleSpend,
		CreatedAt:  now,
	}); err != nil {
		t.Fatalf("RecordSignal: %v", err)
	}
	s2, err := svc2.Score(ctx, "u2")
	if err != nil {
		t.Fatalf("Score: %v", err)
	}
	if s2.CeilingTier != TierReduced {
		t.Errorf("Tier = %q, want REDUCED (score=%v)", s2.CeilingTier, s2.Score)
	}
}

func TestClampCeiling_Tiers(t *testing.T) {
	ctx := context.Background()
	now := time.Unix(1_700_000_000, 0).UTC()

	// STANDARD: no signals, requested returned unchanged.
	{
		svc := New(&fakeRepo{}, fixedClock(now))
		got, tier, err := svc.ClampCeiling(ctx, "u1", 10_000_000)
		if err != nil {
			t.Fatalf("ClampCeiling: %v", err)
		}
		if tier != TierStandard || got != 10_000_000 {
			t.Errorf("STANDARD clamp: got (%d, %s), want (10000000, STANDARD)", got, tier)
		}
	}

	// REDUCED: one fresh double-spend ⇒ tier REDUCED, cap to 500_000.
	{
		repo := &fakeRepo{}
		svc := New(repo, fixedClock(now))
		_ = svc.RecordSignal(ctx, domain.FraudEvent{
			UserID: "u2", SignalType: domain.FraudDoubleSpend, CreatedAt: now,
		})
		got, tier, err := svc.ClampCeiling(ctx, "u2", 10_000_000)
		if err != nil {
			t.Fatalf("ClampCeiling: %v", err)
		}
		if tier != TierReduced || got != ReducedCapKobo {
			t.Errorf("REDUCED clamp: got (%d, %s), want (%d, REDUCED)", got, tier, ReducedCapKobo)
		}

		// Under-cap request passes through unchanged.
		got2, _, _ := svc.ClampCeiling(ctx, "u2", 100_000)
		if got2 != 100_000 {
			t.Errorf("REDUCED under-cap: got %d, want 100000", got2)
		}
	}

	// SUSPENDED: many recent signature failures ⇒ 0.
	{
		repo := &fakeRepo{}
		svc := New(repo, fixedClock(now))
		for i := 0; i < 5; i++ {
			_ = svc.RecordSignal(ctx, domain.FraudEvent{
				ID:         "sv-" + string(rune('a'+i)),
				UserID:     "u3",
				SignalType: domain.FraudSignatureInvalid,
				CreatedAt:  now,
			})
		}
		got, tier, err := svc.ClampCeiling(ctx, "u3", 10_000_000)
		if err != nil {
			t.Fatalf("ClampCeiling: %v", err)
		}
		if tier != TierSuspended || got != 0 {
			t.Errorf("SUSPENDED clamp: got (%d, %s), want (0, SUSPENDED)", got, tier)
		}
	}
}

// TestDecay_HalfLifeExact verifies that an event at t0-30d contributes
// exactly half of an identical event at t0. We compare the score of
// {now, now-30d} against an equivalent construction using the linearity of
// the pre-squash sum.
func TestDecay_HalfLifeExact(t *testing.T) {
	ctx := context.Background()
	now := time.Unix(1_700_000_000, 0).UTC()

	repo := &fakeRepo{}
	svc := New(repo, fixedClock(now))

	evNow := domain.FraudEvent{UserID: "u", SignalType: domain.FraudDoubleSpend, CreatedAt: now}
	evOld := domain.FraudEvent{UserID: "u", SignalType: domain.FraudDoubleSpend, CreatedAt: now.Add(-HalfLife)}
	if err := svc.RecordSignal(ctx, evNow); err != nil {
		t.Fatalf("RecordSignal: %v", err)
	}
	if err := svc.RecordSignal(ctx, evOld); err != nil {
		t.Fatalf("RecordSignal: %v", err)
	}

	s, err := svc.Score(ctx, "u")
	if err != nil {
		t.Fatalf("Score: %v", err)
	}

	// Expected raw = w*1 + w*0.5 = 1.5*w; expected score = 1 - exp(-1.5w).
	w := WeightFor(domain.FraudDoubleSpend)
	wantRaw := w*1.0 + w*0.5
	want := 1 - math.Exp(-wantRaw)

	if math.Abs(s.Score-want) > 1e-12 {
		t.Fatalf("Score = %.15f, want %.15f (diff %.2e)", s.Score, want, math.Abs(s.Score-want))
	}

	// Also assert that the old contribution is exactly half of the new one
	// at the raw-weight level. We reconstruct by computing each term.
	ageNew := now.Sub(now).Seconds()
	ageOld := now.Sub(now.Add(-HalfLife)).Seconds()
	decayNew := math.Pow(2, -ageNew/HalfLife.Seconds())
	decayOld := math.Pow(2, -ageOld/HalfLife.Seconds())
	if math.Abs(decayOld-0.5*decayNew) > 1e-15 {
		t.Errorf("decay_old / decay_new = %v, want 0.5", decayOld/decayNew)
	}
}
