package gossip

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/intellect/offlinepay/internal/crypto"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/service/settlement"
)

type fakeSubmitter struct {
	mu sync.Mutex
	// seen tracks (payer_id, sequence_number) for idempotency simulation.
	seen map[string]bool
	// callLog records each SubmitClaim invocation for assertions.
	callLog []fakeCall
}

type fakeCall struct {
	ReceiverUserID string
	Items          []settlement.ClaimItem
}

func newFakeSubmitter() *fakeSubmitter {
	return &fakeSubmitter{seen: map[string]bool{}}
}

func (f *fakeSubmitter) SubmitClaim(_ context.Context, receiverUserID string, batch []settlement.ClaimItem, _ ...settlement.SubmitOption) (domain.SettlementBatch, []domain.SettlementResult, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.callLog = append(f.callLog, fakeCall{ReceiverUserID: receiverUserID, Items: batch})
	results := make([]domain.SettlementResult, 0, len(batch))
	for _, it := range batch {
		key := it.Payment.PayerID + "|"
		// include seq
		key += itoa(it.Payment.SequenceNumber)
		if f.seen[key] {
			// idempotent duplicate: settlement returns existing state with
			// no new ledger posting. We model that as TxPending.
			results = append(results, domain.SettlementResult{
				TransactionID:   "existing-" + key,
				SequenceNumber:  it.Payment.SequenceNumber,
				SubmittedAmount: it.Payment.Amount,
				Status:          domain.TxPending,
			})
			continue
		}
		f.seen[key] = true
		results = append(results, domain.SettlementResult{
			TransactionID:   "new-" + key,
			SequenceNumber:  it.Payment.SequenceNumber,
			SubmittedAmount: it.Payment.Amount,
			Status:          domain.TxPending,
		})
	}
	return domain.SettlementBatch{ID: "batch-1", ReceiverID: receiverUserID}, results, nil
}

func itoa(n int64) string {
	// avoid pulling strconv into test just for test helper
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var buf [32]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}

type fixture struct {
	serverPub, serverPriv *[32]byte
	bankPub               ed25519.PublicKey
	bankPriv              ed25519.PrivateKey
	payerPub              ed25519.PublicKey
	payerPriv             ed25519.PrivateKey
	ceilingID             string
	ceilingPayload        domain.CeilingTokenPayload
	ceilingSig            []byte
}

func newFixture(t *testing.T) fixture {
	t.Helper()
	spub, spriv, err := crypto.GenerateSealedBoxKeyPair()
	if err != nil {
		t.Fatal(err)
	}
	bpub, bpriv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	pppub, pppriv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	issued := time.Date(2026, 4, 14, 10, 0, 0, 0, time.UTC)
	cp := domain.CeilingTokenPayload{
		PayerID:        "user-payer",
		CeilingAmount:  500000,
		IssuedAt:       issued,
		ExpiresAt:      issued.Add(24 * time.Hour),
		SequenceStart:  0,
		PayerPublicKey: pppub,
		BankKeyID:      "bank-key-1",
	}
	sig, err := crypto.SignCeiling(bpriv, cp)
	if err != nil {
		t.Fatal(err)
	}
	return fixture{
		serverPub: spub, serverPriv: spriv,
		bankPub: bpub, bankPriv: bpriv,
		payerPub: pppub, payerPriv: pppriv,
		ceilingID:      "ceil-1",
		ceilingPayload: cp,
		ceilingSig:     sig,
	}
}

// makeBlob builds a valid sealed gossip blob for the given payment details.
func (fx fixture) makeBlob(t *testing.T, seq int64, amount int64, payeeID string) domain.GossipBlob {
	t.Helper()
	seedNonce := sha256.Sum256([]byte(fmt.Sprintf("nonce|%s|%s|%d", fx.ceilingID, payeeID, seq)))
	seedHash := sha256.Sum256([]byte(fmt.Sprintf("reqhash|%s|%s|%d", fx.ceilingID, payeeID, seq)))
	pp := domain.PaymentPayload{
		PayerID:          fx.ceilingPayload.PayerID,
		PayeeID:          payeeID,
		Amount:           amount,
		SequenceNumber:   seq,
		RemainingCeiling: fx.ceilingPayload.CeilingAmount - amount,
		Timestamp:        fx.ceilingPayload.IssuedAt.Add(5 * time.Minute),
		CeilingTokenID:   fx.ceilingID,
		SessionNonce:     seedNonce[:domain.SessionNonceSize],
		RequestHash:      seedHash[:],
	}
	psig, err := crypto.SignPayment(fx.payerPriv, pp)
	if err != nil {
		t.Fatal(err)
	}
	paymentTok := domain.PaymentToken{
		PayerID:          pp.PayerID,
		PayeeID:          pp.PayeeID,
		Amount:           pp.Amount,
		SequenceNumber:   pp.SequenceNumber,
		RemainingCeiling: pp.RemainingCeiling,
		Timestamp:        pp.Timestamp,
		CeilingTokenID:   pp.CeilingTokenID,
		SessionNonce:     pp.SessionNonce,
		RequestHash:      pp.RequestHash,
		PayerSignature:   psig,
	}

	inner := WireInnerPayload{
		Ceiling: CeilingTokenWire{
			ID:            fx.ceilingID,
			Payload:       fx.ceilingPayload,
			BankSignature: fx.ceilingSig,
		},
		Payment:      paymentTok,
		SenderUserID: payeeID,
	}
	pt, err := EncodeInner(inner)
	if err != nil {
		t.Fatal(err)
	}
	ct, err := crypto.SealAnonymous(fx.serverPub, pt)
	if err != nil {
		t.Fatal(err)
	}
	txHash := sha256.Sum256(pt)
	ctHashInput, err := crypto.Canonicalize(fx.ceilingPayload)
	if err != nil {
		t.Fatal(err)
	}
	ctHash := sha256.Sum256(ctHashInput)
	return domain.GossipBlob{
		TransactionHash:  txHash[:],
		EncryptedBlob:    ct,
		BankSignature:    fx.ceilingSig,
		CeilingTokenHash: ctHash[:],
		HopCount:         0,
		BlobSize:         len(ct),
	}
}

func TestUpload_SingleValidBlobTriggersOneSubmitClaim(t *testing.T) {
	fx := newFixture(t)
	fake := newFakeSubmitter()
	svc := New(fake, SealedBoxKeys{Public: fx.serverPub, Private: fx.serverPriv})

	blob := fx.makeBlob(t, 1, 25000, "user-payee")

	out, err := svc.Upload(context.Background(), "user-carrier", []domain.GossipBlob{blob})
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	if out.Accepted != 1 || out.Rejected != 0 {
		t.Fatalf("want accepted=1 rejected=0, got %+v", out)
	}
	if len(fake.callLog) != 1 {
		t.Fatalf("want 1 SubmitClaim call, got %d", len(fake.callLog))
	}
	if fake.callLog[0].ReceiverUserID != "user-payee" {
		t.Fatalf("want receiver=user-payee, got %s", fake.callLog[0].ReceiverUserID)
	}
	if n := len(fake.callLog[0].Items); n != 1 {
		t.Fatalf("want 1 claim item, got %d", n)
	}
	item := fake.callLog[0].Items[0]
	if item.Payment.SequenceNumber != 1 || item.Payment.Amount != 25000 {
		t.Fatalf("unexpected payment: %+v", item.Payment)
	}
	if item.Ceiling.ID != fx.ceilingID {
		t.Fatalf("ceiling id mismatch: %s", item.Ceiling.ID)
	}
}

func TestUpload_DuplicateBlobsDedupe(t *testing.T) {
	fx := newFixture(t)
	fake := newFakeSubmitter()
	svc := New(fake, SealedBoxKeys{Public: fx.serverPub, Private: fx.serverPriv})

	blob := fx.makeBlob(t, 7, 15000, "user-payee")

	// First upload.
	if _, err := svc.Upload(context.Background(), "user-carrier-1", []domain.GossipBlob{blob}); err != nil {
		t.Fatal(err)
	}
	// Second upload, same blob — should hit idempotency path.
	out, err := svc.Upload(context.Background(), "user-carrier-2", []domain.GossipBlob{blob})
	if err != nil {
		t.Fatal(err)
	}
	if out.Accepted != 1 {
		t.Fatalf("duplicate should still accept (idempotent); got %+v", out)
	}
	if len(fake.callLog) != 2 {
		t.Fatalf("want 2 SubmitClaim calls (both forwarded), got %d", len(fake.callLog))
	}
	// The second result must indicate idempotent path: TransactionID prefixed "existing-".
	if got := out.Items[0].SettlementResult; got == nil || got.TransactionID == "" {
		t.Fatalf("missing settlement result")
	} else if !contains(got.TransactionID, "existing-") {
		t.Fatalf("want dedup TransactionID, got %s", got.TransactionID)
	}
}

func TestUpload_HopLimitExceededRejected(t *testing.T) {
	fx := newFixture(t)
	fake := newFakeSubmitter()
	svc := New(fake, SealedBoxKeys{Public: fx.serverPub, Private: fx.serverPriv})

	blob := fx.makeBlob(t, 1, 10000, "user-payee")
	blob.HopCount = domain.MaxGossipHops + 1

	out, err := svc.Upload(context.Background(), "carrier", []domain.GossipBlob{blob})
	if err != nil {
		t.Fatal(err)
	}
	if out.Accepted != 0 || out.Rejected != 1 {
		t.Fatalf("want accepted=0 rejected=1, got %+v", out)
	}
	if err := out.Items[0].Err; !errors.Is(err, ErrBlobHopLimitExceeded) && !errors.Is(err, domain.ErrInvalidGossipBlob) {
		t.Fatalf("want hop-limit error, got %v", err)
	}
	if len(fake.callLog) != 0 {
		t.Fatalf("want 0 SubmitClaim calls, got %d", len(fake.callLog))
	}
}

func TestUpload_TamperedBlobReportedButBatchContinues(t *testing.T) {
	fx := newFixture(t)
	fake := newFakeSubmitter()
	svc := New(fake, SealedBoxKeys{Public: fx.serverPub, Private: fx.serverPriv})

	good1 := fx.makeBlob(t, 1, 10000, "user-payee")
	bad := fx.makeBlob(t, 2, 20000, "user-payee")
	// Flip a byte deep inside the ciphertext (after the 32-byte eph pub).
	bad.EncryptedBlob[40] ^= 0xFF
	good2 := fx.makeBlob(t, 3, 30000, "user-payee")

	out, err := svc.Upload(context.Background(), "carrier", []domain.GossipBlob{good1, bad, good2})
	if err != nil {
		t.Fatal(err)
	}
	if out.Accepted != 2 || out.Rejected != 1 {
		t.Fatalf("want accepted=2 rejected=1, got %+v", out)
	}
	if !errors.Is(out.Items[1].Err, ErrBadBlob) {
		t.Fatalf("want middle blob ErrBadBlob, got %v", out.Items[1].Err)
	}
	if len(fake.callLog) != 2 {
		t.Fatalf("want 2 SubmitClaim calls, got %d", len(fake.callLog))
	}
}

func TestUpload_KeyringAcceptsRetiredKey(t *testing.T) {
	fx := newFixture(t)
	// Blob was sealed to fx.serverPub (which will be "previous" after rotation).
	blob := fx.makeBlob(t, 1, 25000, "user-payee")

	// New "current" keypair — blob was NOT sealed to this one.
	newPub, newPriv, err := crypto.GenerateSealedBoxKeyPair()
	if err != nil {
		t.Fatal(err)
	}
	retiredAt := time.Date(2026, 5, 14, 0, 0, 0, 0, time.UTC)
	kr := SealedBoxKeyring{
		Current: SealedBoxKey{KeyID: "sb-2", Public: newPub, Private: newPriv},
		Previous: []SealedBoxKey{
			{KeyID: "sb-1", Public: fx.serverPub, Private: fx.serverPriv, RetiredAt: &retiredAt},
		},
	}
	fake := newFakeSubmitter()
	svc := New(fake, kr)

	out, err := svc.Upload(context.Background(), "carrier", []domain.GossipBlob{blob})
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	if out.Accepted != 1 || out.Rejected != 0 {
		t.Fatalf("want accepted=1 rejected=0, got %+v", out)
	}
}

func TestUpload_KeyringRejectsUnknownKey(t *testing.T) {
	fx := newFixture(t)
	blob := fx.makeBlob(t, 1, 25000, "user-payee")

	// Keyring with neither current nor previous matching the blob's sealer.
	aPub, aPriv, err := crypto.GenerateSealedBoxKeyPair()
	if err != nil {
		t.Fatal(err)
	}
	bPub, bPriv, err := crypto.GenerateSealedBoxKeyPair()
	if err != nil {
		t.Fatal(err)
	}
	kr := SealedBoxKeyring{
		Current: SealedBoxKey{KeyID: "a", Public: aPub, Private: aPriv},
		Previous: []SealedBoxKey{
			{KeyID: "b", Public: bPub, Private: bPriv},
		},
	}
	// silence unused fixture sealed keys
	_ = fx.serverPub
	_ = fx.serverPriv

	fake := newFakeSubmitter()
	svc := New(fake, kr)

	out, err := svc.Upload(context.Background(), "carrier", []domain.GossipBlob{blob})
	if err != nil {
		t.Fatal(err)
	}
	if out.Accepted != 0 || out.Rejected != 1 {
		t.Fatalf("want accepted=0 rejected=1, got %+v", out)
	}
	if !errors.Is(out.Items[0].Err, ErrBadBlob) {
		t.Fatalf("want ErrBadBlob, got %v", out.Items[0].Err)
	}
	if len(fake.callLog) != 0 {
		t.Fatalf("want 0 SubmitClaim calls, got %d", len(fake.callLog))
	}
}

// tiny helper to avoid importing strings.
func contains(s, sub string) bool {
	if len(sub) > len(s) {
		return false
	}
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
