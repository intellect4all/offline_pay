package fraud

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/intellect/offlinepay/internal/domain"
)

// Default detector thresholds. Settlement flows can override when
// constructing the detector.
const (
	DefaultVelocityWindow    = 5 * time.Minute
	DefaultVelocityThreshold = 20
	DefaultGeoWindow         = 10 * time.Minute
)

// signalSink is the subset of RecorderAdapter/Service the detector needs.
// Using an interface keeps the detector unit-testable without pulling in a
// repo.
type signalSink interface {
	Record(ctx context.Context, ev domain.FraudEvent)
}

// Detector derives velocity + geographic-anomaly fraud signals from the
// stream of settlement events. It is in-process and bounded: only the most
// recent observations per user are retained.
//
// Velocity: if a user accumulates more than `VelocityThreshold` settled
// transactions in any `VelocityWindow`-long window, a FraudVelocityBreach
// event is emitted.
//
// Geographic: two claims uploaded within `GeoWindow` whose metadata country
// codes differ yield a FraudGeographicAnomaly event (impossible travel).
type Detector struct {
	Sink              signalSink
	VelocityWindow    time.Duration
	VelocityThreshold int
	GeoWindow         time.Duration
	Clock             func() time.Time

	mu        sync.Mutex
	velocity  map[string][]time.Time           // userID → sorted timestamps
	geo       map[string]geoObservation        // userID → most recent geo
	emitted   map[string]struct{}              // dedupe velocity alerts per window
}

type geoObservation struct {
	country string
	at      time.Time
}

// NewDetector constructs a Detector with default windows. sink may be nil
// (observations are still tracked; signals just aren't emitted).
func NewDetector(sink signalSink) *Detector {
	return &Detector{
		Sink:              sink,
		VelocityWindow:    DefaultVelocityWindow,
		VelocityThreshold: DefaultVelocityThreshold,
		GeoWindow:         DefaultGeoWindow,
		Clock:             func() time.Time { return time.Now().UTC() },
		velocity:          map[string][]time.Time{},
		geo:               map[string]geoObservation{},
		emitted:           map[string]struct{}{},
	}
}

// ObserveSettled records a settled transaction for userID at the given
// time. If the cumulative count inside VelocityWindow crosses the
// threshold, a single FraudVelocityBreach signal is emitted for the window.
func (d *Detector) ObserveSettled(ctx context.Context, userID string, at time.Time) {
	if d == nil || userID == "" {
		return
	}
	d.mu.Lock()
	defer d.mu.Unlock()

	cutoff := at.Add(-d.VelocityWindow)
	ts := d.velocity[userID]
	kept := ts[:0]
	for _, t := range ts {
		if t.After(cutoff) {
			kept = append(kept, t)
		}
	}
	kept = append(kept, at)
	d.velocity[userID] = kept

	if len(kept) <= d.VelocityThreshold {
		// Reset the per-user emit flag once the window has drained below
		// threshold so a second burst can still alert.
		delete(d.emitted, userID)
		return
	}
	if _, already := d.emitted[userID]; already {
		return
	}
	d.emitted[userID] = struct{}{}
	if d.Sink == nil {
		return
	}
	d.Sink.Record(ctx, domain.FraudEvent{
		UserID:     userID,
		SignalType: domain.FraudVelocityBreach,
		Severity:   "MEDIUM",
		Details: fmt.Sprintf(
			"%d settled txns in %s (threshold %d)",
			len(kept), d.VelocityWindow, d.VelocityThreshold,
		),
		CreatedAt: at,
	})
}

// ObserveClaim records an inbound claim for userID together with the
// country code carried on the claim metadata. If the user's previously
// observed country differs and both observations fall inside GeoWindow, a
// FraudGeographicAnomaly signal is emitted.
//
// country is case-insensitive (normalized via strings.ToUpper would be
// ideal, but we compare byte-for-byte here — callers should pass a stable
// ISO-3166 alpha-2 code).
func (d *Detector) ObserveClaim(ctx context.Context, userID, country string, at time.Time) {
	if d == nil || userID == "" || country == "" {
		return
	}
	d.mu.Lock()
	defer d.mu.Unlock()

	prev, ok := d.geo[userID]
	d.geo[userID] = geoObservation{country: country, at: at}

	if !ok || prev.country == country {
		return
	}
	if at.Sub(prev.at) > d.GeoWindow {
		return
	}
	if d.Sink == nil {
		return
	}
	d.Sink.Record(ctx, domain.FraudEvent{
		UserID:     userID,
		SignalType: domain.FraudGeographicAnomaly,
		Severity:   "MEDIUM",
		Details: fmt.Sprintf(
			"claims from %s and %s within %s",
			prev.country, country, d.GeoWindow,
		),
		CreatedAt: at,
	})
}
