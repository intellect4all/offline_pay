package bff

import (
	"sync"
	"time"

	"golang.org/x/time/rate"
)

// UserLimiter is the per-user rate-limit surface. Implementations today:
//
//   - MemoryUserRateLimiter — in-process token bucket, single-pod.
//   - RedisUserRateLimiter  — Redis-backed fixed window, cross-pod shared.
//
// The middleware in ratelimit_middleware.go consumes this interface so the
// BFF main can pick the right implementation at startup and gracefully
// fall back to memory when Redis is unavailable.
type UserLimiter interface {
	Allow(userID string) bool
	Stop()
}

// MemoryUserRateLimiter enforces per-user token-bucket rate limiting in
// process. Each user_id gets its own *rate.Limiter with the configured
// RPS and burst. Idle entries are evicted after 5 minutes so memory
// use is bounded.
//
// Single-pod only: each instance maintains its own bucket, so coordinated
// clients can bypass the limit by spreading requests across pods. For
// multi-pod deployments, prefer RedisUserRateLimiter.
type MemoryUserRateLimiter struct {
	rps   rate.Limit
	burst int

	mu      sync.Mutex
	entries map[string]*limiterEntry
	stopCh  chan struct{}
}

type limiterEntry struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

const idleEvictInterval = 30 * time.Second
const idleTTL = 5 * time.Minute

// NewMemoryUserRateLimiter returns an in-process per-user rate limiter
// with the given sustained RPS and burst size. A background goroutine
// evicts idle entries every 30 seconds; call Stop() on shutdown.
func NewMemoryUserRateLimiter(rps float64, burst int) *MemoryUserRateLimiter {
	l := &MemoryUserRateLimiter{
		rps:     rate.Limit(rps),
		burst:   burst,
		entries: make(map[string]*limiterEntry),
		stopCh:  make(chan struct{}),
	}
	go l.evictLoop()
	return l
}

// NewUserRateLimiter is a backwards-compatible alias for
// NewMemoryUserRateLimiter. Prefer the explicit constructor in new code.
func NewUserRateLimiter(rps float64, burst int) *MemoryUserRateLimiter {
	return NewMemoryUserRateLimiter(rps, burst)
}

// Allow returns true if the request from userID is within the rate limit.
func (l *MemoryUserRateLimiter) Allow(userID string) bool {
	l.mu.Lock()
	e, ok := l.entries[userID]
	if !ok {
		e = &limiterEntry{
			limiter: rate.NewLimiter(l.rps, l.burst),
		}
		l.entries[userID] = e
	}
	e.lastSeen = time.Now()
	lim := e.limiter
	l.mu.Unlock()

	return lim.Allow()
}

// Stop terminates the background eviction goroutine.
func (l *MemoryUserRateLimiter) Stop() {
	close(l.stopCh)
}

func (l *MemoryUserRateLimiter) evictLoop() {
	ticker := time.NewTicker(idleEvictInterval)
	defer ticker.Stop()
	for {
		select {
		case <-l.stopCh:
			return
		case now := <-ticker.C:
			l.mu.Lock()
			for uid, e := range l.entries {
				if now.Sub(e.lastSeen) > idleTTL {
					delete(l.entries, uid)
				}
			}
			l.mu.Unlock()
		}
	}
}
