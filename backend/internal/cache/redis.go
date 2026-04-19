package cache

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/redis/go-redis/v9"

	"github.com/intellect/offlinepay/internal/logging"
)

// RedisCache
// Failure posture: Get returns (nil, false, nil) on redis.Nil. Any other
// backend error (timeout, closed conn, etc.) is logged, counted via
// Errors if set, and reported as miss. Set/Del errors are logged/counted
// and swallowed. Callers fall through to Postgres — the cache is
// invisible whether Redis is healthy or not.
//
// Errors is an optional Counter labelled by operation ("get"/"set"/"del").
// Nil-safe.
type RedisCache struct {
	c      *redis.Client
	log    *slog.Logger
	Errors *prometheus.CounterVec
}

// NewRedis parses url (redis://[:pw@]host:port/db) and returns a
// RedisCache that has passed a bootstrap ping.
func NewRedis(ctx context.Context, url string, logger *slog.Logger) (*RedisCache, error) {
	if url == "" {
		return nil, errors.New("cache: empty redis url")
	}
	opts, err := redis.ParseURL(url)
	if err != nil {
		return nil, fmt.Errorf("cache: parse redis url: %w", err)
	}
	client := redis.NewClient(opts)
	pingCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	if err := client.Ping(pingCtx).Err(); err != nil {
		_ = client.Close()
		return nil, fmt.Errorf("cache: redis ping: %w", err)
	}
	return &RedisCache{c: client, log: logging.Or(logger)}, nil
}

func (r *RedisCache) recordErr(op string) {
	if r.Errors != nil {
		r.Errors.WithLabelValues(op).Inc()
	}
}

func (r *RedisCache) Get(ctx context.Context, key string) ([]byte, bool, error) {
	b, err := r.c.Get(ctx, key).Bytes()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return nil, false, nil
		}
		r.recordErr("get")
		r.log.Warn("cache.get failed (treating as miss)", "key", key, "err", err)
		return nil, false, nil
	}
	return b, true, nil
}

func (r *RedisCache) Set(ctx context.Context, key string, value []byte, ttl time.Duration) error {
	if err := r.c.Set(ctx, key, value, ttl).Err(); err != nil {
		r.recordErr("set")
		r.log.Warn("cache.set failed", "key", key, "err", err)
	}
	return nil
}

func (r *RedisCache) Del(ctx context.Context, keys ...string) error {
	if len(keys) == 0 {
		return nil
	}
	if err := r.c.Del(ctx, keys...).Err(); err != nil {
		r.recordErr("del")
		r.log.Warn("cache.del failed", "keys", keys, "err", err)
	}
	return nil
}

func (r *RedisCache) Ping(ctx context.Context) error {
	return r.c.Ping(ctx).Err()
}

func (r *RedisCache) Close() error {
	return r.c.Close()
}
