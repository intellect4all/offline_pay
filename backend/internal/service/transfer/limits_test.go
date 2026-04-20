package transfer

import (
	"math"
	"testing"
)

// TestLimitsForTier pins the exact kobo values for each tier. If these
// numbers change, that's a compliance-relevant policy change — this test
// exists to make it loud in code review.
func TestLimitsForTier(t *testing.T) {
	cases := []struct {
		name       string
		tier       string
		wantSingle int64
		wantDaily  int64
	}{
		{"tier_0 blocks all", TierZero, 0, 0},
		{"unknown defaults to blocked", "GIBBERISH", 0, 0},
		{"empty defaults to blocked", "", 0, 0},
		{"tier_1 small ceiling", TierOne, 10_000_00, 30_000_00},
		{"tier_2 matches CBN Tier 1", TierTwo, 50_000_00, 300_000_00},
		{"tier_3 effectively unlimited", TierThree, math.MaxInt64, math.MaxInt64},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := LimitsForTier(c.tier)
			if got.SingleMaxKobo != c.wantSingle {
				t.Errorf("SingleMaxKobo: got %d want %d", got.SingleMaxKobo, c.wantSingle)
			}
			if got.DailyMaxKobo != c.wantDaily {
				t.Errorf("DailyMaxKobo: got %d want %d", got.DailyMaxKobo, c.wantDaily)
			}
		})
	}
}
