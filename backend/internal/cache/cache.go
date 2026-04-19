// Package cache is the process-wide cache abstraction. A single small
// interface (Get/Set/Del/Ping/Close) is implemented by Redis in
// production and by Noop when REDIS_URL is unset or unreachable. Every
// cache site is written as cache-aside: check cache; on miss fall
// through to Postgres and Set the result. Writers Del the affected keys
// AFTER the DB commit — a cache failure must never roll back a
// committed DB write.
package cache

import (
	"context"
	"encoding/json"
	"errors"
	"time"
)

// Cache is the minimum surface every call site depends on. All writes
// take a TTL — even "immutable" entries get a long bound so stale
// entries eventually fall out after a schema change.
type Cache interface {
	Get(ctx context.Context, key string) (value []byte, hit bool, err error)

	Set(ctx context.Context, key string, value []byte, ttl time.Duration) error

	Del(ctx context.Context, keys ...string) error

	Ping(ctx context.Context) error

	Close() error
}

// GetJSON is a typed Get helper. Returns (false, nil) on miss. Decode
// errors surface as (false, err) — treat them as misses at call sites.
func GetJSON(ctx context.Context, c Cache, key string, dst any) (bool, error) {
	if c == nil {
		return false, nil
	}
	raw, hit, err := c.Get(ctx, key)
	if err != nil || !hit {
		return false, err
	}
	if err := json.Unmarshal(raw, dst); err != nil {
		return false, err
	}
	return true, nil
}

// SetJSON marshals value and stores it under key for ttl.
func SetJSON(ctx context.Context, c Cache, key string, value any, ttl time.Duration) error {
	if c == nil {
		return nil
	}
	b, err := json.Marshal(value)
	if err != nil {
		return err
	}
	return c.Set(ctx, key, b, ttl)
}

// ErrNilCache is returned when callers pass a nil Cache where one was
// required. In practice every cmd constructs either Redis or Noop, so
// this is defensive only.
var ErrNilCache = errors.New("cache: nil Cache")
