package observability

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// WorkerMetrics is the transferworker-scoped collector set. It tracks outbox
// depth + age (polled gauges) and dispatcher/processor throughput (counters
// incremented from the hot path).
type WorkerMetrics struct {
	Registry *prometheus.Registry

	OutboxPendingCount                prometheus.Gauge
	OutboxOldestAgeSeconds            prometheus.Gauge
	OutboxDispatchedTotal             prometheus.Counter
	OutboxDispatchFailuresTotal       prometheus.Counter
	TransferProcessedTotal            *prometheus.CounterVec
	SettlementFinalizeProcessedTotal  *prometheus.CounterVec
}

// NewWorkerMetrics constructs the transferworker metric set on its own
// registry. No global state.
func NewWorkerMetrics() *WorkerMetrics {
	reg := prometheus.NewRegistry()
	reg.MustRegister(
		collectors.NewGoCollector(),
		collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}),
	)

	m := &WorkerMetrics{
		Registry: reg,
		OutboxPendingCount: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "offlinepay_outbox_pending_count",
			Help: "Number of outbox rows where dispatched_at IS NULL.",
		}),
		OutboxOldestAgeSeconds: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "offlinepay_outbox_oldest_age_seconds",
			Help: "Age in seconds of the oldest undispatched outbox row (0 if none).",
		}),
		OutboxDispatchedTotal: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "offlinepay_outbox_dispatched_total",
			Help: "Outbox envelopes successfully published to JetStream.",
		}),
		OutboxDispatchFailuresTotal: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "offlinepay_outbox_dispatch_failures_total",
			Help: "Outbox publish attempts that returned an error.",
		}),
		TransferProcessedTotal: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "offlinepay_transfer_processed_total",
			Help: "Transfer terminal outcomes by status (SETTLED|FAILED).",
		}, []string{"status"}),
		SettlementFinalizeProcessedTotal: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "offlinepay_settlement_finalize_processed_total",
			Help: "Settlement finalize outcomes by status (settled|skipped|failed).",
		}, []string{"status"}),
	}
	reg.MustRegister(
		m.OutboxPendingCount,
		m.OutboxOldestAgeSeconds,
		m.OutboxDispatchedTotal,
		m.OutboxDispatchFailuresTotal,
		m.TransferProcessedTotal,
		m.SettlementFinalizeProcessedTotal,
	)
	return m
}

// Handler returns the Prometheus scrape handler for this WorkerMetrics.
func (m *WorkerMetrics) Handler() http.Handler {
	return promhttp.HandlerFor(m.Registry, promhttp.HandlerOpts{Registry: m.Registry})
}
