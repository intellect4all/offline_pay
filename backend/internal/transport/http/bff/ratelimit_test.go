package bff

import (
	"testing"
)

func TestUserRateLimiter_Allow_BurstThenReject(t *testing.T) {
	lim := NewUserRateLimiter(10, 5) // 10 rps, burst of 5
	defer lim.Stop()

	uid := "user-abc"

	// First 5 should be allowed (burst).
	for i := range 5 {
		if !lim.Allow(uid) {
			t.Fatalf("expected Allow to return true for request %d within burst", i)
		}
	}

	// 6th should be rejected (burst exhausted, no time to refill).
	if lim.Allow(uid) {
		t.Fatal("expected Allow to return false after burst exhausted")
	}
}

func TestUserRateLimiter_Allow_DifferentUsers(t *testing.T) {
	lim := NewUserRateLimiter(10, 2)
	defer lim.Stop()

	// Exhaust user A's burst.
	lim.Allow("A")
	lim.Allow("A")
	if lim.Allow("A") {
		t.Fatal("expected A to be rate-limited")
	}

	// User B should still have their own burst.
	if !lim.Allow("B") {
		t.Fatal("expected B to be allowed (separate bucket)")
	}
}

func TestUserRateLimiter_Allow_SkipUnknownUser(t *testing.T) {
	lim := NewUserRateLimiter(100, 100)
	defer lim.Stop()

	// First call for a new user should succeed (creates entry).
	if !lim.Allow("new-user") {
		t.Fatal("expected new user to be allowed")
	}
}
