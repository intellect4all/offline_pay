package fraud

import (
	"context"
	"testing"
	"time"

	"github.com/intellect/offlinepay/internal/domain"
)

type captureSink struct {
	events []domain.FraudEvent
}

func (c *captureSink) Record(_ context.Context, ev domain.FraudEvent) {
	c.events = append(c.events, ev)
}

func TestDetector_VelocityBreach(t *testing.T) {
	sink := &captureSink{}
	d := NewDetector(sink)
	d.VelocityThreshold = 3
	d.VelocityWindow = time.Minute

	base := time.Date(2026, 4, 1, 10, 0, 0, 0, time.UTC)
	for i := 0; i < 4; i++ {
		d.ObserveSettled(context.Background(), "u1", base.Add(time.Duration(i)*10*time.Second))
	}

	if len(sink.events) != 1 {
		t.Fatalf("events=%d, want 1", len(sink.events))
	}
	if sink.events[0].SignalType != domain.FraudVelocityBreach {
		t.Errorf("signal=%s", sink.events[0].SignalType)
	}
}

func TestDetector_VelocityDedupeWithinWindow(t *testing.T) {
	sink := &captureSink{}
	d := NewDetector(sink)
	d.VelocityThreshold = 2
	d.VelocityWindow = time.Minute

	base := time.Date(2026, 4, 1, 10, 0, 0, 0, time.UTC)
	for i := 0; i < 5; i++ {
		d.ObserveSettled(context.Background(), "u1", base.Add(time.Duration(i)*5*time.Second))
	}
	if len(sink.events) != 1 {
		t.Fatalf("events=%d, want 1 (deduped)", len(sink.events))
	}
}

func TestDetector_VelocityBelowThreshold(t *testing.T) {
	sink := &captureSink{}
	d := NewDetector(sink)
	d.VelocityThreshold = 10
	d.VelocityWindow = time.Minute

	base := time.Date(2026, 4, 1, 10, 0, 0, 0, time.UTC)
	for i := 0; i < 5; i++ {
		d.ObserveSettled(context.Background(), "u1", base.Add(time.Duration(i)*time.Second))
	}
	if len(sink.events) != 0 {
		t.Fatalf("events=%d, want 0", len(sink.events))
	}
}

func TestDetector_GeographicAnomaly(t *testing.T) {
	sink := &captureSink{}
	d := NewDetector(sink)
	d.GeoWindow = 10 * time.Minute

	base := time.Date(2026, 4, 1, 10, 0, 0, 0, time.UTC)
	d.ObserveClaim(context.Background(), "u1", "NG", base)
	d.ObserveClaim(context.Background(), "u1", "GH", base.Add(2*time.Minute))

	if len(sink.events) != 1 || sink.events[0].SignalType != domain.FraudGeographicAnomaly {
		t.Fatalf("events=%+v", sink.events)
	}
}

func TestDetector_GeographicSameCountry(t *testing.T) {
	sink := &captureSink{}
	d := NewDetector(sink)
	base := time.Date(2026, 4, 1, 10, 0, 0, 0, time.UTC)
	d.ObserveClaim(context.Background(), "u1", "NG", base)
	d.ObserveClaim(context.Background(), "u1", "NG", base.Add(time.Minute))
	if len(sink.events) != 0 {
		t.Fatalf("events=%d, want 0", len(sink.events))
	}
}

func TestDetector_GeographicOutsideWindow(t *testing.T) {
	sink := &captureSink{}
	d := NewDetector(sink)
	d.GeoWindow = time.Minute
	base := time.Date(2026, 4, 1, 10, 0, 0, 0, time.UTC)
	d.ObserveClaim(context.Background(), "u1", "NG", base)
	d.ObserveClaim(context.Background(), "u1", "GH", base.Add(5*time.Minute))
	if len(sink.events) != 0 {
		t.Fatalf("events=%d, want 0 (outside window)", len(sink.events))
	}
}
