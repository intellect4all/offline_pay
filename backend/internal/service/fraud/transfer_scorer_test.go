package fraud

// Unit tests for the rule-based transfer scorer. These exercise the pure
// in-memory rules (ruleNewAccountLargeTransfer) and the decision-combining
// dispatcher. Rules that need pg (velocity, novel-receiver, high-daily-
// share) are covered in transfer_scorer_integration_test.go.

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5"

	"github.com/intellect/offlinepay/internal/repository/fraudrepo"
)

func TestRuleNewAccountLargeTransfer(t *testing.T) {
	ctx := context.Background()
	cases := []struct {
		name string
		age  int64
		amt  int64
		want string
	}{
		{"fresh + big: flag", 2, 25_000_00, RuleNewAccountLargeTransfer},
		{"fresh + small: allow", 2, 10_000_00, ""},
		{"old + big: allow", 100, 25_000_00, ""},
		{"at threshold (age=24): allow", 24, 25_000_00, ""},
		{"at amount threshold: allow", 10, 20_000_00, ""},
		{"just over amount: flag", 10, 20_000_01, RuleNewAccountLargeTransfer},
		{"zero age (unknown): allow", 0, 50_000_00, ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			hit, err := ruleNewAccountLargeTransfer(ctx, nil, nil, ScoreInput{
				SenderAccountAgeHours: c.age, AmountKobo: c.amt,
			})
			if err != nil {
				t.Fatalf("rule error: %v", err)
			}
			if hit.Name != c.want {
				t.Errorf("hit.Name = %q want %q", hit.Name, c.want)
			}
			if c.want != "" && hit.Severity != SeverityFlag {
				t.Errorf("severity = %q want FLAG", hit.Severity)
			}
		})
	}
}

// TestScoreTransfer_DecisionCombining walks every outcome-combining path
// with stub rules, verifying: (a) BLOCK dominates FLAG, (b) FLAG dominates
// ALLOW, (c) rule errors propagate, (d) the first matching rule of a
// severity populates Rule/Reason.
func TestScoreTransfer_DecisionCombining(t *testing.T) {
	ctx := context.Background()
	ruleAllow := func(context.Context, *fraudrepo.Repo, pgx.Tx, ScoreInput) (RuleHit, error) {
		return RuleHit{}, nil
	}
	ruleFlagA := func(context.Context, *fraudrepo.Repo, pgx.Tx, ScoreInput) (RuleHit, error) {
		return RuleHit{Name: "flag_a", Severity: SeverityFlag, Reason: "ra"}, nil
	}
	ruleFlagB := func(context.Context, *fraudrepo.Repo, pgx.Tx, ScoreInput) (RuleHit, error) {
		return RuleHit{Name: "flag_b", Severity: SeverityFlag, Reason: "rb"}, nil
	}
	ruleBlock := func(context.Context, *fraudrepo.Repo, pgx.Tx, ScoreInput) (RuleHit, error) {
		return RuleHit{Name: "block", Severity: SeverityBlock, Reason: "rc"}, nil
	}

	t.Run("all allow → ALLOW", func(t *testing.T) {
		svc := &TransferService{rules: []Rule{ruleAllow, ruleAllow}}
		got, err := svc.ScoreTransfer(ctx, nil, ScoreInput{})
		if err != nil {
			t.Fatalf("err: %v", err)
		}
		if got.Decision != DecisionAllow || got.Rule != "" || len(got.RuleHits) != 0 {
			t.Errorf("want allow/empty, got %+v", got)
		}
	})

	t.Run("any flag → FLAG, first wins", func(t *testing.T) {
		svc := &TransferService{rules: []Rule{ruleAllow, ruleFlagA, ruleFlagB}}
		got, err := svc.ScoreTransfer(ctx, nil, ScoreInput{})
		if err != nil {
			t.Fatalf("err: %v", err)
		}
		if got.Decision != DecisionFlag {
			t.Errorf("decision = %s want FLAG", got.Decision)
		}
		if got.Rule != "flag_a" || got.Reason != "ra" {
			t.Errorf("dominant = %s/%s, want flag_a/ra", got.Rule, got.Reason)
		}
		if len(got.RuleHits) != 2 {
			t.Errorf("rule_hits = %d want 2", len(got.RuleHits))
		}
	})

	t.Run("block dominates flag", func(t *testing.T) {
		// Order matters for RuleHits but not for Decision.
		svc := &TransferService{rules: []Rule{ruleFlagA, ruleBlock, ruleFlagB}}
		got, err := svc.ScoreTransfer(ctx, nil, ScoreInput{})
		if err != nil {
			t.Fatalf("err: %v", err)
		}
		if got.Decision != DecisionBlock {
			t.Errorf("decision = %s want BLOCK", got.Decision)
		}
		if got.Rule != "block" {
			t.Errorf("rule = %s want block", got.Rule)
		}
		if len(got.RuleHits) != 3 {
			t.Errorf("rule_hits = %d want 3", len(got.RuleHits))
		}
	})

	t.Run("rule error propagates", func(t *testing.T) {
		boom := func(context.Context, *fraudrepo.Repo, pgx.Tx, ScoreInput) (RuleHit, error) {
			return RuleHit{}, context.DeadlineExceeded
		}
		svc := &TransferService{rules: []Rule{ruleAllow, boom}}
		_, err := svc.ScoreTransfer(ctx, nil, ScoreInput{})
		if err == nil {
			t.Fatalf("want error, got nil")
		}
	})
}

// TestAddRule_AppendsToDefault verifies the doc'd extension path: a caller
// with a fresh TransferService can drop in an additional rule without
// touching the dispatcher.
func TestAddRule_AppendsToDefault(t *testing.T) {
	ctx := context.Background()
	custom := func(context.Context, *fraudrepo.Repo, pgx.Tx, ScoreInput) (RuleHit, error) {
		return RuleHit{Name: "custom", Severity: SeverityFlag, Reason: "r"}, nil
	}
	svc := &TransferService{rules: []Rule{}}
	svc.AddRule(custom)
	got, err := svc.ScoreTransfer(ctx, nil, ScoreInput{})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if got.Decision != DecisionFlag || got.Rule != "custom" {
		t.Errorf("decision=%s rule=%s, want FLAG/custom", got.Decision, got.Rule)
	}
}
