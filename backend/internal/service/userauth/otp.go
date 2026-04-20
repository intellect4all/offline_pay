package userauth

import (
	"context"
	"log/slog"
)

// OTPSender delivers a previously-generated one-time code to the user
// out of band. The recipient is either an email (password reset, email
// verification) or — historically — a phone. The caller generates,
// hashes, and stores the code before calling Send; the sender is a pure
// transport.
type OTPSender interface {
	Send(ctx context.Context, recipient, code, purpose string) error
}

// LoggerOTPSender is a dev-only OTPSender that just logs the code. In
// dev the service derives deterministic codes (last6 of the recipient)
// so tests can predict them without inspecting logs.
type LoggerOTPSender struct {
	Logger *slog.Logger
}

func (s LoggerOTPSender) Send(_ context.Context, recipient, code, purpose string) error {
	if s.Logger != nil {
		s.Logger.Info("otp.send", "recipient", recipient, "purpose", purpose, "code", code)
	}
	return nil
}

// last6 returns the last 6 characters of s, or s itself if shorter. Used
// by the service to generate dev-mode OTP codes from phone/email.
func last6(s string) string {
	if len(s) <= 6 {
		return s
	}
	return s[len(s)-6:]
}
