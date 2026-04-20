package notification

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"

	"github.com/intellect/offlinepay/internal/logging"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

// TokenLookup retrieves a user's registered FCM tokens and purges ones the
// upstream service reports as invalid. Satisfied by *sqlcgen.Queries.
type TokenLookup interface {
	ListPushTokensForUser(ctx context.Context, userID string) ([]sqlcgen.ListPushTokensForUserRow, error)
	DeletePushTokenByValue(ctx context.Context, fcmToken string) error
}

// FCMSender fans an event out to every push token the user has registered.
// Dead tokens (UNREGISTERED / INVALID_ARGUMENT / SENDER_ID_MISMATCH) are
// dropped from the registry so they stop consuming quota.
type FCMSender struct {
	Client *messaging.Client
	Tokens TokenLookup
	Logger *slog.Logger
}

// NewFCMSender constructs a sender from a project ID and a service-account
// credential that is either a filesystem path, a raw JSON string, or a base64
// encoding of the JSON.
func NewFCMSender(ctx context.Context, projectID, serviceAccount string, tokens TokenLookup, logger *slog.Logger) (*FCMSender, error) {
	if projectID == "" || serviceAccount == "" {
		return nil, errors.New("fcm: project id and service account required")
	}
	if tokens == nil {
		return nil, errors.New("fcm: token lookup required")
	}
	opt, err := resolveFCMCredentials(serviceAccount)
	if err != nil {
		return nil, fmt.Errorf("fcm credentials: %w", err)
	}
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID}, opt)
	if err != nil {
		return nil, fmt.Errorf("firebase app: %w", err)
	}
	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("firebase messaging: %w", err)
	}
	return &FCMSender{Client: client, Tokens: tokens, Logger: logger}, nil
}

func resolveFCMCredentials(v string) (option.ClientOption, error) {
	trimmed := strings.TrimSpace(v)
	if strings.HasPrefix(trimmed, "{") {
		return option.WithCredentialsJSON([]byte(trimmed)), nil
	}
	if decoded, err := base64.StdEncoding.DecodeString(trimmed); err == nil && len(decoded) > 0 && decoded[0] == '{' {
		return option.WithCredentialsJSON(decoded), nil
	}
	if _, err := os.Stat(trimmed); err != nil {
		return nil, fmt.Errorf("service account path unreadable: %w", err)
	}
	return option.WithCredentialsFile(trimmed), nil
}

// Send satisfies Sender. Errors from individual tokens are logged and swallowed
// so a bad registration does not block the rest of the fan-out; only lookup
// failures bubble up as a real error.
func (s *FCMSender) Send(ctx context.Context, ev Event) error {
	log := logging.Or(s.Logger)
	rows, err := s.Tokens.ListPushTokensForUser(ctx, ev.UserID)
	if err != nil {
		return fmt.Errorf("list push tokens: %w", err)
	}
	if len(rows) == 0 {
		log.Debug("fcm no tokens for user", "user_id", ev.UserID, "type", ev.Type)
		return nil
	}
	data := flattenPayload(ev)
	for _, row := range rows {
		msg := &messaging.Message{
			Token:        row.FcmToken,
			Notification: &messaging.Notification{Title: ev.Title, Body: ev.Body},
			Data:         data,
		}
		if _, sendErr := s.Client.Send(ctx, msg); sendErr != nil {
			s.handleSendError(ctx, row.FcmToken, ev, sendErr, log)
		}
	}
	return nil
}

func (s *FCMSender) handleSendError(ctx context.Context, token string, ev Event, sendErr error, log *slog.Logger) {
	log.Warn("fcm send failed", "user_id", ev.UserID, "type", ev.Type, "err", sendErr)
	if messaging.IsUnregistered(sendErr) ||
		messaging.IsInvalidArgument(sendErr) ||
		messaging.IsSenderIDMismatch(sendErr) {
		if delErr := s.Tokens.DeletePushTokenByValue(ctx, token); delErr != nil {
			log.Warn("fcm purge dead token failed", "err", delErr)
		}
	}
}

func flattenPayload(ev Event) map[string]string {
	data := make(map[string]string, len(ev.Metadata)+1)
	for k, v := range ev.Metadata {
		data[k] = v
	}
	data["type"] = ev.Type
	return data
}
