//go:build scale

// Scale test: 100k payments across ~500 users. Validates the SubmitClaim +
// FinalizeForPayer paths hold up at higher volume and reports p99 latency.
//
// Run with:
//
//	go test -tags=scale -count=1 -timeout 15m -run TestScaleHundredK ./cmd/e2e/...
package e2e

import (
	"context"
	"math/rand"
	"sort"
	"testing"
	"time"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/service/settlement"
)

func TestScaleHundredK(t *testing.T) {
	ctx := context.Background()
	const (
		users = 500
		N     = 100_000
		// p99 budget per SubmitClaim call (single-item batch).
		p99Budget = 50 * time.Millisecond
		// Wall-clock budget for the whole run.
		wallBudget = 10 * time.Minute
	)
	e, cleanup := buildEnv(t, users)
	defer cleanup()

	rng := rand.New(rand.NewSource(1))
	for i := range e.users {
		// Generous ceilings so we don't churn refresh during the run.
		e.ensureCeiling(ctx, &e.users[i], 50_000_00)
	}

	wallStart := time.Now()
	latencies := make([]time.Duration, 0, N)

	type sub struct {
		payerID, receiverID string
	}
	subs := make([]sub, 0, N)

	for i := 0; i < N; i++ {
		payerIdx := rng.Intn(users)
		receiverIdx := rng.Intn(users)
		for receiverIdx == payerIdx {
			receiverIdx = rng.Intn(users)
		}
		payer := &e.users[payerIdx]
		receiver := &e.users[receiverIdx]
		amount := int64(100_00 + rng.Intn(200_00))
		if payer.ceiling == nil || payer.ceiling.CeilingAmount-payer.seq*amount < amount {
			e.ensureCeiling(ctx, payer, amount)
		}
		pt, ct := e.makePayment(payer, receiver, amount, time.Now().UTC())
		t0 := time.Now()
		if _, _, err := e.settle.SubmitClaim(ctx, receiver.id, []settlement.ClaimItem{{Payment: pt, Ceiling: ct}}); err != nil {
			t.Fatalf("submit %d: %v", i, err)
		}
		latencies = append(latencies, time.Since(t0))
		subs = append(subs, sub{payer.id, receiver.id})

		if time.Since(wallStart) > wallBudget {
			t.Fatalf("submission phase exceeded wall budget at i=%d", i)
		}
	}

	// Finalize each unique payer.
	payers := map[string]bool{}
	for _, s := range subs {
		payers[s.payerID] = true
	}
	settled, partial, rejected := 0, 0, 0
	var settledTotal int64
	for pid := range payers {
		results, err := e.settle.FinalizeForPayer(ctx, pid)
		if err != nil {
			t.Fatalf("finalize %s: %v", pid, err)
		}
		for _, r := range results {
			switch r.Status {
			case domain.TxSettled:
				settled++
				settledTotal += r.SettledAmount
			case domain.TxPartiallySettled:
				partial++
				settledTotal += r.SettledAmount
			case domain.TxRejected:
				rejected++
			}
		}
	}
	totalWall := time.Since(wallStart)

	sort.Slice(latencies, func(i, j int) bool { return latencies[i] < latencies[j] })
	p50 := latencies[len(latencies)*50/100]
	p95 := latencies[len(latencies)*95/100]
	p99 := latencies[len(latencies)*99/100]

	t.Logf("scale: N=%d users=%d wall=%s settled=%d partial=%d rejected=%d settled_total=%d",
		N, users, totalWall, settled, partial, rejected, settledTotal)
	t.Logf("scale: SubmitClaim latency p50=%s p95=%s p99=%s", p50, p95, p99)

	if totalWall > wallBudget {
		t.Fatalf("total wall time %s exceeded budget %s", totalWall, wallBudget)
	}
	if p99 > p99Budget {
		t.Fatalf("p99 SubmitClaim latency %s exceeded budget %s", p99, p99Budget)
	}

	global.add(N, settledTotal, partial, rejected, 0)
	global.mu.Lock()
	global.Tests = append(global.Tests, "TestScaleHundredK")
	global.Durations = append(global.Durations, p99)
	global.mu.Unlock()
}
