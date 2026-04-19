
package settlement

import (
	"context"
	"crypto/ed25519"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"time"

	"github.com/intellect/offlinepay/internal/crypto"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

// Sentinel errors.
var (
	ErrSelfPay                = errors.New("settlement: payer_id == payee_id")
	ErrCeilingExpired         = errors.New("settlement: ceiling expired past grace window")
	ErrCeilingRevoked         = errors.New("settlement: ceiling terminated server-side (revoked/expired/exhausted)")
	ErrCeilingRecoveryClosed  = errors.New("settlement: ceiling in recovery; release window has closed")
	ErrBadBankSignature       = errors.New("settlement: ceiling bank signature invalid")
	ErrBadPayerSignature      = errors.New("settlement: payment payer signature invalid")
	ErrBadReceiverSignature   = errors.New("settlement: payment request receiver signature invalid")
	ErrBadDisplayCardSig      = errors.New("settlement: display card server signature invalid")
	ErrSequenceBelowStart     = errors.New("settlement: sequence_number <= ceiling.sequence_start")
	ErrCeilingMismatch        = errors.New("settlement: payment.ceiling_token_id does not match provided ceiling")
	ErrPayerIDMismatch        = errors.New("settlement: payment.payer_id does not match ceiling.payer_id")
	ErrSubmitterNotParty      = errors.New("settlement: submitter is not the payer or the payee on the token")
	ErrRequestReceiverMismatch = errors.New("settlement: request.receiver_id does not match payment.payee_id")
	ErrRequestNonceMismatch   = errors.New("settlement: payment.session_nonce does not match request.session_nonce")
	ErrRequestHashMismatch    = errors.New("settlement: payment.request_hash does not match hash(request)")
	ErrRequestAmountMismatch  = errors.New("settlement: payment.amount does not match request.amount")
	ErrRequestExpired         = errors.New("settlement: payment request expired past grace window")
	ErrRequestDisplayCardUser = errors.New("settlement: display_card.user_id does not match request.receiver_id")
	ErrRequestNonceReplay     = errors.New("settlement: session_nonce already consumed")
)

// RequestGrace is the clock-drift allowance when evaluating
// PaymentRequest.expires_at. PRs are short-lived by design; the grace
// window only smooths over device-clock skew.
const RequestGrace = 5 * time.Minute

// Defaults.
const (
	DefaultClockGrace        = 30 * time.Minute
	DefaultAutoSettleTimeout = 72 * time.Hour
)

// System-reserved identifiers (see migration 0012_accounts_suspense).
const (
	SystemSuspenseAccountID = "system-suspense"
)

type Clock interface{ Now() time.Time }

type SystemClock struct{}

func (SystemClock) Now() time.Time { return time.Now().UTC() }

// FraudRecorder is a notify-only sink for signature-verification failures
// during settlement. Implementations MUST NOT block — the settlement tx
// continues even if recording fails.
type FraudRecorder interface {
	Record(ctx context.Context, ev domain.FraudEvent)
}

type NoopFraudRecorder struct{}

func (NoopFraudRecorder) Record(context.Context, domain.FraudEvent) {}

// FraudDetector receives stream observations (accepted claims, settled
// txns) and emits derived signals (velocity, geographic anomaly) via its
// own sink. Implementations MUST NOT block.
type FraudDetector interface {
	ObserveSettled(ctx context.Context, userID string, at time.Time)
	ObserveClaim(ctx context.Context, userID, country string, at time.Time)
}

type NoopFraudDetector struct{}

func (NoopFraudDetector) ObserveSettled(context.Context, string, time.Time)         {}
func (NoopFraudDetector) ObserveClaim(context.Context, string, string, time.Time)   {}

// submitOptions carries optional per-batch context passed through
// WithSubmitterCountry. Zero values mean "not provided".
type submitOptions struct {
	submitterCountry string
}

// SubmitOption configures an individual SubmitClaim invocation.
type SubmitOption func(*submitOptions)

// WithSubmitterCountry attaches an ISO-3166 alpha-2 country code for the
// submitting receiver's network location at upload time. The settlement
// service forwards it to the fraud detector so geographic-anomaly signals
// can fire when the same user uploads from different countries inside the
// detector's window. Empty strings are ignored.
func WithSubmitterCountry(country string) SubmitOption {
	return func(o *submitOptions) { o.submitterCountry = country }
}

// Repository is the narrow repo subset the settlement service needs.
// *pgrepo.Repo (via the adapter) satisfies this interface.
type Repository interface {
	Tx(ctx context.Context, fn func(Repository) error) error

	GetAccountID(ctx context.Context, userID string, kind sqlcgen.AccountKind) (string, error)
	DebitAccount(ctx context.Context, accountID string, amount int64) error
	ForceDebitAccount(ctx context.Context, accountID string, amount int64) error
	CreditAccount(ctx context.Context, accountID string, amount int64) error
	PostLedger(ctx context.Context, txnID string, legs []pgrepo.LedgerLeg) error

	GetCeilingToken(ctx context.Context, id string) (domain.CeilingToken, error)
	GetBankSigningKey(ctx context.Context, keyID string) (domain.BankSigningKey, error)
	UpdateCeilingStatus(ctx context.Context, id string, status domain.CeilingStatus) error

	GetPaymentBySequence(ctx context.Context, payerUserID string, sequenceNumber int64) (domain.Transaction, error)
	CreatePayment(ctx context.Context, p pgrepo.CreatePaymentParams) (domain.Transaction, error)
	ListPendingForPayer(ctx context.Context, payerUserID string) ([]domain.Transaction, error)
	UpdatePaymentStatus(ctx context.Context, id string, state domain.TransactionStatus,
		settledAmount int64, rejectionReason string, batchID *string,
		submittedAt, settledAt *time.Time) (domain.Transaction, error)

	ListPayersWithStalePending(ctx context.Context, olderThan time.Time) ([]string, error)

	RecordTransaction(ctx context.Context, p pgrepo.RecordTransactionParams) error
	GetTransactionAnchorForPayment(ctx context.Context, paymentTokenID string) (pgrepo.TransactionAnchor, error)
	FinalizePairedTransactions(ctx context.Context, groupID string, status domain.TransactionLifecycleStatus, settled *int64, failureReason *string) error

	// InsertFinalizeOutbox enqueues a Phase 4b finalize event for the
	// given payer. Called from inside an existing tx so the enqueue is
	// atomic with the business write that triggered it (Phase 4a PENDING
	// row, AutoSettleSweep tick, or a payer's sync-requested finalize).
	InsertFinalizeOutbox(ctx context.Context, outboxID, payerUserID string, payload []byte) error
}

// ClaimItem is a single entry in a SubmitClaim batch. The caller (transport
// layer or test) provides the payer-signed payment token, the ceiling token
// it references, and the receiver-signed PaymentRequest the payer's token
// counter-signs. The service re-verifies every signature and re-derives the
// request hash so no DB lookup chain is needed.
type ClaimItem struct {
	Payment domain.PaymentToken
	Ceiling domain.CeilingToken
	Request domain.PaymentRequest
}

// Service is the stateless settlement engine.
type Service struct {
	Repo              Repository
	Clock             Clock
	Fraud             FraudRecorder
	Detector          FraudDetector
	NewID             func() string
	ClockGrace        time.Duration
	AutoSettleTimeout time.Duration
	// SuspenseAccountID overrides the default system suspense account id.
	SuspenseAccountID string
	// PanicAfter is a test-only fault-injection hook. If set, it is invoked
	// at named stages inside FinalizeForPayer ("start", "post-debit-lien",
	// "pre-commit"). Production code never sets this.
	PanicAfter func(stage string)
}

func (s *Service) invokePanic(stage string) {
	if s.PanicAfter != nil {
		s.PanicAfter(stage)
	}
}

// New constructs a Service with production defaults.
func New(repo Repository) *Service {
	return &Service{
		Repo:              repo,
		Clock:             SystemClock{},
		Fraud:             NoopFraudRecorder{},
		Detector:          NoopFraudDetector{},
		NewID:             pgrepo.NewID,
		ClockGrace:        DefaultClockGrace,
		AutoSettleTimeout: DefaultAutoSettleTimeout,
		SuspenseAccountID: SystemSuspenseAccountID,
	}
}

// SubmitClaim  Re-verifies signatures, enforces all guards,
// dedupes by (payer, sequence), and credits each accepted claim's payee
// receiving_pending. Returns the batch descriptor and per-item results.
//
// submitterUserID is the authenticated caller: either the payer or the
// payee on each token in the batch. Whichever side reaches connectivity
// first drains its QUEUED rows; the other side dedupes by
// (payer, sequence) when it catches up.
//
// Each item is processed in its own sub-transaction so that a single bad
// item doesn't poison the whole batch. The outer batch descriptor is
// returned regardless (with totals reflecting what actually succeeded).
func (s *Service) SubmitClaim(ctx context.Context, submitterUserID string, batch []ClaimItem, opts ...SubmitOption) (domain.SettlementBatch, []domain.SettlementResult, error) {
	if submitterUserID == "" {
		return domain.SettlementBatch{}, nil, errors.New("settlement: submitter id required")
	}
	var o submitOptions
	for _, fn := range opts {
		fn(&o)
	}
	now := s.Clock.Now().UTC()
	batchID := s.NewID()
	b := domain.SettlementBatch{
		ID:             batchID,
		ReceiverID:     submitterUserID,
		TotalSubmitted: len(batch),
		Status:         domain.BatchProcessing,
		SubmittedAt:    now,
		CreatedAt:      now,
	}
	results := make([]domain.SettlementResult, 0, len(batch))

	anyAccepted := false
	// Collect distinct payer ids whose payments we accepted into PENDING
	// so we can enqueue a single finalize event per payer at the end.
	// Dedup is just an optimisation — the processor short-circuits when
	// there are no PENDING rows, so duplicate events are harmless.
	payersToFinalize := map[string]struct{}{}
	for _, item := range batch {
		res, err := s.submitOne(ctx, batchID, submitterUserID, item, now)
		if err != nil {
			// Infrastructure error — abort the batch. Caller can retry.
			b.Status = domain.BatchFailed
			return b, results, err
		}
		results = append(results, res)
		switch res.Status {
		case domain.TxPending:
			b.TotalAmount += res.SettledAmount // 0 in 4a; settled amount is in 4b
			anyAccepted = true
			payersToFinalize[item.Payment.PayerID] = struct{}{}
		case domain.TxRejected:
			b.TotalRejected++
		}
	}
	// Fire geographic observation once per batch — one physical upload
	// from one device, so multiple items don't mean multiple geo points.
	if anyAccepted && s.Detector != nil && o.submitterCountry != "" {
		s.Detector.ObserveClaim(ctx, submitterUserID, o.submitterCountry, now)
	}

	// One outbox row per payeris enough — the worker's FinalizeForPayer drains every PENDING row
	// for that payer in sequence. Enqueue failures are non-fatal from the
	// RPC's perspective (the PENDING rows are durable), but we surface the
	// error so the caller can retry the batch under their idempotency key.
	for payerID := range payersToFinalize {
		if err := s.enqueueFinalize(ctx, payerID, domain.FinalizeReasonClaimAccepted); err != nil {
			b.Status = domain.BatchFailed
			return b, results, fmt.Errorf("settlement: enqueue finalize for %s: %w", payerID, err)
		}
	}

	processedAt := s.Clock.Now().UTC()
	b.ProcessedAt = &processedAt
	b.Status = domain.BatchCompleted
	return b, results, nil
}

func (s *Service) submitOne(ctx context.Context, batchID, submitterUserID string, item ClaimItem, now time.Time) (domain.SettlementResult, error) {
	p := item.Payment
	c := item.Ceiling
	req := item.Request
	res := domain.SettlementResult{
		SequenceNumber:  p.SequenceNumber,
		SubmittedAmount: p.Amount,
	}

	// 1) Structural sanity: a token that pays itself is invalid regardless
	// of who submits.
	if p.PayerID == p.PayeeID {
		res.Status = domain.TxRejected
		res.Reason = ErrSelfPay.Error()
		return res, nil
	}
	if p.PayerID != c.PayerID {
		res.Status = domain.TxRejected
		res.Reason = ErrPayerIDMismatch.Error()
		return res, nil
	}
	if p.CeilingTokenID != c.ID {
		res.Status = domain.TxRejected
		res.Reason = ErrCeilingMismatch.Error()
		return res, nil
	}
	// Submitter binding:
	// Whichever device reaches connectivity first uploads; the other side
	// will dedupe via (payer_user_id, sequence_number) below. A random
	// third party cannot submit — the PR + signatures still pin the two
	// legitimate participants cryptographically, and this check refuses
	// stolen-blob uploads from non-parties.
	if submitterUserID != p.PayerID && submitterUserID != p.PayeeID {
		res.Status = domain.TxRejected
		res.Reason = ErrSubmitterNotParty.Error()
		return res, nil
	}
	// PaymentRequest binds to the token's payee, not to the submitter: the
	// payer and payee both hold the same PR blob, so either side can
	// present it.
	if req.ReceiverID != p.PayeeID {
		res.Status = domain.TxRejected
		res.Reason = ErrRequestReceiverMismatch.Error()
		return res, nil
	}
	if req.ReceiverDisplayCard.UserID != req.ReceiverID {
		res.Status = domain.TxRejected
		res.Reason = ErrRequestDisplayCardUser.Error()
		return res, nil
	}

	// 2) Re-verify bank signature on ceiling via its bank key id.
	bankKey, err := s.Repo.GetBankSigningKey(ctx, c.BankKeyID)
	if err != nil {
		return res, fmt.Errorf("settlement: load bank key %s: %w", c.BankKeyID, err)
	}
	cpayload := domain.CeilingTokenPayload{
		PayerID:        c.PayerID,
		CeilingAmount:  c.CeilingAmount,
		IssuedAt:       c.IssuedAt,
		ExpiresAt:      c.ExpiresAt,
		SequenceStart:  c.SequenceStart,
		PayerPublicKey: c.PayerPublicKey,
		BankKeyID:      c.BankKeyID,
	}
	if err := crypto.VerifyCeiling(ed25519.PublicKey(bankKey.PublicKey), cpayload, c.BankSignature); err != nil {
		s.Fraud.Record(ctx, domain.FraudEvent{
			UserID:         c.PayerID,
			SignalType:     domain.FraudSignatureInvalid,
			CeilingTokenID: &c.ID,
			Severity:       "HIGH",
			Details:        "bank signature on ceiling failed verification at settlement",
		})
		res.Status = domain.TxRejected
		res.Reason = ErrBadBankSignature.Error()
		return res, nil
	}

	// 3) Re-verify payer signature on payment.
	ppayload := domain.PaymentPayload{
		PayerID:          p.PayerID,
		PayeeID:          p.PayeeID,
		Amount:           p.Amount,
		SequenceNumber:   p.SequenceNumber,
		RemainingCeiling: p.RemainingCeiling,
		Timestamp:        p.Timestamp,
		CeilingTokenID:   p.CeilingTokenID,
		SessionNonce:     p.SessionNonce,
		RequestHash:      p.RequestHash,
	}
	if err := crypto.VerifyPayment(ed25519.PublicKey(c.PayerPublicKey), ppayload, p.PayerSignature); err != nil {
		txID := ""
		s.Fraud.Record(ctx, domain.FraudEvent{
			UserID:         p.PayerID,
			SignalType:     domain.FraudSignatureInvalid,
			CeilingTokenID: &c.ID,
			TransactionID:  &txID,
			Severity:       "HIGH",
			Details:        "payer signature on payment failed verification at settlement",
		})
		res.Status = domain.TxRejected
		res.Reason = ErrBadPayerSignature.Error()
		return res, nil
	}

	// 3b) Verify the display card is really server-issued. Reuse the
	//     ceiling's bank key — we issue both with the same active key so
	//     devices need only the one cached pubkey.
	cardPayload := req.ReceiverDisplayCard.Payload()
	cardKey := bankKey
	if cardPayload.BankKeyID != c.BankKeyID {
		cardKey, err = s.Repo.GetBankSigningKey(ctx, cardPayload.BankKeyID)
		if err != nil {
			return res, fmt.Errorf("settlement: load bank key %s: %w", cardPayload.BankKeyID, err)
		}
	}
	if err := crypto.VerifyDisplayCard(ed25519.PublicKey(cardKey.PublicKey), cardPayload, req.ReceiverDisplayCard.ServerSignature); err != nil {
		res.Status = domain.TxRejected
		res.Reason = ErrBadDisplayCardSig.Error()
		return res, nil
	}

	// 3c) Verify the receiver's signature on the PaymentRequest. The
	//     receiver's device pubkey lives inside the PR payload — the
	//     authenticated submitter claim (checked above) plus the server's
	//     single-use session_nonce index prevents an attacker from
	//     substituting their own keypair for somebody else's user_id.
	rpayload := req.Payload()
	if err := crypto.VerifyRequest(ed25519.PublicKey(req.ReceiverDevicePubkey), rpayload, req.ReceiverSignature); err != nil {
		res.Status = domain.TxRejected
		res.Reason = ErrBadReceiverSignature.Error()
		return res, nil
	}

	// 3d) Bind the payment to the request: nonce equality, hash equality,
	//     amount equality (unless PR is unbound), and expiry. The hash is
	//     recomputed from the canonical PR so any tampering between payer
	//     sign-time and submit-time fails.
	if !bytesEqual(p.SessionNonce, req.SessionNonce) {
		res.Status = domain.TxRejected
		res.Reason = ErrRequestNonceMismatch.Error()
		return res, nil
	}
	reqHash, err := crypto.HashRequest(req)
	if err != nil {
		return res, fmt.Errorf("settlement: hash request: %w", err)
	}
	if !bytesEqual(p.RequestHash, reqHash) {
		res.Status = domain.TxRejected
		res.Reason = ErrRequestHashMismatch.Error()
		return res, nil
	}
	if req.Amount != domain.UnboundAmount && p.Amount != req.Amount {
		res.Status = domain.TxRejected
		res.Reason = ErrRequestAmountMismatch.Error()
		return res, nil
	}
	if now.After(req.ExpiresAt.Add(RequestGrace)) {
		res.Status = domain.TxRejected
		res.Reason = ErrRequestExpired.Error()
		return res, nil
	}

	// 4) Sequence + expiry.
	if p.SequenceNumber <= c.SequenceStart {
		s.Fraud.Record(ctx, domain.FraudEvent{
			UserID:         p.PayerID,
			SignalType:     domain.FraudSequenceAnomaly,
			CeilingTokenID: &c.ID,
			Severity:       "MEDIUM",
			Details:        "payment sequence_number <= ceiling.sequence_start",
		})
		res.Status = domain.TxRejected
		res.Reason = ErrSequenceBelowStart.Error()
		return res, nil
	}
	if now.After(c.ExpiresAt.Add(s.ClockGrace)) {
		res.Status = domain.TxRejected
		res.Reason = ErrCeilingExpired.Error()
		return res, nil
	}

	// 5) Dedupe by (payer, sequence). If the payment already exists, return
	//    its current state idempotently — no ledger re-post. Runs before
	//    the server-side ceiling-status check (4b) because a retry of an
	//    already-accepted claim must produce the same result even after
	//    the ceiling later transitions to RECOVERY_PENDING or a terminal
	//    status.
	if existing, err := s.Repo.GetPaymentBySequence(ctx, p.PayerID, p.SequenceNumber); err == nil {
		res.TransactionID = existing.ID
		res.Status = existing.Status
		res.SettledAmount = existing.SettledAmount
		if existing.RejectionReason != nil {
			res.Reason = *existing.RejectionReason
		}
		return res, nil
	} else if !isNoRows(err) {
		return res, fmt.Errorf("settlement: dedupe lookup: %w", err)
	}

	// 4b) Consult the server-side ceiling status for first-time claims only.
	// The client's bank-signed copy carries the immutable payload; status +
	// release_after are mutable and only the DB knows the truth. Without
	// this check a merchant could settle a brand-new claim against a
	// ceiling the payer has already recovered (or the server has already
	// revoked/expired), racing the ReleaseOnExpiry sweeper and breaking
	// lien accounting.
	//
	// Accepted: ACTIVE ceilings, and RECOVERY_PENDING ceilings whose
	// release_after is still in the future (in-flight merchants settle
	// normally during the quarantine window).
	// Rejected: any terminal status, or RECOVERY_PENDING past release_after.
	live, err := s.Repo.GetCeilingToken(ctx, c.ID)
	if err != nil {
		return res, fmt.Errorf("settlement: reload ceiling status: %w", err)
	}
	switch live.Status {
	case domain.CeilingActive:
		// fall through
	case domain.CeilingRecoveryPending:
		if live.ReleaseAfter == nil || !now.Before(*live.ReleaseAfter) {
			res.Status = domain.TxRejected
			res.Reason = ErrCeilingRecoveryClosed.Error()
			return res, nil
		}
	default: // EXPIRED, REVOKED, EXHAUSTED, or anything else non-active
		res.Status = domain.TxRejected
		res.Reason = ErrCeilingRevoked.Error()
		return res, nil
	}

	// 6) Accept. Single tx: create payment row PENDING, post ledger, flip
	//    balances, write paired transactions rows.
	txErr := s.Repo.Tx(ctx, func(repo Repository) error {
		paymentID := s.NewID()
		// Receiver identity comes from the payer-signed token (p.PayeeID),
		// NOT from the submitter. Either party may upload the claim; only
		// the signed payee ever gets credited.
		receiverPendingAcc, err := repo.GetAccountID(ctx, p.PayeeID, sqlcgen.AccountKindReceivingPending)
		if err != nil {
			return fmt.Errorf("settlement: receiver pending account: %w", err)
		}
		submittedAt := now
		// Persist the cryptographically bound payee + the authenticated
		// submitter separately. The unique index on
		// (payee_user_id, session_nonce) single-use-locks the PR here.
		if _, err := repo.CreatePayment(ctx, pgrepo.CreatePaymentParams{
			ID:                paymentID,
			CeilingID:         c.ID,
			PayerUserID:       p.PayerID,
			PayeeUserID:       p.PayeeID,
			Amount:            p.Amount,
			SequenceNumber:    p.SequenceNumber,
			RemainingCeiling:  p.RemainingCeiling,
			SignedAt:          p.Timestamp,
			PayerSignature:    p.PayerSignature,
			Status:            domain.TxPending,
			SessionNonce:      p.SessionNonce,
			RequestHash:       p.RequestHash,
			RequestAmountKobo: req.Amount,
			SubmittedByUserID: submitterUserID,
		}); err != nil {
			return fmt.Errorf("settlement: insert payment: %w", err)
		}

		// Paired business-event rows. Payer-side row's id IS the ledger
		// txn_id so the FK lands; both rows share group_id so finalise
		// can flip them together. Phase 4b will reuse the same txn_id
		// for its own ledger posts.
		anchorID := s.NewID()
		groupID := anchorID
		receiverRowID := s.NewID()
		payerCounter := p.PayeeID
		payeeCounter := p.PayerID
		paymentRef := paymentID
		if err := repo.RecordTransaction(ctx, pgrepo.RecordTransactionParams{
			ID:                 anchorID,
			GroupID:            groupID,
			UserID:             p.PayerID,
			CounterpartyUserID: &payerCounter,
			Kind:               domain.TxKindOfflinePaymentSent,
			Status:             domain.TxStatusPending,
			Direction:          "DEBIT",
			AmountKobo:         p.Amount,
			Memo:               "offline payment sent",
			PaymentTokenID:     &paymentRef,
		}); err != nil {
			return fmt.Errorf("settlement: record payer transaction: %w", err)
		}
		if err := repo.RecordTransaction(ctx, pgrepo.RecordTransactionParams{
			ID:                 receiverRowID,
			GroupID:            groupID,
			UserID:             p.PayeeID,
			CounterpartyUserID: &payeeCounter,
			Kind:               domain.TxKindOfflinePaymentReceived,
			Status:             domain.TxStatusPending,
			Direction:          "CREDIT",
			AmountKobo:         p.Amount,
			Memo:               "offline payment received",
			PaymentTokenID:     &paymentRef,
		}); err != nil {
			return fmt.Errorf("settlement: record receiver transaction: %w", err)
		}

		// Ledger: DEBIT suspense, CREDIT receiver.receiving_pending.
		// Use anchorID as txn_id so the FK to transactions(id) holds.
		if err := repo.PostLedger(ctx, anchorID, []pgrepo.LedgerLeg{
			{AccountID: s.SuspenseAccountID, Direction: "DEBIT", Amount: p.Amount, Memo: "claim 4a suspense"},
			{AccountID: receiverPendingAcc, Direction: "CREDIT", Amount: p.Amount, Memo: "claim 4a receiver pending"},
		}); err != nil {
			return fmt.Errorf("settlement: post 4a ledger: %w", err)
		}
		if err := repo.ForceDebitAccount(ctx, s.SuspenseAccountID, p.Amount); err != nil {
			return fmt.Errorf("settlement: debit suspense: %w", err)
		}
		if err := repo.CreditAccount(ctx, receiverPendingAcc, p.Amount); err != nil {
			return fmt.Errorf("settlement: credit pending: %w", err)
		}
		// Stamp submitted_at + batch id.
		if _, err := repo.UpdatePaymentStatus(ctx, paymentID, domain.TxPending, 0, "", &batchID, &submittedAt, nil); err != nil {
			return fmt.Errorf("settlement: stamp submit: %w", err)
		}
		res.TransactionID = paymentID
		res.Status = domain.TxPending
		return nil
	})
	if txErr != nil {
		return res, txErr
	}
	return res, nil
}

// FinalizeForPayer — Phase 4b. Processes every PENDING payment for payer
// in sequence order, debiting lien_holding as funds are consumed. Runs in
// a single outer tx so partials settle atomically.
func (s *Service) FinalizeForPayer(ctx context.Context, payerUserID string) ([]domain.SettlementResult, error) {
	var results []domain.SettlementResult
	err := s.Repo.Tx(ctx, func(repo Repository) error {
		s.invokePanic("start")
		pending, err := repo.ListPendingForPayer(ctx, payerUserID)
		if err != nil {
			return fmt.Errorf("settlement: list pending: %w", err)
		}
		// Defensive re-sort — pgrepo orders ASC by sequence but a fake
		// might not.
		sort.SliceStable(pending, func(i, j int) bool {
			return pending[i].SequenceNumber < pending[j].SequenceNumber
		})
		if len(pending) == 0 {
			return nil
		}

		lienAcc, err := repo.GetAccountID(ctx, payerUserID, sqlcgen.AccountKindLienHolding)
		if err != nil {
			return fmt.Errorf("settlement: lien account: %w", err)
		}

		// Load ceiling to know the starting lien amount + to update its
		// status on exhaustion. We use the ceiling referenced by the first
		// pending payment; all others must share it (one-active invariant).
		ceiling, err := repo.GetCeilingToken(ctx, pending[0].CeilingTokenID)
		if err != nil {
			return fmt.Errorf("settlement: load ceiling: %w", err)
		}
		remaining := ceiling.CeilingAmount

		now := s.Clock.Now().UTC()

		for _, txn := range pending {
			settled := int64(0)
			status := domain.TxSettled
			reason := ""
			switch {
			case remaining <= 0:
				// Ceiling already exhausted — no funds left.
				settled = 0
				status = domain.TxPartiallySettled
				reason = "ceiling exhausted"
				s.Fraud.Record(ctx, domain.FraudEvent{
					UserID:         payerUserID,
					SignalType:     domain.FraudCeilingExhaustion,
					CeilingTokenID: &ceiling.ID,
					TransactionID:  &txn.ID,
					Severity:       "LOW",
					Details:        "txn reached settlement after ceiling already exhausted",
				})
			case txn.Amount <= remaining:
				settled = txn.Amount
				remaining -= settled
				status = domain.TxSettled
			default:
				// Partial: some funds remain but less than full amount.
				settled = remaining
				remaining = 0
				status = domain.TxPartiallySettled
				reason = fmt.Sprintf("ceiling short by %d kobo", txn.Amount-settled)
				s.Fraud.Record(ctx, domain.FraudEvent{
					UserID:         payerUserID,
					SignalType:     domain.FraudCeilingExhaustion,
					CeilingTokenID: &ceiling.ID,
					TransactionID:  &txn.ID,
					Severity:       "LOW",
					Details:        "txn settlement exhausted the ceiling (partial)",
				})
			}

			receiverPendingAcc, err := repo.GetAccountID(ctx, txn.PayeeID, sqlcgen.AccountKindReceivingPending)
			if err != nil {
				return fmt.Errorf("settlement: receiver pending: %w", err)
			}
			receiverMainAcc, err := repo.GetAccountID(ctx, txn.PayeeID, sqlcgen.AccountKindMain)
			if err != nil {
				return fmt.Errorf("settlement: receiver main: %w", err)
			}

			// Reuse the Phase-4a anchor as the ledger txn_id so all
			// ledger postings for this payment hang off one transactions
			// row (and the deferred FK to transactions(id) holds).
			anchor, err := repo.GetTransactionAnchorForPayment(ctx, txn.ID)
			if err != nil {
				return fmt.Errorf("settlement: load txn anchor: %w", err)
			}
			ledgerTxn := anchor.ID
			// Four-leg settlement per txn: release the payer's lien,
			// repay suspense (pairing the Phase-4a debit), drain the
			// receiver's pending bucket, credit the receiver's main
			// wallet so the funds are immediately spendable. No
			// receiving_available hop — it was ceremonial overhead.
			legs := make([]pgrepo.LedgerLeg, 0, 6)
			if settled > 0 {
				legs = append(legs,
					pgrepo.LedgerLeg{AccountID: lienAcc, Direction: "DEBIT", Amount: settled, Memo: "4b lien release"},
					pgrepo.LedgerLeg{AccountID: s.SuspenseAccountID, Direction: "CREDIT", Amount: settled, Memo: "4b suspense repay"},
					pgrepo.LedgerLeg{AccountID: receiverPendingAcc, Direction: "DEBIT", Amount: settled, Memo: "4b pending drain"},
					pgrepo.LedgerLeg{AccountID: receiverMainAcc, Direction: "CREDIT", Amount: settled, Memo: "4b main credit"},
				)
			}
			unsettled := txn.Amount - settled
			if unsettled > 0 {
				legs = append(legs,
					pgrepo.LedgerLeg{AccountID: receiverPendingAcc, Direction: "DEBIT", Amount: unsettled, Memo: "4b unsettled reverse"},
					pgrepo.LedgerLeg{AccountID: s.SuspenseAccountID, Direction: "CREDIT", Amount: unsettled, Memo: "4b suspense reverse"},
				)
			}
			if len(legs) > 0 {
				if err := repo.PostLedger(ctx, ledgerTxn, legs); err != nil {
					return fmt.Errorf("settlement: 4b ledger: %w", err)
				}
				if settled > 0 {
					if err := repo.DebitAccount(ctx, lienAcc, settled); err != nil {
						return fmt.Errorf("settlement: debit lien: %w", err)
					}
					if err := repo.CreditAccount(ctx, s.SuspenseAccountID, settled); err != nil {
						return fmt.Errorf("settlement: credit suspense: %w", err)
					}
					if err := repo.DebitAccount(ctx, receiverPendingAcc, settled); err != nil {
						return fmt.Errorf("settlement: debit pending: %w", err)
					}
					if err := repo.CreditAccount(ctx, receiverMainAcc, settled); err != nil {
						return fmt.Errorf("settlement: credit main: %w", err)
					}
				}
				if unsettled > 0 {
					if err := repo.DebitAccount(ctx, receiverPendingAcc, unsettled); err != nil {
						return fmt.Errorf("settlement: reverse debit pending: %w", err)
					}
					if err := repo.CreditAccount(ctx, s.SuspenseAccountID, unsettled); err != nil {
						return fmt.Errorf("settlement: reverse credit suspense: %w", err)
					}
				}
			}

			settledAt := now
			if _, err := repo.UpdatePaymentStatus(ctx, txn.ID, status, settled, reason, txn.SettlementBatchID, txn.SubmittedAt, &settledAt); err != nil {
				return fmt.Errorf("settlement: update state: %w", err)
			}
			// Velocity observation — only once the txn reached a terminal
			// settled state (partials with settled>0 still count; zero-
			// settle rows don't). Runs inside the tx but the detector is
			// in-memory so there's no risk of blocking.
			if settled > 0 && s.Detector != nil {
				s.Detector.ObserveSettled(ctx, payerUserID, settledAt)
			}

			// Flip both paired transactions rows to COMPLETED with the
			// final settled_amount_kobo. Reason (if any) goes to
			// failure_reason for visibility on partials.
			finalSettled := settled
			var failPtr *string
			if reason != "" {
				r := reason
				failPtr = &r
			}
			if err := repo.FinalizePairedTransactions(ctx, anchor.GroupID, domain.TxStatusCompleted, &finalSettled, failPtr); err != nil {
				return fmt.Errorf("settlement: finalize transactions: %w", err)
			}

			results = append(results, domain.SettlementResult{
				TransactionID:   txn.ID,
				SequenceNumber:  txn.SequenceNumber,
				SubmittedAmount: txn.Amount,
				SettledAmount:   settled,
				Status:          status,
				Reason:          reason,
				ReceiverUserID:  txn.PayeeID,
			})
		}

		if remaining == 0 {
			if err := repo.UpdateCeilingStatus(ctx, ceiling.ID, domain.CeilingExhausted); err != nil {
				return fmt.Errorf("settlement: exhaust ceiling: %w", err)
			}
		}
		s.invokePanic("pre-commit")
		return nil
	})
	return results, err
}

// AutoSettleSweep finds payers whose oldest PENDING payment is older than
// the configured timeout and enqueues a finalize event for each. Cron
// entrypoint. Returns the number of payers enqueued.
//
// The sweep does not drive the ledger itself — it just hands intent to
// the outbox. The settlementworker (really the FinalizeProcessor running
// inside cmd/transferworker) picks the events up and calls
// FinalizeForPayer. This keeps the cron tx tiny (one row per payer) and
// avoids a 72h-old sweep stalling behind a single slow payer's ledger
// movement.
func (s *Service) AutoSettleSweep(ctx context.Context) (int, error) {
	cutoff := s.Clock.Now().UTC().Add(-s.AutoSettleTimeout)
	payers, err := s.Repo.ListPayersWithStalePending(ctx, cutoff)
	if err != nil {
		return 0, fmt.Errorf("settlement: list stale payers: %w", err)
	}
	enqueued := 0
	for _, p := range payers {
		if err := s.enqueueFinalize(ctx, p, domain.FinalizeReasonSweep); err != nil {
			// Log-shaped failures only: a row not enqueued will be
			// retried on the next sweep tick.
			return enqueued, err
		}
		enqueued++
	}
	return enqueued, nil
}

// EnqueueFinalize is the public entrypoint SyncUser(finalize=true) uses
// to hand a user's Phase 4b off to the worker. Thin wrapper around the
// package-private enqueueFinalize so transport-layer callers don't poke
// at internals. Returns the caller-visible "in progress" signal: nil on
// a successful enqueue, an error if the outbox insert fails (transport
// layer should surface 502).
func (s *Service) EnqueueFinalize(ctx context.Context, payerUserID, reason string) error {
	return s.enqueueFinalize(ctx, payerUserID, reason)
}

// enqueueFinalize inserts a settlement-finalize outbox row for payerUserID.
// Shared by SubmitClaim, AutoSettleSweep, and SyncUser(finalize=true) so
// every Phase 4b entrypoint goes through exactly the same code path.
func (s *Service) enqueueFinalize(ctx context.Context, payerUserID, reason string) error {
	if payerUserID == "" {
		return errors.New("settlement: enqueueFinalize: empty payer_user_id")
	}
	payload, err := json.Marshal(domain.FinalizePayerPayload{
		PayerUserID: payerUserID,
		Reason:      reason,
		EnqueuedAt:  s.Clock.Now().UTC(),
	})
	if err != nil {
		return fmt.Errorf("settlement: marshal finalize payload: %w", err)
	}
	return s.Repo.InsertFinalizeOutbox(ctx, s.NewID(), payerUserID, payload)
}

// isNoRows is shared with the wallet service pattern — we match on
// substring so any pgx-shaped "no rows" surfaces correctly.
func isNoRows(err error) bool {
	if err == nil {
		return false
	}
	if errors.Is(err, ErrNoRows) {
		return true
	}
	return err.Error() == "no rows in result set"
}

// bytesEqual is a constant-time-ish byte-slice comparator. crypto/subtle
// would be ideal but these comparisons aren't secret-dependent; a plain
// equality is sufficient and keeps the dep surface small.
func bytesEqual(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// ErrNoRows is the sentinel fake repos should return on missing rows.
var ErrNoRows = errors.New("no rows in result set")
