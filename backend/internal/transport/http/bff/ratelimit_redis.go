package bff

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"

	"github.com/intellect/offlinepay/internal/logging"
)

// RedisUserRateLimiter enforces per-user rate limiting backed by Redis
// so the budget is shared across every BFF pod. Implemented as a
// fixed-1s-window counter: INCR the (userID, current-second) slot and
// PEXPIRE it on creation; requests are allowed while the count stays
// at or below burst.
//
// Trade-off: fixed-window counters can admit up to 2×burst across a
// window boundary. Acceptable for the coarse abuse-prevention role this
// limiter plays in the POC; trade up to a sliding window or proper
// token bucket (e.g. go-redis/redis_rate) if that becomes a problem.
//
// Failure posture is fail-open: any Redis error allows the request and
// logs a warning. The BFF is protected by the in-process memory limiter
// fallback anyway (see cmd/bff/main.go), and a hard fail-closed would
// turn a Redis outage into a full site outage.
type RedisUserRateLimiter struct {
	client *redis.Client
	burst  int
	window time.Duration
	log    *slog.Logger
}

// NewRedisUserRateLimiter parses url (redis://[:pw@]host:port/db) and
// returns a limiter that allows up to `burst` requests per second per
// user. A bootstrap ping confirms the connection before returning.
//
// The caller owns lifetime: call Stop() on shutdown to release the
// underlying connection pool.
func NewRedisUserRateLimiter(ctx context.Context, url string, rps float64, burst int, logger *slog.Logger) (*RedisUserRateLimiter, error) {
	if url == "" {
		return nil, errors.New("bff: empty redis url for rate limiter")
	}
	opts, err := redis.ParseURL(url)
	if err != nil {
		return nil, fmt.Errorf("bff: parse redis url: %w", err)
	}
	client := redis.NewClient(opts)
	pingCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	if err := client.Ping(pingCtx).Err(); err != nil {
		_ = client.Close()
		return nil, fmt.Errorf("bff: redis rate-limit ping: %w", err)
	}
	// Fold the sustained RPS into the effective per-second ceiling so the
	// caller's (rps, burst) pair maps to a single integer budget. `burst`
	// already represents the allowed spike on top of rps in time/rate
	// semantics; combining them here keeps Allow() to one INCR.
	ceiling := max(burst, int(rps))
	return &RedisUserRateLimiter{
		client: client,
		burst:  ceiling,
		window: time.Second,
		log:    logging.Or(logger),
	}, nil
}

// Allow returns true when the userID has remaining budget in the
// current window. Any Redis error fails open (returns true) and logs.
func (l *RedisUserRateLimiter) Allow(userID string) bool {
	if userID == "" {
		return true
	}
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	key := l.bucketKey(userID)
	count, err := l.client.Incr(ctx, key).Result()
	if err != nil {
		l.log.Warn("rate-limit INCR failed, failing open", "err", err, "user", userID)
		return true
	}
	// Only the first INCR needs to set the TTL; subsequent ones within
	// the window are cheap no-op checks on the same key.
	if count == 1 {
		if err := l.client.PExpire(ctx, key, l.window).Err(); err != nil {
			l.log.Warn("rate-limit PEXPIRE failed", "err", err, "user", userID)
		}
	}
	return count <= int64(l.burst)
}

// Stop closes the underlying Redis client.
func (l *RedisUserRateLimiter) Stop() {
	if err := l.client.Close(); err != nil {
		l.log.Warn("rate-limit redis close", "err", err)
	}
}

// bucketKey pins the user into a fixed one-second slot. The second
// index is encoded in the key so the window rolls naturally — the old
// key expires, the new one starts at 1 on the next INCR.
func (l *RedisUserRateLimiter) bucketKey(userID string) string {
	return fmt.Sprintf("rl:user:%s:%d", userID, time.Now().Unix())
}
