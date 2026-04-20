package attestation

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"sync"
	"time"
)

// MemoryNonceStore is a process-local NonceStore suitable for single-node
// homelab deployments and tests. Nonces live in a map keyed by (userID,
// hex(nonce)) with an expiry timestamp; Consume is idempotent-safe
// (second Consume with the same nonce fails with ErrNonceMismatch).
//
// A multi-node production deployment should replace this with a
// Redis-backed implementation so nonces survive a failover.
type MemoryNonceStore struct {
	mu      sync.Mutex
	entries map[string]time.Time
	now     func() time.Time
}

// NewMemoryNonceStore constructs an empty store.
func NewMemoryNonceStore() *MemoryNonceStore {
	return &MemoryNonceStore{entries: map[string]time.Time{}, now: func() time.Time { return time.Now().UTC() }}
}

// Issue returns a 32-byte random nonce. The TTL is the wall-clock
// window during which Consume must run.
func (s *MemoryNonceStore) Issue(_ context.Context, userID string, ttl time.Duration) ([]byte, error) {
	n := make([]byte, 32)
	if _, err := rand.Read(n); err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.entries[s.key(userID, n)] = s.now().Add(ttl)
	s.gc()
	return n, nil
}

// Consume removes the (userID, nonce) entry. Returns ErrNonceMismatch if
// it was never issued, already consumed, or expired.
func (s *MemoryNonceStore) Consume(_ context.Context, userID string, nonce []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	k := s.key(userID, nonce)
	exp, ok := s.entries[k]
	if !ok {
		return ErrNonceMismatch
	}
	delete(s.entries, k)
	if s.now().After(exp) {
		return ErrNonceMismatch
	}
	return nil
}

func (s *MemoryNonceStore) key(userID string, nonce []byte) string {
	return userID + "|" + hex.EncodeToString(nonce)
}

// gc is called under the mutex; sweeps expired entries. Cheap enough to
// run on every Issue for the homelab scale this ships at.
func (s *MemoryNonceStore) gc() {
	now := s.now()
	for k, exp := range s.entries {
		if now.After(exp) {
			delete(s.entries, k)
		}
	}
}
