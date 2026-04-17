package domain

import "testing"

func TestTransactionStatus_CanTransitionTo(t *testing.T) {
	cases := []struct {
		name   string
		from   TransactionStatus
		to     TransactionStatus
		want   bool
	}{
		{"queued→submitted", TxQueued, TxSubmitted, true},
		{"queued→expired", TxQueued, TxExpired, true},
		{"queued→pending (skip)", TxQueued, TxPending, false},
		{"submitted→pending", TxSubmitted, TxPending, true},
		{"submitted→rejected", TxSubmitted, TxRejected, true},
		{"submitted→settled (skip)", TxSubmitted, TxSettled, false},
		{"pending→settled", TxPending, TxSettled, true},
		{"pending→partial", TxPending, TxPartiallySettled, true},
		{"pending→rejected", TxPending, TxRejected, true},
		{"pending→queued (backward)", TxPending, TxQueued, false},
		{"settled→anything (terminal)", TxSettled, TxPending, false},
		{"rejected→anything (terminal)", TxRejected, TxPending, false},
		{"partial→anything (terminal)", TxPartiallySettled, TxSettled, false},
		{"expired→anything (terminal)", TxExpired, TxSubmitted, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := c.from.CanTransitionTo(c.to); got != c.want {
				t.Fatalf("%s→%s: got %v, want %v", c.from, c.to, got, c.want)
			}
		})
	}
}

func TestTransactionStatus_IsTerminal(t *testing.T) {
	terminal := []TransactionStatus{TxSettled, TxPartiallySettled, TxRejected, TxExpired}
	for _, s := range terminal {
		if !s.IsTerminal() {
			t.Errorf("%s should be terminal", s)
		}
	}
	nonTerminal := []TransactionStatus{TxQueued, TxSubmitted, TxPending}
	for _, s := range nonTerminal {
		if s.IsTerminal() {
			t.Errorf("%s should not be terminal", s)
		}
	}
}
