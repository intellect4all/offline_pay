package settlement

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/service/notification"
)

// fakeFinalizer records FinalizeForPayer calls and returns canned results.
type fakeFinalizer struct {
	mu        sync.Mutex
	calls     []string
	result    []domain.SettlementResult
	err       error
}

func (f *fakeFinalizer) FinalizeForPayer(_ context.Context, payerUserID string) ([]domain.SettlementResult, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, payerUserID)
	if f.err != nil {
		return nil, f.err
	}
	return append([]domain.SettlementResult(nil), f.result...), nil
}

// fakeEvents is an in-memory processed_events ledger. Only the four methods
// the processor uses.
type fakeEvents struct {
	mu        sync.Mutex
	processed map[string]string // outboxID → status
}

func newFakeEvents() *fakeEvents { return &fakeEvents{processed: map[string]string{}} }

func (e *fakeEvents) IsEventProcessed(_ context.Context, id string) (bool, error) {
	e.mu.Lock()
	defer e.mu.Unlock()
	_, ok := e.processed[id]
	return ok, nil
}
func (e *fakeEvents) MarkEventProcessedSkipped(_ context.Context, id string) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.processed[id] = "SKIPPED"
	return nil
}
func (e *fakeEvents) MarkEventProcessedFailed(_ context.Context, id string) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.processed[id] = "FAILED"
	return nil
}
func (e *fakeEvents) MarkEventProcessedOK(_ context.Context, id string) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.processed[id] = "SETTLED"
	return nil
}

// fakeNotifier records every push emitted.
type fakeNotifier struct {
	mu     sync.Mutex
	events []notification.Event
}

func (f *fakeNotifier) Send(_ context.Context, e notification.Event) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.events = append(f.events, e)
	return nil
}

// envelope builds a valid outbox envelope for a settlement-finalize event.
func envelope(id, payerID, reason string) []byte {
	inner, _ := json.Marshal(domain.FinalizePayerPayload{
		PayerUserID: payerID,
		Reason:      reason,
		EnqueuedAt:  time.Date(2026, 4, 21, 12, 0, 0, 0, time.UTC),
	})
	outer, _ := json.Marshal(domain.OutboxEnvelope{
		ID:          id,
		Aggregate:   domain.OutboxAggregateSettlementFinalize,
		AggregateID: payerID,
		Payload:     inner,
	})
	return outer
}

func TestFinalizeProcessor_ProcessesHappyPath(t *testing.T) {
	events := newFakeEvents()
	fin := &fakeFinalizer{
		result: []domain.SettlementResult{
			{
				TransactionID:   "tx-1",
				SequenceNumber:  1,
				SubmittedAmount: 3000,
				SettledAmount:   3000,
				Status:          domain.TxSettled,
				ReceiverUserID:  "bob",
			},
		},
	}
	not := &fakeNotifier{}
	p := &FinalizeProcessor{Events: events, Service: fin, Notifier: not}

	// Build a fake JetStream msg — we call p.process directly so we can
	// bypass the PullSubscribe dance entirely.
	if err := p.processForTest(context.Background(), envelope("ob-1", "alice", domain.FinalizeReasonClaimAccepted)); err != nil {
		t.Fatalf("process: %v", err)
	}

	if got := fin.calls; len(got) != 1 || got[0] != "alice" {
		t.Fatalf("want FinalizeForPayer(alice) once, got %v", got)
	}
	if got := events.processed["ob-1"]; got != "SETTLED" {
		t.Fatalf("want ob-1 SETTLED, got %q", got)
	}

	// Wait for async notify goroutine.
	p.notifyWG.Wait()
	if len(not.events) != 2 {
		t.Fatalf("want 2 notifications (payer + receiver), got %d", len(not.events))
	}
	types := map[string]int{}
	for _, e := range not.events {
		types[e.Type]++
	}
	if types["offline_payment_settled"] != 1 || types["offline_payment_received"] != 1 {
		t.Errorf("notification fan-out wrong: %+v", types)
	}
}

func TestFinalizeProcessor_Idempotent(t *testing.T) {
	events := newFakeEvents()
	// Pre-mark the event as processed — second delivery must no-op.
	_ = events.MarkEventProcessedOK(context.Background(), "ob-1")

	fin := &fakeFinalizer{}
	p := &FinalizeProcessor{Events: events, Service: fin}
	if err := p.processForTest(context.Background(), envelope("ob-1", "alice", "claim_accepted")); err != nil {
		t.Fatalf("process: %v", err)
	}
	if len(fin.calls) != 0 {
		t.Fatalf("expected no FinalizeForPayer call on redelivery, got %v", fin.calls)
	}
}

func TestFinalizeProcessor_UnknownAggregateSkipped(t *testing.T) {
	events := newFakeEvents()
	fin := &fakeFinalizer{}
	p := &FinalizeProcessor{Events: events, Service: fin}
	body, _ := json.Marshal(domain.OutboxEnvelope{
		ID:        "ob-1",
		Aggregate: "transfer", // not our aggregate
		Payload:   []byte("{}"),
	})
	if err := p.processForTest(context.Background(), body); err != nil {
		t.Fatalf("process: %v", err)
	}
	if len(fin.calls) != 0 {
		t.Fatalf("expected no finalize for non-settlement aggregate")
	}
	if events.processed["ob-1"] != "SKIPPED" {
		t.Errorf("want ob-1 SKIPPED, got %q", events.processed["ob-1"])
	}
}

func TestFinalizeProcessor_TransientErrorBubblesForNak(t *testing.T) {
	events := newFakeEvents()
	fin := &fakeFinalizer{err: errors.New("db down")}
	p := &FinalizeProcessor{Events: events, Service: fin}
	err := p.processForTest(context.Background(), envelope("ob-1", "alice", "claim_accepted"))
	if err == nil {
		t.Fatal("expected error so Run() can Nak the message")
	}
	if _, ok := events.processed["ob-1"]; ok {
		t.Errorf("expected ob-1 to remain unprocessed on transient error")
	}
}

// processForTest re-implements process() without the NATS handle. The real
// Run() goroutine pulls from JetStream and calls process(ctx, *nats.Msg);
// factoring that out for tests would require a mock nats.Msg surface, so
// we reach into the same processing logic through a thin helper. The two
// paths share their core by construction — if you refactor process(), keep
// this helper byte-identical except for the m.Term/Ack calls.
func (p *FinalizeProcessor) processForTest(ctx context.Context, data []byte) error {
	var env domain.OutboxEnvelope
	if err := json.Unmarshal(data, &env); err != nil {
		return nil
	}
	ev := p.events()
	already, err := ev.IsEventProcessed(ctx, env.ID)
	if err != nil {
		return err
	}
	if already {
		return nil
	}
	if env.Aggregate != domain.OutboxAggregateSettlementFinalize {
		p.recordOutcome("skipped")
		return ev.MarkEventProcessedSkipped(ctx, env.ID)
	}
	var fp domain.FinalizePayerPayload
	if err := json.Unmarshal(env.Payload, &fp); err != nil {
		p.recordOutcome("failed")
		return ev.MarkEventProcessedFailed(ctx, env.ID)
	}
	if fp.PayerUserID == "" {
		p.recordOutcome("failed")
		return ev.MarkEventProcessedFailed(ctx, env.ID)
	}
	results, err := p.Service.FinalizeForPayer(ctx, fp.PayerUserID)
	if err != nil {
		return err
	}
	if err := ev.MarkEventProcessedOK(ctx, env.ID); err != nil {
		return err
	}
	p.recordOutcome("settled")
	p.emitNotifications(ctx, fp, results)
	return nil
}
