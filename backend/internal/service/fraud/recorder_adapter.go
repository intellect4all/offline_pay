package fraud

import (
	"context"
	"log/slog"

	"github.com/intellect/offlinepay/internal/domain"
)

// RecorderAdapter satisfies settlement.FraudRecorder and
// reconciliation.FraudRecorder by forwarding events to a fraud.Service. It
// decouples the emitters (settlement, reconciliation, gossip) from the
// scoring store and keeps Record non-blocking for the caller's tx.
type RecorderAdapter struct {
	svc *Service
}

// NewRecorderAdapter wraps a Service in the Record(ctx, event) interface the
// settlement and reconciliation services consume.
func NewRecorderAdapter(svc *Service) *RecorderAdapter {
	return &RecorderAdapter{svc: svc}
}

// Record persists a fraud event. Errors are logged and swallowed — the
// settlement/reconciliation transaction must not fail because of a
// best-effort fraud write.
func (a *RecorderAdapter) Record(ctx context.Context, ev domain.FraudEvent) {
	if a == nil || a.svc == nil {
		return
	}
	if err := a.svc.RecordSignal(ctx, ev); err != nil {
		slog.WarnContext(ctx, "fraud recorder: record signal failed",
			"err", err,
			"signal_type", string(ev.SignalType),
			"user_id", ev.UserID,
		)
	}
}
