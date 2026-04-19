package fraud

// Intrabank-transfer fraud scoring. This file lives alongside the existing
// ceiling-token signal service because both are "fraud" concerns and callers
// benefit from a single import path. The two surfaces are deliberately
// independent:
//
//   - Service (service.go) aggregates offline-ceiling fraud signals into a
//     decayed risk score and drives ceiling tiering.
//   - TransferService (this file) runs synchronous rule-based scoring inside
//     the transfer-accept tx and returns ALLOW / FLAG / BLOCK.
//
// Rule design:
//
//   - Every rule has the same signature: func(ctx, tx, in) (RuleHit, error).
//     A rule returning RuleHit{} (empty Name) did not trigger.
//   - The dispatcher iterates the rules slice in order. Adding rule #N+1 is
//     a one-line edit to `defaultRules`.
//   - Severity is combined across hits: any BLOCK wins; else any FLAG;
//     else ALLOW.
//   - Rules run inside the caller's pgx.Tx so counts are consistent with
//     the transfer being accepted (a concurrent sibling transfer on the
//     same sender will be serialised by the tx isolation level — we
//     deliberately do NOT take explicit row locks here; a false-negative
//     at the edge of a 60-second velocity window is acceptable).
//
// Performance budget: each rule MUST be sub-10ms. All DB queries use
// existing indexes — see 0018_transfers_and_outbox (sender_created_at).

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/oklog/ulid/v2"

	"github.com/intellect/offlinepay/internal/repository/fraudrepo"
)

// Decision levels.
const (
	DecisionAllow = "ALLOW"
	DecisionFlag  = "FLAG"
	DecisionBlock = "BLOCK"
)

// Severity labels, mirrored into RuleHit.
const (
	SeverityFlag  = "FLAG"
	SeverityBlock = "BLOCK"
)

// Rule names — stable identifiers used for metrics and audit queries.
const (
	RuleVelocitySender1m        = "velocity_sender_1m"
	RuleVelocitySender1h        = "velocity_sender_1h"
	RuleNewAccountLargeTransfer = "new_account_large_transfer"
	RuleNovelReceiverHighAmount = "novel_receiver_high_amount"
	RuleHighDailyShare          = "high_daily_share"
)

// Thresholds — collected as consts so a future config layer can override
// them without touching rule bodies.
const (
	// Velocity: > 10 transfers in 60s is BLOCK; > 50 in an hour is BLOCK.
	VelocityCount1m = 10
	VelocityCount1h = 50

	// New-account: < 24h old + > ₦20,000 transfer is FLAG.
	NewAccountAgeHours   int64 = 24
	NewAccountAmountKobo int64 = 20_000_00

	// Novel-receiver: never-before receiver + > ₦100,000 is FLAG.
	NovelReceiverAmountKobo int64 = 100_000_00

	// High daily share: would push today's total above 80% of tier limit.
	HighDailySharePercent = 80
)

// RuleHit is the output of a single rule. An empty Name means "no hit".
type RuleHit struct {
	Name     string `json:"name"`
	Severity string `json:"severity"` // FLAG or BLOCK
	Reason   string `json:"reason"`
}

// Score is the combined result of running every rule against one transfer.
// Decision is the final outcome; RuleHits carries every triggered rule for
// audit. Rule/Reason reflect the "dominant" hit (first BLOCK, else first
// FLAG) for convenient logging.
type Score struct {
	Decision string    `json:"decision"`
	Rule     string    `json:"rule,omitempty"`
	Reason   string    `json:"reason,omitempty"`
	RuleHits []RuleHit `json:"rule_hits,omitempty"`
}

// ScoreInput carries everything a rule can look at. Callers fill the fields
// they have; rules degrade gracefully when a value is zero/empty.
type ScoreInput struct {
	SenderUserID          string
	ReceiverUserID        string
	AmountKobo            int64
	SenderTier            string
	DailyTierLimitKobo    int64
	SenderAccountAgeHours int64
}

// Rule is the uniform signature every rule implements. Rules must be cheap
// (<10ms) and must use the supplied tx for any reads.
type Rule func(ctx context.Context, repo *fraudrepo.Repo, tx pgx.Tx, in ScoreInput) (RuleHit, error)

// TransferService runs the rule set against one transfer and records the
// decision. The repo handles the out-of-tx write path for BLOCK outcomes.
type TransferService struct {
	Repo  *fraudrepo.Repo
	rules []Rule
}

// NewTransferService constructs the service with the default rule set. To
// inject additional rules in tests, append to svc.rules after construction.
func NewTransferService(pool *pgxpool.Pool) *TransferService {
	return &TransferService{Repo: fraudrepo.New(pool), rules: defaultRules()}
}

// NewTransferServiceWithRepo lets callers inject a pre-built repo (tests
// mostly). Production code uses NewTransferService.
func NewTransferServiceWithRepo(repo *fraudrepo.Repo) *TransferService {
	return &TransferService{Repo: repo, rules: defaultRules()}
}

// AddRule registers an extra rule. Order matters for RuleHits but not for
// the final decision (severity dominates).
func (s *TransferService) AddRule(r Rule) { s.rules = append(s.rules, r) }

// defaultRules lists the rules that ship out of the box. A fraud engineer
// adding rule #6 only touches this function.
func defaultRules() []Rule {
	return []Rule{
		ruleVelocitySender1m,
		ruleVelocitySender1h,
		ruleNewAccountLargeTransfer,
		ruleNovelReceiverHighAmount,
		ruleHighDailyShare,
	}
}

// ScoreTransfer runs every rule against in and combines the outcomes. Rules
// execute inside the caller's tx so counts are consistent with the
// transfer being accepted. A rule that errors is NOT treated as a block —
// we log through the returned error and let the caller decide (the
// transfer service today fails closed, propagating the err up).
func (s *TransferService) ScoreTransfer(ctx context.Context, tx pgx.Tx, in ScoreInput) (Score, error) {
	if s == nil {
		return Score{Decision: DecisionAllow}, nil
	}
	var hits []RuleHit
	for _, r := range s.rules {
		hit, err := r(ctx, s.Repo, tx, in)
		if err != nil {
			return Score{}, fmt.Errorf("fraud rule: %w", err)
		}
		if hit.Name != "" {
			hits = append(hits, hit)
		}
	}
	decision := DecisionAllow
	var rule, reason string
	// First pass: any BLOCK wins.
	for _, h := range hits {
		if h.Severity == SeverityBlock {
			decision = DecisionBlock
			rule = h.Name
			reason = h.Reason
			break
		}
	}
	if decision == DecisionAllow {
		// Second pass: any FLAG promotes to FLAG.
		for _, h := range hits {
			if h.Severity == SeverityFlag {
				decision = DecisionFlag
				rule = h.Name
				reason = h.Reason
				break
			}
		}
	}
	return Score{Decision: decision, Rule: rule, Reason: reason, RuleHits: hits}, nil
}

// RecordScore writes a fraud_scores row. transferID is empty for BLOCK
// outcomes (no transfer row to attach to). The write runs inside the
// caller's tx when the decision is FLAG (so it commits with the transfer)
// and via the pool when the decision is BLOCK (transfer tx will be rolled
// back by the caller, but we still want the audit row).
func (s *TransferService) RecordScore(ctx context.Context, tx pgx.Tx, transferID string, in ScoreInput, score Score) error {
	if s == nil {
		return nil
	}
	if score.Decision == DecisionAllow {
		// Intentional: ALLOW is trace-only to keep the table small.
		return nil
	}
	hitsJSON, err := json.Marshal(score.RuleHits)
	if err != nil {
		return fmt.Errorf("marshal rule_hits: %w", err)
	}
	params := fraudrepo.InsertFraudScoreParams{
		ID:         newScoreID(),
		TransferID: transferID,
		SenderID:   in.SenderUserID,
		Decision:   score.Decision,
		Rule:       nullableStr(score.Rule),
		Reason:     nullableStr(score.Reason),
		RuleHits:   hitsJSON,
		AmountKobo: in.AmountKobo,
	}
	if score.Decision == DecisionBlock {
		// For BLOCK the caller's tx will rollback — we must write outside
		// of it so the audit row survives.
		if s.Repo == nil {
			return nil
		}
		return s.Repo.InsertFraudScore(ctx, params)
	}
	// FLAG: piggyback on the accept tx so the write commits atomically with
	// the transfer row.
	return s.Repo.InsertFraudScoreInTx(ctx, tx, params)
}

func nullableStr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func newScoreID() string {
	return strings.ToLower(ulid.MustNew(ulid.Timestamp(time.Now()), rand.Reader).String())
}

// ruleVelocitySender1m: BLOCK when the incoming transfer would push the
// sender's total over VelocityCount1m in the trailing 60 seconds. We count
// prior committed transfers and add one for the in-flight request, so the
// rule fires on the (VelocityCount1m+1)th attempt — matching the task's
// "11th of 11" acceptance spec. LIMIT caps scans at threshold+1.
func ruleVelocitySender1m(ctx context.Context, repo *fraudrepo.Repo, tx pgx.Tx, in ScoreInput) (RuleHit, error) {
	if in.SenderUserID == "" {
		return RuleHit{}, nil
	}
	prior, err := repo.CountRecentTransfersBySender(ctx, tx, in.SenderUserID, 60*time.Second, VelocityCount1m+1)
	if err != nil {
		return RuleHit{}, err
	}
	// prior+1 (the incoming transfer) > threshold  ⇔  prior >= threshold.
	if prior >= VelocityCount1m {
		return RuleHit{
			Name:     RuleVelocitySender1m,
			Severity: SeverityBlock,
			Reason:   fmt.Sprintf("velocity_spike: >%d transfers in 60s", VelocityCount1m),
		}, nil
	}
	return RuleHit{}, nil
}

// ruleVelocitySender1h: BLOCK when the incoming transfer would push the
// sender's hourly total past VelocityCount1h. Same inclusive-of-incoming
// semantics as the 1m rule above.
func ruleVelocitySender1h(ctx context.Context, repo *fraudrepo.Repo, tx pgx.Tx, in ScoreInput) (RuleHit, error) {
	if in.SenderUserID == "" {
		return RuleHit{}, nil
	}
	prior, err := repo.CountRecentTransfersBySender(ctx, tx, in.SenderUserID, time.Hour, VelocityCount1h+1)
	if err != nil {
		return RuleHit{}, err
	}
	if prior >= VelocityCount1h {
		return RuleHit{
			Name:     RuleVelocitySender1h,
			Severity: SeverityBlock,
			Reason:   fmt.Sprintf("velocity_spike: >%d transfers in 1h", VelocityCount1h),
		}, nil
	}
	return RuleHit{}, nil
}

// ruleNewAccountLargeTransfer: account age < 24h AND amount > ₦20,000 → FLAG.
// No DB query needed; the caller pre-fetches account age in the same tx.
func ruleNewAccountLargeTransfer(_ context.Context, _ *fraudrepo.Repo, _ pgx.Tx, in ScoreInput) (RuleHit, error) {
	if in.SenderAccountAgeHours <= 0 {
		return RuleHit{}, nil
	}
	if in.SenderAccountAgeHours < NewAccountAgeHours && in.AmountKobo > NewAccountAmountKobo {
		return RuleHit{
			Name:     RuleNewAccountLargeTransfer,
			Severity: SeverityFlag,
			Reason: fmt.Sprintf(
				"account_age=%dh amount=%d > threshold=%d",
				in.SenderAccountAgeHours, in.AmountKobo, NewAccountAmountKobo,
			),
		}, nil
	}
	return RuleHit{}, nil
}

// ruleNovelReceiverHighAmount: sender has never transferred to this
// receiver before AND amount > ₦100,000 → FLAG. Short-circuits on amount
// so cheap transfers skip the query entirely.
func ruleNovelReceiverHighAmount(ctx context.Context, repo *fraudrepo.Repo, tx pgx.Tx, in ScoreInput) (RuleHit, error) {
	if in.AmountKobo <= NovelReceiverAmountKobo {
		return RuleHit{}, nil
	}
	if in.SenderUserID == "" || in.ReceiverUserID == "" {
		return RuleHit{}, nil
	}
	seen, err := repo.ExistsTransferBetween(ctx, tx, in.SenderUserID, in.ReceiverUserID)
	if err != nil {
		return RuleHit{}, err
	}
	if !seen {
		return RuleHit{
			Name:     RuleNovelReceiverHighAmount,
			Severity: SeverityFlag,
			Reason: fmt.Sprintf(
				"first transfer to receiver at amount=%d (> %d)",
				in.AmountKobo, NovelReceiverAmountKobo,
			),
		}, nil
	}
	return RuleHit{}, nil
}

// ruleHighDailyShare: this transfer would push the day's cumulative total
// past HighDailySharePercent% of the tier's daily cap → FLAG. The transfer
// service already rejects 100%+ via ErrExceedsDailyLimit; this fires at
// 80% as a soft nudge for reviewers.
//
// We skip the rule when the tier limit is effectively unlimited (KYC3 uses
// math.MaxInt64) — the 80% threshold is meaningless and the multiplication
// would overflow.
func ruleHighDailyShare(ctx context.Context, repo *fraudrepo.Repo, tx pgx.Tx, in ScoreInput) (RuleHit, error) {
	if in.SenderUserID == "" || in.DailyTierLimitKobo <= 0 {
		return RuleHit{}, nil
	}
	// Guard against overflow on the unlimited tier (KYC3 = math.MaxInt64).
	// If the limit is already larger than 1e18 kobo, nobody's single-day
	// spend is crossing 80% of it in practice.
	if in.DailyTierLimitKobo > 1_000_000_000_000_000_000 {
		return RuleHit{}, nil
	}
	spentToday, err := repo.SumSenderTransfersToday(ctx, tx, in.SenderUserID)
	if err != nil {
		return RuleHit{}, err
	}
	projected := spentToday + in.AmountKobo
	threshold := (in.DailyTierLimitKobo * HighDailySharePercent) / 100
	if projected > threshold {
		return RuleHit{
			Name:     RuleHighDailyShare,
			Severity: SeverityFlag,
			Reason: fmt.Sprintf(
				"projected_today=%d > %d%% of daily_limit=%d",
				projected, HighDailySharePercent, in.DailyTierLimitKobo,
			),
		}, nil
	}
	return RuleHit{}, nil
}

// ErrRule is returned when a rule's DB call fails. Callers can wrap it
// with errors.Is to distinguish rule failures from business-level errors.
var ErrRule = errors.New("fraud: rule execution failed")
