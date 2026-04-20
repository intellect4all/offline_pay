// Package main is the entrypoint for the offlinepay backoffice admin-api.
//
// It exposes a REST JSON API on ADMIN_HTTP_ADDR (default :8081) for the
// Nuxt dashboard. Auth is email+password + bcrypt; access tokens are
// short-lived HMAC-SHA256 JWTs, refresh tokens are persisted in
// admin_sessions.
//
// Required env:
//   DB_URL                      — Postgres connection string
//   ADMIN_JWT_SECRET            — HMAC secret for access tokens (>= 32 bytes)
//
// Optional env:
//   ADMIN_HTTP_ADDR             — listen addr (default :8081)
//   ADMIN_ACCESS_TTL_MINUTES    — access token TTL (default 15)
//   ADMIN_REFRESH_TTL_HOURS     — refresh token TTL (default 168 = 7 days)
//   ADMIN_CORS_ORIGIN           — CORS allowed origin (default http://localhost:3000)
//   ADMIN_JWT_AUDIENCE          — aud claim (default offlinepay-admin)
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/intellect/offlinepay/db"
	"github.com/intellect/offlinepay/internal/logging"
	"github.com/intellect/offlinepay/internal/observability"
	migraterunner "github.com/intellect/offlinepay/internal/repository/migrate"
	svc "github.com/intellect/offlinepay/internal/service/admin"
	httpadmin "github.com/intellect/offlinepay/internal/transport/http/admin"
)

func main() {
	if err := run(); err != nil {
		slog.Error("adminapi exited", "err", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := loadConfig()
	if err != nil {
		return err
	}

	logging.Setup(cfg.Env, cfg.LogFormat, cfg.LogLevel)

	rootCtx, cancel := context.WithCancel(context.Background())
	defer cancel()

	otelShutdown, err := observability.Setup(rootCtx, observability.TracingConfig{
		Endpoint:    cfg.OTELEndpoint,
		ServiceName: cfg.OTELServiceName,
		Env:         cfg.Env,
		SampleRatio: 1.0,
	})
	if err != nil {
		return fmt.Errorf("otel: %w", err)
	}
	defer func() {
		shutdownCtx, c := context.WithTimeout(context.Background(), 5*time.Second)
		defer c()
		_ = otelShutdown(shutdownCtx)
	}()

	if cfg.MigrateOnBoot {
		if err := migraterunner.Run(rootCtx, cfg.DBURL, db.MigrationsFS); err != nil {
			return fmt.Errorf("migrate on boot: %w", err)
		}
	}

	pool, err := pgxpool.New(rootCtx, cfg.DBURL)
	if err != nil {
		return fmt.Errorf("pgxpool: %w", err)
	}
	defer pool.Close()
	if err := pool.Ping(rootCtx); err != nil {
		return fmt.Errorf("pg ping: %w", err)
	}

	signer := svc.JWTSigner{Secret: []byte(cfg.JWTSecret), Audience: cfg.JWTAudience, TTL: cfg.AccessTTL}
	service := svc.New(pool, signer, cfg.RefreshTTL)
	handler := httpadmin.NewHandler(service)

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           handler.Mux(cfg.CORSOrigin),
		ReadHeaderTimeout: 5 * time.Second,
	}

	serverErr := make(chan error, 1)
	go func() {
		slog.Info("adminapi listening", "addr", cfg.HTTPAddr, "cors_origin", cfg.CORSOrigin)
		serverErr <- srv.ListenAndServe()
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-sigCh:
		slog.Info("shutdown signal", "signal", sig.String())
	case err := <-serverErr:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("http serve: %w", err)
		}
	}

	shutdownCtx, c := context.WithTimeout(context.Background(), 10*time.Second)
	defer c()
	return srv.Shutdown(shutdownCtx)
}
