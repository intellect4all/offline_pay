// Package logging configures the process-wide structured logger.
//
// Format and level are env-driven (OFFLINEPAY_LOG_FORMAT, OFFLINEPAY_LOG_LEVEL)
// and resolved through internal/config. Setup installs the resulting handler as
// slog.Default so call sites can use the package-level slog functions.
package logging

import (
	"context"
	"io"
	"log/slog"
	"os"
	"runtime/debug"
	"strings"
)

// Setup builds a *slog.Logger and installs it as the process default.
//
// format: "json" or "text" (case-insensitive). Empty falls back to "text" for
// non-prod envs and "json" for env=="production".
// level: "debug", "info", "warn", "error". Empty defaults to "info".
func Setup(env, format, level string) *slog.Logger {
	return setupTo(os.Stdout, env, format, level)
}

func setupTo(w io.Writer, env, format, level string) *slog.Logger {
	lvl := parseLevel(level)
	handler := buildHandler(w, env, format, lvl)
	logger := slog.New(handler).With(baseAttrs(env)...)
	slog.SetDefault(logger)
	return logger
}

func buildHandler(w io.Writer, env, format string, lvl slog.Level) slog.Handler {
	opts := &slog.HandlerOptions{Level: lvl}
	switch resolveFormat(env, format) {
	case "json":
		return slog.NewJSONHandler(w, opts)
	default:
		return slog.NewTextHandler(w, opts)
	}
}

func resolveFormat(env, format string) string {
	f := strings.ToLower(strings.TrimSpace(format))
	if f == "json" || f == "text" {
		return f
	}
	if env == "production" {
		return "json"
	}
	return "text"
}

func parseLevel(s string) slog.Level {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

func baseAttrs(env string) []any {
	attrs := []any{
		slog.String("service", "offlinepay-server"),
		slog.String("env", env),
	}
	if v := buildVersion(); v != "" {
		attrs = append(attrs, slog.String("version", v))
	}
	return attrs
}

func buildVersion() string {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return ""
	}
	for _, s := range info.Settings {
		if s.Key == "vcs.revision" && s.Value != "" {
			if len(s.Value) > 12 {
				return s.Value[:12]
			}
			return s.Value
		}
	}
	return info.Main.Version
}

// FromContext returns slog.Default. Reserved for future per-request loggers
// that carry request metadata in context.
func FromContext(_ context.Context) *slog.Logger {
	return slog.Default()
}

// Or returns l when non-nil, otherwise slog.Default. Call at constructor
// entry to avoid the `if l == nil { l = slog.Default() }` boilerplate.
func Or(l *slog.Logger) *slog.Logger {
	if l == nil {
		return slog.Default()
	}
	return l
}
