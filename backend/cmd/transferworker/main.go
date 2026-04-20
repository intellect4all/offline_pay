// Package main is the entrypoint for the offlinepay transfer worker.
//
// It runs two goroutines on a shared pgx pool + NATS JetStream context:
//   - Dispatcher: polls the outbox table and publishes pending envelopes.
//   - Processor:  pulls from JetStream and mutates the ledger (sender -> receiver).
//
// Required env:
//   DB_URL                         — Postgres connection string
//
// Optional env:
//   NATS_URL                       — NATS URL (default nats://localhost:4222)
//   WORKER_BATCH_SIZE              — dispatcher batch size (default 16)
//   WORKER_DISPATCH_INTERVAL_MS    — dispatcher tick interval ms (default 500)
//   WORKER_METRICS_ADDR            — Prometheus scrape listen addr (default :9102)
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/nats-io/nats.go"

	"github.com/intellect/offlinepay/db"
	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/logging"
	"github.com/intellect/offlinepay/internal/observability"
	migraterunner "github.com/intellect/offlinepay/internal/repository/migrate"
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
	"github.com/intellect/offlinepay/internal/service/notification"
	"github.com/intellect/offlinepay/internal/service/settlement"
	"github.com/intellect/offlinepay/internal/service/transfer"
)

func main() {
	if err := run(); err != nil {
		slog.Error("transferworker exited", "err", err)
		os.Exit(1)
	}
}

func run() error {
	cfg := loadConfig()

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

	nc, err := nats.Connect(cfg.NATSURL,
		nats.Name("offlinepay-transferworker"),
		nats.MaxReconnects(-1),
		nats.ReconnectWait(2*time.Second),
	)
	if err != nil {
		return fmt.Errorf("nats connect: %w", err)
	}
	defer nc.Drain()

	js, err := nc.JetStream()
	if err != nil {
		return fmt.Errorf("jetstream context: %w", err)
	}
	if err := transfer.EnsureStream(js); err != nil {
		return fmt.Errorf("ensure stream: %w", err)
	}

	metrics := observability.NewWorkerMetrics()

	slog.Info("transferworker starting",
		"nats_url", cfg.NATSURL, "batch_size", cfg.BatchSize, "interval", cfg.Interval,
		"metrics_addr", cfg.MetricsAddr)

	dispatcher := &transfer.Dispatcher{
		Pool: pool,
		Nats: nc,
		JS:   js,
		// rows whose aggregate is missing from
		// SubjectByAggregate drop here. Every known aggregate should
		// have an entry below.
		Subject: domain.OutboxSubjectTransfer,
		SubjectByAggregate: map[string]string{
			domain.OutboxAggregateTransfer:          domain.OutboxSubjectTransfer,
			domain.OutboxAggregateSettlementFinalize: domain.OutboxSubjectSettlementFinalize,
		},
		Logger:                slog.Default(),
		BatchSize:             cfg.BatchSize,
		Interval:              cfg.Interval,
		DispatchedTotal:       metrics.OutboxDispatchedTotal,
		DispatchFailuresTotal: metrics.OutboxDispatchFailuresTotal,
	}
	notifier := buildNotifier(rootCtx, cfg, pool)
	processor := &transfer.Processor{
		Pool:           pool,
		JS:             js,
		Subject:        domain.OutboxSubjectTransfer,
		Durable:        "payments-transfer-processor",
		Logger:         slog.Default(),
		ProcessedTotal: metrics.TransferProcessedTotal,
		Notifier:       notifier,
	}

	// Settlement finalize processor. Shares the pool, JetStream, and
	// notifier with the transfer processor — same worker binary, second
	// durable consumer. The finalize engine itself is the regular
	// settlement.Service wrapping a pgrepo adapter.
	settlementRepo := pgrepo.New(pool, cache.Noop{})
	settlementSvc := settlement.New(settlement.NewPgRepoAdapter(settlementRepo))
	finalizeProcessor := &settlement.FinalizeProcessor{
		Pool:           pool,
		Service:        settlementSvc,
		JS:             js,
		Subject:        domain.OutboxSubjectSettlementFinalize,
		Durable:        "payments-settlement-finalize",
		Logger:         slog.Default(),
		ProcessedTotal: metrics.SettlementFinalizeProcessedTotal,
		Notifier:       notifier,
	}

	// Metrics HTTP listener (Prometheus scrape target).
	var metricsSrv *http.Server
	if cfg.MetricsAddr != "" {
		mux := http.NewServeMux()
		mux.Handle("/metrics", metrics.Handler())
		mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte("ok"))
		})
		metricsSrv = &http.Server{Addr: cfg.MetricsAddr, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
		go func() {
			slog.Info("metrics http listening", "addr", cfg.MetricsAddr)
			if err := metricsSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
				slog.Error("metrics http server failed", "err", err)
			}
		}()
	}

	var wg sync.WaitGroup
	wg.Add(4)
	go func() {
		defer wg.Done()
		if err := dispatcher.Run(rootCtx); err != nil {
			slog.Error("dispatcher exited", "err", err)
		}
	}()
	go func() {
		defer wg.Done()
		if err := processor.Run(rootCtx); err != nil {
			slog.Error("processor exited", "err", err)
		}
	}()
	go func() {
		defer wg.Done()
		if err := finalizeProcessor.Run(rootCtx); err != nil {
			slog.Error("finalize processor exited", "err", err)
		}
	}()
	go func() {
		defer wg.Done()
		pollOutboxGauges(rootCtx, pool, metrics, 5*time.Second)
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	sig := <-sigCh
	slog.Info("shutdown signal", "signal", sig.String())
	cancel()
	if metricsSrv != nil {
		shutdownCtx, c := context.WithTimeout(context.Background(), 5*time.Second)
		_ = metricsSrv.Shutdown(shutdownCtx)
		c()
	}
	wg.Wait()
	return nil
}

// buildNotifier returns an FCMSender when FCM env is configured; otherwise it
// returns the LogSender stub so local/dev deployments keep working without
// Firebase credentials.
func buildNotifier(ctx context.Context, cfg *config, pool *pgxpool.Pool) notification.Sender {
	if cfg.FCMProjectID == "" || cfg.FCMServiceAccount == "" {
		slog.Info("fcm disabled; falling back to log sender")
		return notification.LogSender{Logger: slog.Default()}
	}
	sender, err := notification.NewFCMSender(ctx, cfg.FCMProjectID, cfg.FCMServiceAccount, sqlcgen.New(pool), slog.Default())
	if err != nil {
		slog.Error("fcm init failed; falling back to log sender", "err", err)
		return notification.LogSender{Logger: slog.Default()}
	}
	slog.Info("fcm sender ready", "project_id", cfg.FCMProjectID)
	return sender
}

// pollOutboxGauges refreshes the outbox depth + oldest-age gauges on a fixed
// interval. One query per tick; cheap (filtered COUNT + MIN).
func pollOutboxGauges(ctx context.Context, pool *pgxpool.Pool, m *observability.WorkerMetrics, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	// Prime once so /metrics has non-stale values before the first tick.
	refreshOutboxGauges(ctx, pool, m)
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			refreshOutboxGauges(ctx, pool, m)
		}
	}
}

func refreshOutboxGauges(ctx context.Context, pool *pgxpool.Pool, m *observability.WorkerMetrics) {
	qctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	var pending int64
	var oldestAge int64
	err := pool.QueryRow(qctx, `
		SELECT
			COUNT(*) FILTER (WHERE dispatched_at IS NULL),
			COALESCE(EXTRACT(EPOCH FROM now() - MIN(created_at) FILTER (WHERE dispatched_at IS NULL)), 0)::bigint
		FROM outbox`).Scan(&pending, &oldestAge)
	if err != nil {
		slog.Warn("outbox gauge poll failed", "err", err)
		return
	}
	m.OutboxPendingCount.Set(float64(pending))
	m.OutboxOldestAgeSeconds.Set(float64(oldestAge))
}
