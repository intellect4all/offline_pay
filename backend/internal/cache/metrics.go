package cache

import (
	"context"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

// Metrics is a small prometheus counter set owned by the cache
// subsystem. Construction is optional — pass a nil *Metrics to any
// Observe-wrapped cache to disable instrumentation (useful in tests and
// in cmds that don't expose /metrics).
type Metrics struct {
	Hits   *prometheus.CounterVec
	Misses *prometheus.CounterVec
	Errors *prometheus.CounterVec
}

// NewMetrics registers the counter vecs on reg. reg may be nil, in
// which case a nil *Metrics is returned and callers of Observe skip
// instrumentation.
func NewMetrics(reg prometheus.Registerer) *Metrics {
	if reg == nil {
		return nil
	}
	m := &Metrics{
		Hits: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "offlinepay_cache_hits_total",
			Help: "Cache GET calls that returned a stored value, by domain.",
		}, []string{"domain"}),
		Misses: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "offlinepay_cache_misses_total",
			Help: "Cache GET calls that returned no value, by domain.",
		}, []string{"domain"}),
		Errors: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "offlinepay_cache_errors_total",
			Help: "Cache operations that returned a backend error, by domain. Treated as miss at the call site.",
		}, []string{"domain"}),
	}
	reg.MustRegister(m.Hits, m.Misses, m.Errors)
	return m
}

// Observed wraps a Cache and annotates each call with a per-call-site
// domain label. Pass nil *Metrics to bypass instrumentation.
type Observed struct {
	Cache   Cache
	Domain  string
	Metrics *Metrics
}

func (o Observed) Get(ctx context.Context, key string) ([]byte, bool, error) {
	b, hit, err := o.Cache.Get(ctx, key)
	if o.Metrics != nil {
		switch {
		case err != nil:
			o.Metrics.Errors.WithLabelValues(o.Domain).Inc()
		case hit:
			o.Metrics.Hits.WithLabelValues(o.Domain).Inc()
		default:
			o.Metrics.Misses.WithLabelValues(o.Domain).Inc()
		}
	}
	return b, hit, err
}

func (o Observed) Set(ctx context.Context, key string, value []byte, ttl time.Duration) error {
	err := o.Cache.Set(ctx, key, value, ttl)
	if err != nil && o.Metrics != nil {
		o.Metrics.Errors.WithLabelValues(o.Domain).Inc()
	}
	return err
}

func (o Observed) Del(ctx context.Context, keys ...string) error {
	err := o.Cache.Del(ctx, keys...)
	if err != nil && o.Metrics != nil {
		o.Metrics.Errors.WithLabelValues(o.Domain).Inc()
	}
	return err
}

func (o Observed) Ping(ctx context.Context) error { return o.Cache.Ping(ctx) }
func (o Observed) Close() error                   { return o.Cache.Close() }
