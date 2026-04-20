//go:build integration

// Verifies that the pre-tx cached reads (receiver resolution + sender
// KYC tier) actually consult the cache on the happy path, and that the
// kycrepo tier-invalidation hook unblocks a promoted user's transfer on
// the next call.
package transfer

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/repository/kycrepo"
)

// memCache is a minimal in-process Cache used only by tests. It
// preserves the hit/miss semantics RedisCache exposes but records
// counts so we can assert on them.
type memCache struct {
	mu     sync.Mutex
	data   map[string][]byte
	hits   map[string]int
	misses map[string]int
	sets   map[string]int
	dels   map[string]int
}

func newMemCache() *memCache {
	return &memCache{
		data: map[string][]byte{}, hits: map[string]int{}, misses: map[string]int{},
		sets: map[string]int{}, dels: map[string]int{},
	}
}

func (m *memCache) Get(_ context.Context, key string) ([]byte, bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	v, ok := m.data[key]
	if ok {
		m.hits[key]++
		return v, true, nil
	}
	m.misses[key]++
	return nil, false, nil
}
func (m *memCache) Set(_ context.Context, key string, v []byte, _ time.Duration) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.data[key] = v
	m.sets[key]++
	return nil
}
func (m *memCache) Del(_ context.Context, keys ...string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, k := range keys {
		delete(m.data, k)
		m.dels[k]++
	}
	return nil
}
func (m *memCache) Ping(_ context.Context) error { return nil }
func (m *memCache) Close() error                 { return nil }

// TestInitiateTransfer_CachesTierAndReceiver asserts:
//  1. The first InitiateTransfer call populates the cache for the
//     sender's tier and the receiver's account_number.
//  2. A second call serves both reads from the cache (hit counters > 0).
//  3. A tier promotion via kycrepo.Submit invalidates the cached tier.
func TestInitiateTransfer_CachesTierAndReceiver(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	m := newMemCache()
	svc := New(pool, m, nil)

	// Alice at TIER_2 (permits ₦50k single) sends to Bob.
	insertUser(t, pool, "alice", "+2348100000011", "8100000011", TierTwo)
	insertUser(t, pool, "bob", "+2348100000012", "8100000012", TierZero)

	run := func(ref string) {
		if _, err := svc.InitiateTransfer(ctx, InitiateTransferInput{
			SenderUserID:          "alice",
			ReceiverAccountNumber: "8100000012",
			AmountKobo:            1_000_00,
			Reference:             ref,
		}); err != nil {
			t.Fatalf("%s: %v", ref, err)
		}
	}

	run(newRef(t, "warmup"))
	// First call should have Set the two hot keys.
	if m.sets["user:tier:alice"] == 0 {
		t.Fatalf("expected tier cache populated on first call; sets=%+v", m.sets)
	}
	if m.sets["acct:uid:8100000012"] == 0 {
		t.Fatalf("expected receiver cache populated on first call; sets=%+v", m.sets)
	}

	run(newRef(t, "hit"))
	// Second call should hit both.
	if m.hits["user:tier:alice"] < 1 {
		t.Fatalf("expected tier cache hit on second call; hits=%+v", m.hits)
	}
	if m.hits["acct:uid:8100000012"] < 1 {
		t.Fatalf("expected receiver cache hit on second call; hits=%+v", m.hits)
	}

	// Promote alice to TIER_3 via kycrepo.Submit and confirm the
	// invalidation hook fired Del on user:tier:alice.
	kr := kycrepo.New(pool, m)
	tier := TierThree
	submittedBy := "alice"
	now := time.Now().UTC()
	if _, err := kr.Submit(ctx, kycrepo.SubmissionInput{
		ID:          fmt.Sprintf("sub-%d", time.Now().UnixNano()),
		UserID:      "alice",
		IDType:      "BVN",
		IDNumber:    "22212345678",
		Status:      "VERIFIED",
		TierGranted: &tier,
		SubmittedBy: &submittedBy,
		VerifiedAt:  &now,
	}); err != nil {
		t.Fatalf("kycrepo.Submit: %v", err)
	}
	if m.dels["user:tier:alice"] < 1 {
		t.Fatalf("expected Submit to Del tier cache; dels=%+v", m.dels)
	}

	// Confirm the next transfer reads the new tier (TIER_3 unlimited)
	// rather than the previously cached TIER_2.
	if _, err := svc.InitiateTransfer(ctx, InitiateTransferInput{
		SenderUserID:          "alice",
		ReceiverAccountNumber: "8100000012",
		// ₦1,000,000 would exceed TIER_2's ₦50k single limit; succeeds
		// only if the cached stale TIER_2 was invalidated.
		AmountKobo: 1_000_000_00,
		Reference:  newRef(t, "post-promote"),
	}); err != nil {
		t.Fatalf("post-promote transfer: %v", err)
	}

	// And sanity: the stored cached tier should now match TIER_3.
	var cachedTier string
	if _, err := cache.GetJSON(ctx, m, "user:tier:alice", &cachedTier); err != nil {
		t.Fatalf("GetJSON: %v", err)
	}
	if cachedTier != TierThree {
		// The tier may be cached by the post-promote call itself
		// (GetSenderKYCTier SetJSONs on miss). Decode and assert.
		raw, _, _ := m.Get(ctx, "user:tier:alice")
		_ = json.Unmarshal(raw, &cachedTier)
		if cachedTier != TierThree {
			t.Fatalf("expected cached tier=%s after promote; got %q", TierThree, cachedTier)
		}
	}
}
