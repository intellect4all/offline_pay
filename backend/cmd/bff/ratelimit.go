package main

import (
	"context"
	"log/slog"

	"github.com/intellect/offlinepay/internal/transport/http/bff"
)

// resolveUserLimiter returns the per-user rate limiter wired for this
// process. Redis is preferred so every BFF pod shares the same budget;
// we fall back to the in-memory limiter whenever Redis is unset or the
// connection fails. Graceful degradation is the goal — a Redis outage
// must never take the BFF down with it.
func resolveUserLimiter(ctx context.Context, cfg *config) bff.UserLimiter {
	mode := "memory"
	if cfg.RedisURL != "" {
		rl, err := bff.NewRedisUserRateLimiter(ctx, cfg.RedisURL, cfg.RateLimitRPS, cfg.RateLimitBurst, slog.Default())
		if err == nil {
			slog.Info("per-user rate limiter configured",
				"mode", "redis",
				"rps", cfg.RateLimitRPS,
				"burst", cfg.RateLimitBurst,
			)
			return rl
		}
		slog.Warn("redis rate limiter unavailable, falling back to memory",
			"err", err,
		)
	}
	slog.Info("per-user rate limiter configured",
		"mode", mode,
		"rps", cfg.RateLimitRPS,
		"burst", cfg.RateLimitBurst,
	)
	return bff.NewMemoryUserRateLimiter(cfg.RateLimitRPS, cfg.RateLimitBurst)
}
