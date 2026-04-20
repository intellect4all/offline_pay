//go:build integration

// Integration tests for the fraud-scoring hook wired into InitiateTransfer.
// Verifies the 11-in-60s BLOCK path and the fresh-user-large-amount FLAG
// path end-to-end (transfer row written, fraud_scores row persisted).
//
// Run with:
//
//	go test -tags=integration ./internal/service/transfer/...
package transfer

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/intellect/offlinepay/internal/service/fraud"
)

// TestInitiateTransfer_FraudVelocityBlocksEleventh fires 11 transfers
// within a second from the same sender. The first 10 accept; the 11th
// trips velocity_sender_1m and returns ErrFraudBlocked. A BLOCK row must
// land in fraud_scores with an empty transfer_id.
func TestInitiateTransfer_FraudVelocityBlocksEleventh(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	fraudSvc := fraud.NewTransferService(pool)
	svc := New(pool, nil, fraudSvc)

	// Seed two old KYC3 users so velocity is the only rule that can fire
	// (KYC3 has unlimited daily, large amount is fine for the tier, and
	// the account is not fresh — new-account-large-transfer stays silent).
	insertUser(t, pool, "alice", "+2348100000001", "8100000001", TierThree)
	insertUser(t, pool, "bob", "+2348100000002", "8100000002", TierThree)
	// Backdate alice's created_at so the new-account rule doesn't fire.
	_, err := pool.Exec(ctx,
		`UPDATE users SET created_at = now() - interval '90 days' WHERE id = 'alice'`)
	if err != nil {
		t.Fatalf("backdate: %v", err)
	}

	for i := 0; i < 10; i++ {
		_, err := svc.InitiateTransfer(ctx, InitiateTransferInput{
			SenderUserID:          "alice",
			ReceiverAccountNumber: "8100000002",
			AmountKobo:            100_00,
			Reference:             fmt.Sprintf("vtest-%d-%d", i, time.Now().UnixNano()),
		})
		if err != nil {
			t.Fatalf("transfer %d: %v", i, err)
		}
	}
	_, err = svc.InitiateTransfer(ctx, InitiateTransferInput{
		SenderUserID:          "alice",
		ReceiverAccountNumber: "8100000002",
		AmountKobo:            100_00,
		Reference:             fmt.Sprintf("vtest-11-%d", time.Now().UnixNano()),
	})
	if !errors.Is(err, ErrFraudBlocked) {
		t.Fatalf("11th transfer: want ErrFraudBlocked, got %v", err)
	}

	var blockCount int
	if err := pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM fraud_scores WHERE sender_id = 'alice' AND decision = 'BLOCK'`,
	).Scan(&blockCount); err != nil {
		t.Fatalf("count block rows: %v", err)
	}
	if blockCount < 1 {
		t.Errorf("fraud_scores block rows = %d want >=1", blockCount)
	}

	// Also assert no transfer_id populated on the block row (tx rolled back).
	var tid string
	if err := pool.QueryRow(ctx,
		`SELECT transfer_id FROM fraud_scores
		 WHERE sender_id = 'alice' AND decision = 'BLOCK'
		 ORDER BY created_at DESC LIMIT 1`).Scan(&tid); err != nil {
		t.Fatalf("select tid: %v", err)
	}
	if tid != "" {
		t.Errorf("block row transfer_id = %q want empty", tid)
	}
}

// TestInitiateTransfer_FraudFlagsFreshLargeAmount: a sub-24h KYC3 sender
// moving ₦25k is accepted, but the transfer row carries flagged=true and
// a FLAG row in fraud_scores references it by transfer_id.
func TestInitiateTransfer_FraudFlagsFreshLargeAmount(t *testing.T) {
	ctx := context.Background()
	pool, cleanup := startPostgres(t, ctx)
	defer cleanup()

	fraudSvc := fraud.NewTransferService(pool)
	svc := New(pool, nil, fraudSvc)

	// Alice is a freshly-created KYC3 (picked so tier limits don't get in
	// the way) account; Bob is old so receiver rules are quiet.
	insertUser(t, pool, "alice", "+2348100000001", "8100000001", TierThree)
	insertUser(t, pool, "bob", "+2348100000002", "8100000002", TierThree)
	_, err := pool.Exec(ctx,
		`UPDATE users SET created_at = now() - interval '1 hour' WHERE id = 'alice'`)
	if err != nil {
		t.Fatalf("set fresh: %v", err)
	}

	tr, err := svc.InitiateTransfer(ctx, InitiateTransferInput{
		SenderUserID:          "alice",
		ReceiverAccountNumber: "8100000002",
		AmountKobo:            25_000_00,
		Reference:             newRef(t, "flag-fresh"),
	})
	if err != nil {
		t.Fatalf("initiate: %v", err)
	}
	if tr.Status != "ACCEPTED" {
		t.Fatalf("status = %s want ACCEPTED", tr.Status)
	}

	var flagged bool
	if err := pool.QueryRow(ctx,
		`SELECT flagged FROM transfers WHERE id = $1`, tr.ID).Scan(&flagged); err != nil {
		t.Fatalf("select flagged: %v", err)
	}
	if !flagged {
		t.Errorf("transfer.flagged = false, want true")
	}

	var decision string
	var tid string
	if err := pool.QueryRow(ctx,
		`SELECT decision, transfer_id FROM fraud_scores
		 WHERE sender_id = 'alice' ORDER BY created_at DESC LIMIT 1`,
	).Scan(&decision, &tid); err != nil {
		t.Fatalf("select fraud_scores: %v", err)
	}
	if decision != fraud.DecisionFlag {
		t.Errorf("decision = %s want FLAG", decision)
	}
	if tid != tr.ID {
		t.Errorf("transfer_id = %q want %q", tid, tr.ID)
	}
}
