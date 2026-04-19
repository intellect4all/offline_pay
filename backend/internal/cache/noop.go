package cache

import (
	"context"
	"time"
)

// Noop is a Cache that never stores anything and always reports miss.
// Used when REDIS_URL is unset or the initial Redis ping fails, so the
// rest of the process can run unchanged.
type Noop struct{}

func (Noop) Get(context.Context, string) ([]byte, bool, error)        { return nil, false, nil }
func (Noop) Set(context.Context, string, []byte, time.Duration) error { return nil }
func (Noop) Del(context.Context, ...string) error                     { return nil }
func (Noop) Ping(context.Context) error                               { return nil }
func (Noop) Close() error                                             { return nil }
