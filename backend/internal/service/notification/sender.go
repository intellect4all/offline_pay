// Package notification dispatches user-facing events (transfer settled,
// transfer failed, etc.). LogSender is a dev placeholder — swap in FCM/APNs
// for production.
package notification

import (
	"context"
	"log/slog"

	"github.com/intellect/offlinepay/internal/logging"
)

// TODO: push notification sender (FCM Android / APNs iOS). LogSender is
// dev/staging only.

type Event struct {
	UserID   string
	Type     string // e.g. "transfer_settled", "transfer_failed", "transfer_received"
	Title    string
	Body     string
	Metadata map[string]string
}

// Sender dispatches notification events. Implementations may log, enqueue
// for push delivery, write to a notifications table, etc.
type Sender interface {
	Send(ctx context.Context, ev Event) error
}

// LogSender writes each event to slog. Never errors.
type LogSender struct {
	Logger *slog.Logger
}

func (s LogSender) Send(_ context.Context, ev Event) error {
	logging.Or(s.Logger).Info("notification",
		"user_id", ev.UserID,
		"type", ev.Type,
		"title", ev.Title,
		"body", ev.Body,
		"metadata", ev.Metadata,
	)
	return nil
}
