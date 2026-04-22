package observability

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Metrics is the process-wide collector set. One instance is built at
// bootstrap and injected into services that emit measurements.
type Metrics struct {
	Registry *prometheus.Registry

	SettlementLatency *prometheus.HistogramVec
	CeilingActive     prometheus.Gauge
	CeilingRelease    *prometheus.CounterVec
	LienAge           prometheus.Histogram
	GossipUploads     prometheus.Counter
	FraudSignals      *prometheus.CounterVec
	GRPCRequests      *prometheus.CounterVec
	GRPCDuration      *prometheus.HistogramVec
}

// NewMetrics constructs a fresh Metrics with all collectors registered on a
// private prometheus.Registry — no global side effects, easier to test.
func NewMetrics() *Metrics {
	reg := prometheus.NewRegistry()
	reg.MustRegister(collectors.NewGoCollector(), collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}))

	m := &Metrics{
		Registry: reg,
		SettlementLatency: prometheus.NewHistogramVec(prometheus.HistogramOpts{
			Name:    "offlinepay_settlement_latency_seconds",
			Help:    "Settlement latency by phase (submit, finalize, auto_settle).",
			Buckets: prometheus.DefBuckets,
		}, []string{"phase"}),
		CeilingActive: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "offlinepay_ceiling_active_total",
			Help: "Number of ceiling tokens currently in ACTIVE status.",
		}),
		CeilingRelease: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "offlinepay_ceiling_release_total",
			Help: "Ceiling release attempts broken down by how they resolved. " +
				"outcome=success: lien returned to main (moveToMain/recovery sweep/expiry sweep). " +
				"outcome=stale: candidate skipped because a new in-flight claim appeared. " +
				"outcome=error: release transaction failed; lien may be stranded — alert.",
		}, []string{"outcome", "terminal"}),
		LienAge: prometheus.NewHistogram(prometheus.HistogramOpts{
			Name:    "offlinepay_lien_age_seconds",
			Help:    "Age of a lien when it is released back to the main wallet.",
			Buckets: prometheus.ExponentialBuckets(60, 2, 12),
		}),
		GossipUploads: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "offlinepay_gossip_upload_total",
			Help: "Gossip blob uploads accepted by the settlement service.",
		}),
		FraudSignals: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "offlinepay_fraud_signal_total",
			Help: "Fraud signals recorded by type.",
		}, []string{"type"}),
		GRPCRequests: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "offlinepay_grpc_requests_total",
			Help: "gRPC requests handled by method and code.",
		}, []string{"method", "code"}),
		GRPCDuration: prometheus.NewHistogramVec(prometheus.HistogramOpts{
			Name:    "offlinepay_grpc_request_duration_seconds",
			Help:    "gRPC request duration by method.",
			Buckets: prometheus.DefBuckets,
		}, []string{"method"}),
	}
	reg.MustRegister(
		m.SettlementLatency,
		m.CeilingActive,
		m.CeilingRelease,
		m.LienAge,
		m.GossipUploads,
		m.FraudSignals,
		m.GRPCRequests,
		m.GRPCDuration,
	)
	return m
}

// Handler returns the Prometheus scrape handler for this Metrics' registry.
func (m *Metrics) Handler() http.Handler {
	return promhttp.HandlerFor(m.Registry, promhttp.HandlerOpts{Registry: m.Registry})
}
