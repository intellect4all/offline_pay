package domain

import "time"

// FraudEvent logs a single suspicious-activity signal attributed to a user.
type FraudEvent struct {
	// ID is the unique event identifier.
	ID string
	// UserID is the attributed user.
	UserID string
	// SignalType categorizes the detected signal.
	SignalType FraudSignalType
	// CeilingTokenID links the event to a ceiling when applicable.
	CeilingTokenID *string
	// TransactionID links the event to a transaction when applicable.
	TransactionID *string
	// Details is a human-readable description.
	Details string
	// Severity is one of "LOW", "MEDIUM", "HIGH", "CRITICAL".
	Severity string
	// CreatedAt is the event timestamp.
	CreatedAt time.Time
}

// FraudSignalType categorizes a fraud signal.
type FraudSignalType string

const (
	// FraudDoubleSpend indicates repeated sequence numbers on one ceiling.
	FraudDoubleSpend FraudSignalType = "DOUBLE_SPEND"
	// FraudCeilingExhaustion indicates ceiling was drawn over its limit.
	FraudCeilingExhaustion FraudSignalType = "CEILING_EXHAUSTION"
	// FraudGeographicAnomaly indicates implausible geographic movement.
	FraudGeographicAnomaly FraudSignalType = "GEOGRAPHIC_ANOMALY"
	// FraudSequenceAnomaly indicates gaps or reversals in sequence numbers.
	FraudSequenceAnomaly FraudSignalType = "SEQUENCE_ANOMALY"
	// FraudDeviceChange indicates an unexpected device/public-key change.
	FraudDeviceChange FraudSignalType = "DEVICE_CHANGE"
	// FraudVelocityBreach indicates abnormal transaction frequency.
	FraudVelocityBreach FraudSignalType = "VELOCITY_BREACH"
	// FraudSignatureInvalid indicates a signature verification failure.
	FraudSignatureInvalid FraudSignalType = "SIGNATURE_INVALID"
)

// FraudScore is the aggregated risk score for a user; drives ceiling tiering.
type FraudScore struct {
	// UserID is the scored user.
	UserID string
	// Score is the aggregated risk in [0.0, 1.0]; higher means riskier.
	Score float64
	// EventCount is the total number of FraudEvents contributing to the score.
	EventCount int
	// LastEventAt is the timestamp of the most recent FraudEvent.
	LastEventAt *time.Time
	// CeilingTier is the current tier: "STANDARD", "REDUCED", "SUSPENDED".
	CeilingTier string
	// UpdatedAt is the last-modified timestamp.
	UpdatedAt time.Time
}
