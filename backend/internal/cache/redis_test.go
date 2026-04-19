//go:build integration

// Integration tests for the Redis-backed Cache. Runs against a
// disposable redis:7-alpine container via testcontainers-go.
//
// Run with:
//
//	go test -tags=integration ./internal/cache/...
package cache

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"
)

func startRedis(t *testing.T, ctx context.Context) (string, func()) {
	t.Helper()
	req := testcontainers.ContainerRequest{
		Image:        "redis:7-alpine",
		ExposedPorts: []string{"6379/tcp"},
		WaitingFor:   wait.ForLog("Ready to accept connections").WithStartupTimeout(30 * time.Second),
	}
	container, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: req,
		Started:          true,
	})
	if err != nil {
		t.Fatalf("start redis: %v", err)
	}
	host, err := container.Host(ctx)
	if err != nil {
		t.Fatalf("host: %v", err)
	}
	port, err := container.MappedPort(ctx, "6379/tcp")
	if err != nil {
		t.Fatalf("port: %v", err)
	}
	url := fmt.Sprintf("redis://%s:%s/0", host, port.Port())
	cleanup := func() {
		_ = container.Terminate(context.Background())
	}
	return url, cleanup
}

func TestRedisCache_RoundTrip(t *testing.T) {
	ctx := context.Background()
	url, cleanup := startRedis(t, ctx)
	defer cleanup()

	c, err := NewRedis(ctx, url, nil)
	if err != nil {
		t.Fatalf("NewRedis: %v", err)
	}
	defer c.Close()

	// Miss.
	if _, hit, err := c.Get(ctx, "absent"); err != nil || hit {
		t.Fatalf("expected (_, false, nil); got hit=%v err=%v", hit, err)
	}

	// Set + hit.
	if err := c.Set(ctx, "k1", []byte("v1"), time.Minute); err != nil {
		t.Fatalf("Set: %v", err)
	}
	b, hit, err := c.Get(ctx, "k1")
	if err != nil || !hit || string(b) != "v1" {
		t.Fatalf("expected (v1, true, nil); got (%q, %v, %v)", b, hit, err)
	}

	// Del -> miss.
	if err := c.Del(ctx, "k1"); err != nil {
		t.Fatalf("Del: %v", err)
	}
	if _, hit, _ := c.Get(ctx, "k1"); hit {
		t.Fatalf("expected miss after Del")
	}
}

func TestRedisCache_TTLExpires(t *testing.T) {
	ctx := context.Background()
	url, cleanup := startRedis(t, ctx)
	defer cleanup()

	c, err := NewRedis(ctx, url, nil)
	if err != nil {
		t.Fatalf("NewRedis: %v", err)
	}
	defer c.Close()

	if err := c.Set(ctx, "ephemeral", []byte("x"), 200*time.Millisecond); err != nil {
		t.Fatalf("Set: %v", err)
	}
	time.Sleep(400 * time.Millisecond)
	if _, hit, _ := c.Get(ctx, "ephemeral"); hit {
		t.Fatalf("expected miss after ttl expired")
	}
}

func TestRedisCache_GetJSON(t *testing.T) {
	ctx := context.Background()
	url, cleanup := startRedis(t, ctx)
	defer cleanup()

	c, err := NewRedis(ctx, url, nil)
	if err != nil {
		t.Fatalf("NewRedis: %v", err)
	}
	defer c.Close()

	type payload struct {
		A int    `json:"a"`
		B string `json:"b"`
	}
	in := payload{A: 7, B: "hello"}
	if err := SetJSON(ctx, c, "kp", in, time.Minute); err != nil {
		t.Fatalf("SetJSON: %v", err)
	}
	var out payload
	hit, err := GetJSON(ctx, c, "kp", &out)
	if err != nil || !hit || out != in {
		t.Fatalf("expected hit+equal; got hit=%v err=%v out=%+v", hit, err, out)
	}
}

func TestNewRedis_UnreachableURLFails(t *testing.T) {
	// Port 1 is reserved and refused everywhere — fast, deterministic
	// failure. We want NewRedis to return an error (not silently
	// proceed) so callers can fall back to Noop.
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	_, err := NewRedis(ctx, "redis://127.0.0.1:1/0", nil)
	if err == nil {
		t.Fatal("expected NewRedis to fail on unreachable url")
	}
	if !errors.Is(err, context.DeadlineExceeded) &&
		!isConnectionRefused(err) &&
		err.Error() == "" {
		t.Fatalf("unexpected err shape: %v", err)
	}
}

func isConnectionRefused(err error) bool {
	return err != nil && contains(err.Error(), "refused")
}

func contains(s, sub string) bool {
	return len(s) >= len(sub) && (s == sub || indexOf(s, sub) >= 0)
}

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}

func TestNoop_AlwaysMisses(t *testing.T) {
	ctx := context.Background()
	var c Cache = Noop{}
	if err := c.Set(ctx, "k", []byte("v"), time.Minute); err != nil {
		t.Fatalf("Noop.Set returned err: %v", err)
	}
	if _, hit, err := c.Get(ctx, "k"); err != nil || hit {
		t.Fatalf("Noop.Get hit=%v err=%v; want false/nil", hit, err)
	}
}
