// KYC-tier transaction limits for intrabank transfers.
//
// Nigeria's CBN (Central Bank of Nigeria) Tier 1 BVN framework caps per-tier
// single-transaction and cumulative daily limits. This file encodes the
// production-aligned ceilings so a user with no KYC cannot drain the rails
// and a fully-verified user gets effectively unlimited movement.
//
// All amounts are in kobo (int64). Naira values shown in comments for
// readability. These constants are the floor — real deployments should
// drive them from config/feature-flags so compliance can tune without a
// redeploy.
//
package transfer

import (
	"errors"
	"math"
)

// TierLimits captures the per-transaction and per-day ceilings for a
// given KYC tier. Zero values mean "blocked" — no transfer of any size is
// permitted.
type TierLimits struct {
	SingleMaxKobo int64
	DailyMaxKobo  int64
}

// KYC tier strings persisted in users.kyc_tier. Values match the CHECK
// constraint in migration 0019_user_profile.
//
// Semantics in this product:
//
//	TIER_0 — phone only (no name/email; legacy/device-registered rows)
//	TIER_1 — phone + first/last name + email (default post-signup)
//	TIER_2 — NIN verified
//	TIER_3 — BVN verified
//
// CBN single/daily caps are mapped to TIER_2/3 since those include a
// government ID. TIER_1 (signup-only) gets a small send-ceiling; TIER_0
// cannot send.
const (
	TierZero  = "TIER_0"
	TierOne   = "TIER_1"
	TierTwo   = "TIER_2"
	TierThree = "TIER_3"
)

// LimitsForTier returns the TierLimits for a known tier string. Unknown
// tiers fall back to TIER_0 (safer default: an unrecognised string must
// not authorise movement). Matching is exact — callers should pass the
// value read from users.kyc_tier verbatim.
func LimitsForTier(tier string) TierLimits {
	switch tier {
	case TierOne:
		// Post-signup only (no NIN/BVN) — minimal send-ceiling to
		// reduce blast radius from credential-stuffing.
		return TierLimits{
			SingleMaxKobo: 10_000_00,
			DailyMaxKobo:  30_000_00,
		}
	case TierTwo:
		// NIN verified — CBN Tier 1 headroom: ₦50,000 / ₦300,000.
		return TierLimits{
			SingleMaxKobo: 50_000_00,
			DailyMaxKobo:  300_000_00,
		}
	case TierThree:
		// BVN verified — effectively unlimited (bank-set in prod).
		return TierLimits{
			SingleMaxKobo: math.MaxInt64,
			DailyMaxKobo:  math.MaxInt64,
		}
	case TierZero:
		fallthrough
	default:
		// Blocks all transfers. Callers must check SingleMaxKobo == 0
		// and return ErrTierBlocked.
		return TierLimits{SingleMaxKobo: 0, DailyMaxKobo: 0}
	}
}

// Limit-check errors. InitiateTransfer returns these before any outbox
// write so a quota-exceeding transfer never lands in the ledger.
var (
	ErrTierBlocked        = errors.New("transfer: kyc tier does not permit sending — complete kyc")
	ErrExceedsSingleLimit = errors.New("transfer: amount exceeds single-transaction limit for tier")
	ErrExceedsDailyLimit  = errors.New("transfer: amount exceeds daily cumulative limit for tier")
)
