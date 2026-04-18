// Package wallet owns the offline-wallet / ceiling-token lifecycle:
// funding, draining, refreshing, and expiry-sweeping.
//
// Transactional contract: every `*InTx` helper MUST run inside Repo.Tx.
// The closure parameter is named `repo`, not `tx`, because it is a
// Repository view — not a raw pgx.Tx. Breaking that boundary loses the
// multi-write atomicity guarantee and the deferred ledger FK to
// transactions(id).
package wallet

import (
	"context"
	"crypto/ed25519"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/intellect/offlinepay/internal/crypto"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

// Signer is a local alias for crypto.CeilingSigner so wallet owns the
// signing contract on its public surface — callers don't need kms.
type Signer = crypto.CeilingSigner

var (
	ErrActiveCeilingExists  = errors.New("wallet: user already has an active ceiling")
	ErrNoActiveCeiling      = errors.New("wallet: no active ceiling for user")
	ErrUnsettledClaims      = errors.New("wallet: ceiling has unsettled claims")
	ErrInsufficientFunds    = errors.New("wallet: insufficient funds in main wallet")
	ErrMissingPayerPubkey   = errors.New("wallet: user has no registered payer public key")
	ErrSuspended            = errors.New("wallet: user suspended by fraud tier")
	ErrRecoveryRaceLost     = errors.New("wallet: ceiling no longer active (recovery race)")
)

// ReleaseGrace is the clock-drift buffer added to expiry before the
// sweeper considers a ceiling releasable.
const ReleaseGrace = 30 * time.Minute

// DefaultAutoSettleTimeout is how long an offline-signed payment token
// can still realistically land before auto-settle rejects it. Mirrors
// the settlement-service default; the BFF overrides via Service.
// AutoSettleTimeout when it wires the two services together.
const DefaultAutoSettleTimeout = 72 * time.Hour

type Clock interface{ Now() time.Time }

type SystemClock struct{}

func (SystemClock) Now() time.Time { return time.Now().UTC() }

// SequenceTracker pre-registers a ceiling's starting sequence number in a
// fast store (Redis) so settlement can cheaply reject replays and
// out-of-order submissions. Implementations MUST be idempotent per
// (userID, ceilingID). Postgres UNIQUE (payer_user_id, sequence_number)
// remains the source of truth.
type SequenceTracker interface {
	RegisterCeiling(ctx context.Context, userID, ceilingID string, sequenceStart int64) error
}

type NoopSequenceTracker struct{}

func (NoopSequenceTracker) RegisterCeiling(context.Context, string, string, int64) error {
	return nil
}

// FraudGate clamps the requested ceiling against the user's fraud tier.
// allowed==0 means suspended — refuse.
type FraudGate interface {
	ClampCeiling(ctx context.Context, userID string, requested int64) (int64, string, error)
}

type NoopFraudGate struct{}

func (NoopFraudGate) ClampCeiling(_ context.Context, _ string, requested int64) (int64, string, error) {
	return requested, "STANDARD", nil
}

// Repository is the subset of pgrepo.Repo the wallet service needs. Extracted
// so that unit tests can drop in a fake without standing up Postgres. The
// concrete *pgrepo.Repo satisfies this interface.
type Repository interface {
	Tx(ctx context.Context, fn func(Repository) error) error

	GetAccountID(ctx context.Context, userID string, kind sqlcgen.AccountKind) (string, error)
	GetAccountBalance(ctx context.Context, userID string, kind sqlcgen.AccountKind) (int64, error)
	DebitAccount(ctx context.Context, accountID string, amount int64) error
	CreditAccount(ctx context.Context, accountID string, amount int64) error
	PostLedger(ctx context.Context, txnID string, legs []pgrepo.LedgerLeg) error

	GetUserPayerPubkey(ctx context.Context, userID string) ([]byte, error)

	GetActiveCeiling(ctx context.Context, userID string) (domain.CeilingToken, error)
	GetActiveBankSigningKey(ctx context.Context) (domain.BankSigningKey, error)
	IssueCeilingToken(ctx context.Context, p pgrepo.IssueCeilingParams) (domain.CeilingToken, error)
	UpdateCeilingStatus(ctx context.Context, id string, status domain.CeilingStatus) error
	MarkCeilingRecoveryPending(ctx context.Context, id string, releaseAfter time.Time) (int64, error)
	ListReleasableExpiredCeilings(ctx context.Context, before time.Time) ([]domain.CeilingToken, error)
	CountInFlightPaymentsForCeiling(ctx context.Context, ceilingID string) (int64, error)
	SumSettledForCeiling(ctx context.Context, ceilingID string) (int64, error)
	GetCurrentCeilingForPayer(ctx context.Context, userID string) (*pgrepo.CurrentCeilingRow, error)

	RecordTransaction(ctx context.Context, p pgrepo.RecordTransactionParams) error
}

// Balances is the per-user snapshot returned by GetBalances. LienHolding
// is the offline-wallet float — funds committed to an active ceiling,
// spendable offline via signed payment tokens.
type Balances struct {
	Main             int64
	LienHolding      int64
	ReceivingPending int64
}

// Service is the wallet/ceiling domain service. Stateless: all state lives
// in Repo + SeqTracker. Signer nil means sign locally with the private key
// from GetActiveBankSigningKey (dev/test); production wires a KMS-backed
// implementation.
type Service struct {
	Repo       Repository
	Clock      Clock
	SeqTracker SequenceTracker
	Fraud      FraudGate
	Signer     Signer
	NewID      func() string

	// AutoSettleTimeout bounds how long an offline-signed payment token
	// can realistically take to propagate + settle. Used only by the
	// recovery flow to size the quarantine window; zero falls back to
	// [DefaultAutoSettleTimeout]. Must match the corresponding
	// settlement.Service setting in production.
	AutoSettleTimeout time.Duration
}

// New constructs a Service with defaults (SystemClock, no-op SeqTracker,
// ULID NewID, local signing). Callers can override fields directly.
func New(repo Repository) *Service {
	return &Service{
		Repo:       repo,
		Clock:      SystemClock{},
		SeqTracker: NoopSequenceTracker{},
		Fraud:      NoopFraudGate{},
		NewID:      pgrepo.NewID,
	}
}

// FundOffline is an online operation. It debits the user's main wallet,
// places a lien on those funds, and issues a bank-signed ceiling token
// authorising offline spend. One ACTIVE ceiling per user is enforced at the
// DB level (partial unique index); violations surface as
// ErrActiveCeilingExists.
func (s *Service) FundOffline(ctx context.Context, userID string, amountKobo int64, ttl time.Duration) (domain.CeilingToken, error) {
	if amountKobo <= 0 {
		return domain.CeilingToken{}, fmt.Errorf("wallet: amount must be positive")
	}
	if ttl <= 0 {
		return domain.CeilingToken{}, fmt.Errorf("wallet: ttl must be positive")
	}

	if gate := s.Fraud; gate != nil {
		allowed, _, err := gate.ClampCeiling(ctx, userID, amountKobo)
		if err != nil {
			return domain.CeilingToken{}, fmt.Errorf("wallet: fraud clamp: %w", err)
		}
		if allowed <= 0 {
			return domain.CeilingToken{}, ErrSuspended
		}
		if allowed < amountKobo {
			amountKobo = allowed
		}
	}

	var issued domain.CeilingToken
	err := s.Repo.Tx(ctx, func(repo Repository) error {
		t, err := s.fundOfflineInTx(ctx, repo, userID, amountKobo, ttl)
		if err != nil {
			return err
		}
		issued = t
		return nil
	})
	if err != nil {
		return domain.CeilingToken{}, err
	}

	// Pre-register the sequence range outside the tx — the Redis write is
	// best-effort; Postgres uniqueness is the source of truth.
	if s.SeqTracker != nil {
		if err := s.SeqTracker.RegisterCeiling(ctx, userID, issued.ID, issued.SequenceStart); err != nil {
			return issued, fmt.Errorf("wallet: register sequence start: %w", err)
		}
	}
	return issued, nil
}

func (s *Service) fundOfflineInTx(ctx context.Context, repo Repository, userID string, amountKobo int64, ttl time.Duration) (domain.CeilingToken, error) {
	// 1) Refuse if an ACTIVE ceiling already exists.
	if _, err := repo.GetActiveCeiling(ctx, userID); err == nil {
		return domain.CeilingToken{}, ErrActiveCeilingExists
	} else if !isNoRows(err) {
		return domain.CeilingToken{}, fmt.Errorf("wallet: lookup active ceiling: %w", err)
	}

	// 2) Load payer public key.
	payerPub, err := repo.GetUserPayerPubkey(ctx, userID)
	if err != nil {
		return domain.CeilingToken{}, fmt.Errorf("wallet: load payer pubkey: %w", err)
	}
	if len(payerPub) == 0 {
		return domain.CeilingToken{}, ErrMissingPayerPubkey
	}

	// 3) Resolve main + lien_holding account ids.
	mainAcc, err := repo.GetAccountID(ctx, userID, sqlcgen.AccountKindMain)
	if err != nil {
		return domain.CeilingToken{}, fmt.Errorf("wallet: resolve main account: %w", err)
	}
	lienAcc, err := repo.GetAccountID(ctx, userID, sqlcgen.AccountKindLienHolding)
	if err != nil {
		return domain.CeilingToken{}, fmt.Errorf("wallet: resolve lien account: %w", err)
	}

	// 4) Pre-check main balance (for a clean error; DecrementAccountBalance
	//    also enforces the invariant at the UPDATE).
	mainBal, err := repo.GetAccountBalance(ctx, userID, sqlcgen.AccountKindMain)
	if err != nil {
		return domain.CeilingToken{}, fmt.Errorf("wallet: read main balance: %w", err)
	}
	if mainBal < amountKobo {
		return domain.CeilingToken{}, ErrInsufficientFunds
	}

	// 5) Bank signing key.
	bankKey, err := repo.GetActiveBankSigningKey(ctx)
	if err != nil {
		return domain.CeilingToken{}, fmt.Errorf("wallet: load bank signing key: %w", err)
	}

	// Truncate to microseconds so the signed payload matches the value
	// Postgres stores after insert — timestamptz has μs precision, and a
	// later re-verify would otherwise read back a rounded timestamp.
	now := s.Clock.Now().UTC().Truncate(time.Microsecond)
	ceilingID := s.NewID()
	payload := domain.CeilingTokenPayload{
		PayerID:        userID,
		CeilingAmount:  amountKobo,
		IssuedAt:       now,
		ExpiresAt:      now.Add(ttl),
		SequenceStart:  0,
		PayerPublicKey: payerPub,
		BankKeyID:      bankKey.KeyID,
	}
	sig, err := s.signCeiling(ctx, bankKey, payload)
	if err != nil {
		return domain.CeilingToken{}, fmt.Errorf("wallet: sign ceiling: %w", err)
	}

	// 6) Persist the ceiling row FIRST so the transactions.ceiling_id FK
	//    resolves at insert time below.
	ct, err := repo.IssueCeilingToken(ctx, pgrepo.IssueCeilingParams{
		ID:             ceilingID,
		PayerUserID:    userID,
		CeilingAmount:  amountKobo,
		SequenceStart:  payload.SequenceStart,
		IssuedAt:       payload.IssuedAt,
		ExpiresAt:      payload.ExpiresAt,
		PayerPublicKey: payerPub,
		BankKeyID:      bankKey.KeyID,
		BankSignature:  sig,
		LienAccountID:  lienAcc,
	})
	if err != nil {
		return domain.CeilingToken{}, fmt.Errorf("wallet: insert ceiling: %w", err)
	}

	// 7) Business-event row. id == txnID so the upcoming ledger posts'
	//    txn_id FK to transactions(id) lands at COMMIT.
	txnID := s.NewID()
	if err := repo.RecordTransaction(ctx, pgrepo.RecordTransactionParams{
		ID:         txnID,
		GroupID:    txnID,
		UserID:     userID,
		Kind:       domain.TxKindOfflineFund,
		Status:     domain.TxStatusCompleted,
		Direction:  "DEBIT",
		AmountKobo: amountKobo,
		Memo:       "offline wallet fund",
		CeilingID:  &ceilingID,
	}); err != nil {
		return domain.CeilingToken{}, fmt.Errorf("wallet: record transaction: %w", err)
	}

	// 8) Double-entry ledger posting: debit main, credit lien_holding.
	if err := repo.PostLedger(ctx, txnID, []pgrepo.LedgerLeg{
		{AccountID: mainAcc, Direction: "DEBIT", Amount: amountKobo, Memo: "offline wallet fund"},
		{AccountID: lienAcc, Direction: "CREDIT", Amount: amountKobo, Memo: "offline wallet fund"},
	}); err != nil {
		return domain.CeilingToken{}, fmt.Errorf("wallet: post ledger: %w", err)
	}

	// 9) Balance updates.
	if err := repo.DebitAccount(ctx, mainAcc, amountKobo); err != nil {
		return domain.CeilingToken{}, fmt.Errorf("wallet: debit main: %w", err)
	}
	if err := repo.CreditAccount(ctx, lienAcc, amountKobo); err != nil {
		return domain.CeilingToken{}, fmt.Errorf("wallet: credit lien: %w", err)
	}

	return ct, nil
}

// signCeiling dispatches to the configured Signer, or falls back to
// in-process signing when none is wired. Splitting this out keeps the
// FundOffline / Refresh code paths identical regardless of signer mode.
func (s *Service) signCeiling(ctx context.Context, bankKey domain.BankSigningKey, payload domain.CeilingTokenPayload) ([]byte, error) {
	if s.Signer != nil {
		return crypto.SignCeilingWithSigner(ctx, s.Signer, bankKey.KeyID, payload)
	}
	if len(bankKey.PrivateKey) != ed25519.PrivateKeySize {
		return nil, fmt.Errorf("wallet: bank key %q has no usable private half and no Signer is configured", bankKey.KeyID)
	}
	return crypto.SignCeiling(ed25519.PrivateKey(bankKey.PrivateKey), payload)
}

// MoveToMain drains the offline wallet back to main. Refuses with
// ErrUnsettledClaims if any payment tokens against this ceiling are still
// PENDING or SUBMITTED — those funds are legitimately owed to merchants.
func (s *Service) MoveToMain(ctx context.Context, userID string) error {
	return s.Repo.Tx(ctx, func(repo Repository) error {
		return s.moveToMainInTx(ctx, repo, userID)
	})
}

func (s *Service) moveToMainInTx(ctx context.Context, repo Repository, userID string) error {
	active, err := repo.GetActiveCeiling(ctx, userID)
	if err != nil {
		if isNoRows(err) {
			return ErrNoActiveCeiling
		}
		return fmt.Errorf("wallet: load active ceiling: %w", err)
	}
	inflight, err := repo.CountInFlightPaymentsForCeiling(ctx, active.ID)
	if err != nil {
		return fmt.Errorf("wallet: count in-flight claims: %w", err)
	}
	if inflight > 0 {
		return ErrUnsettledClaims
	}
	return s.releaseCeiling(ctx, repo, userID, active, domain.CeilingRevoked, domain.TxKindOfflineDrain, "offline wallet drain")
}

// Refresh is equivalent to MoveToMain + FundOffline executed atomically.
// Use when a user wants to rotate their ceiling (new expiry, new amount).
func (s *Service) Refresh(ctx context.Context, userID string, newAmount int64, ttl time.Duration) (domain.CeilingToken, error) {
	if newAmount <= 0 {
		return domain.CeilingToken{}, fmt.Errorf("wallet: amount must be positive")
	}
	if ttl <= 0 {
		return domain.CeilingToken{}, fmt.Errorf("wallet: ttl must be positive")
	}

	if gate := s.Fraud; gate != nil {
		allowed, _, err := gate.ClampCeiling(ctx, userID, newAmount)
		if err != nil {
			return domain.CeilingToken{}, fmt.Errorf("wallet: fraud clamp: %w", err)
		}
		if allowed <= 0 {
			return domain.CeilingToken{}, ErrSuspended
		}
		if allowed < newAmount {
			newAmount = allowed
		}
	}

	var issued domain.CeilingToken
	err := s.Repo.Tx(ctx, func(repo Repository) error {
		if err := s.moveToMainInTx(ctx, repo, userID); err != nil && !errors.Is(err, ErrNoActiveCeiling) {
			return err
		}
		t, err := s.fundOfflineInTx(ctx, repo, userID, newAmount, ttl)
		if err != nil {
			return err
		}
		issued = t
		return nil
	})
	if err != nil {
		return domain.CeilingToken{}, err
	}
	if s.SeqTracker != nil {
		if err := s.SeqTracker.RegisterCeiling(ctx, userID, issued.ID, issued.SequenceStart); err != nil {
			return issued, fmt.Errorf("wallet: register sequence start: %w", err)
		}
	}
	return issued, nil
}

// RecoverOfflineCeiling handles the "lost ceiling token on device" case.
// The user no longer has the device-side token needed to sign offline
// payments, but the lien is still locked on their main wallet. Immediate
// refund would race with any already-signed payment a merchant is still
// carrying offline; instead we put the ceiling into RECOVERY_PENDING and
// stamp a release_after far enough in the future that any gossip-carried
// claim can still land and settle. The expiry sweep releases the
// remaining lien amount back to main once that window closes.
//
// Refuses with ErrUnsettledClaims if server-visible claims are still
// in-flight — those funds are owed to merchants and must settle first.
func (s *Service) RecoverOfflineCeiling(ctx context.Context, userID string) (domain.CeilingToken, error) {
	var out domain.CeilingToken
	autoSettle := s.AutoSettleTimeout
	if autoSettle <= 0 {
		autoSettle = DefaultAutoSettleTimeout
	}
	err := s.Repo.Tx(ctx, func(repo Repository) error {
		c, err := repo.GetActiveCeiling(ctx, userID)
		if err != nil {
			if isNoRows(err) {
				return ErrNoActiveCeiling
			}
			return fmt.Errorf("wallet: load active ceiling: %w", err)
		}
		inflight, err := repo.CountInFlightPaymentsForCeiling(ctx, c.ID)
		if err != nil {
			return fmt.Errorf("wallet: count in-flight: %w", err)
		}
		if inflight > 0 {
			return ErrUnsettledClaims
		}
		// releaseAfter = max(expires_at, now) + auto_settle + grace.
		// Using max(expires_at, now) rather than now() matters when the
		// user triggers recovery well before the ceiling's original
		// expiry: we still need to keep the lien around long enough for
		// already-signed payments (valid until expires_at + grace) to
		// propagate and settle.
		now := s.Clock.Now().UTC()
		anchor := c.ExpiresAt
		if anchor.Before(now) {
			anchor = now
		}
		releaseAfter := anchor.Add(autoSettle).Add(ReleaseGrace)
		n, err := repo.MarkCeilingRecoveryPending(ctx, c.ID, releaseAfter)
		if err != nil {
			return fmt.Errorf("wallet: mark recovery: %w", err)
		}
		if n == 0 {
			// Row moved out of ACTIVE between GetActiveCeiling and the
			// update — probably a concurrent sweep or another recovery
			// call. Surface it so the HTTP layer can 409.
			return ErrRecoveryRaceLost
		}
		c.Status = domain.CeilingRecoveryPending
		c.ReleaseAfter = &releaseAfter
		out = c
		return nil
	})
	return out, err
}

// ReleaseOnExpiry sweeps ceilings whose quarantine/expiry window has
// passed (now - ReleaseGrace) and which have no in-flight claims.
// Handles both:
//   - ACTIVE ceilings past their normal expiry (tagged
//     OFFLINE_EXPIRY_RELEASE in the activity log).
//   - RECOVERY_PENDING ceilings past their release_after (tagged
//     OFFLINE_RECOVERY_RELEASE).
//
// Idempotent: safe to run on a cron. Returns the number of ceilings
// released.
func (s *Service) ReleaseOnExpiry(ctx context.Context) (int, error) {
	cutoff := s.Clock.Now().UTC().Add(-ReleaseGrace)
	released := 0

	// Candidates are read outside the release tx; each release runs in its
	// own tx so a single bad record doesn't block the rest of the batch.
	candidates, err := s.Repo.ListReleasableExpiredCeilings(ctx, cutoff)
	if err != nil {
		return 0, fmt.Errorf("wallet: list releasable: %w", err)
	}

	for _, c := range candidates {
		err := s.Repo.Tx(ctx, func(repo Repository) error {
			// Re-check in tx — new in-flight claims may have arrived
			// between list and sweep.
			inflight, err := repo.CountInFlightPaymentsForCeiling(ctx, c.ID)
			if err != nil {
				return fmt.Errorf("wallet: recount in-flight: %w", err)
			}
			if inflight > 0 {
				return errStaleCandidate
			}
			terminal := domain.CeilingExpired
			kind := domain.TxKindOfflineExpiryRelease
			memo := "offline wallet expiry release"
			if c.Status == domain.CeilingRecoveryPending {
				terminal = domain.CeilingRevoked
				kind = domain.TxKindOfflineRecoveryRelease
				memo = "offline wallet recovery release"
			}
			return s.releaseCeiling(ctx, repo, c.PayerID, c, terminal, kind, memo)
		})
		if err == nil {
			released++
			continue
		}
		if errors.Is(err, errStaleCandidate) {
			slog.Info("wallet.ceiling_release_skipped",
				"outcome", "stale",
				"user_id", c.PayerID,
				"ceiling_id", c.ID,
				"status", string(c.Status),
				"reason", "in-flight claim arrived between list and sweep",
			)
			continue
		}
		slog.Error("wallet.ceiling_release_failed",
			"outcome", "error",
			"user_id", c.PayerID,
			"ceiling_id", c.ID,
			"status", string(c.Status),
			"err", err,
		)
		return released, err
	}
	return released, nil
}

var errStaleCandidate = errors.New("wallet: stale expiry candidate")

// releaseCeiling moves the ceiling's remaining lien back from
// lien_holding to main, posts the ledger, transitions the ceiling to
// the requested terminal status, and writes a business-event row.
// Assumes caller holds the tx and has already verified there are no
// in-flight claims.
//
// Remaining = ceiling_kobo - sum(settled_amount_kobo) across every
// payment token attached to this ceiling. Debiting the original
// ceiling_kobo blindly would fail the lien account's `balance_kobo >=
// $amount` guard as soon as any merchant claim has already settled a
// kobo against this ceiling, stranding the lien. remaining == 0 means
// the ceiling was already fully spent and release becomes a no-op.
//
// `kind` distinguishes user-initiated drains (TxKindOfflineDrain) from
// expiry-sweeper releases (TxKindOfflineExpiryRelease) for history.
func (s *Service) releaseCeiling(ctx context.Context, repo Repository, userID string, c domain.CeilingToken, terminal domain.CeilingStatus, kind domain.TransactionKind, memo string) error {
	settled, err := repo.SumSettledForCeiling(ctx, c.ID)
	if err != nil {
		return fmt.Errorf("wallet: sum settled: %w", err)
	}
	remaining := c.CeilingAmount - settled
	if remaining < 0 {
		// Defensive: the ceiling was over-settled, which would be a
		// server-side integrity violation (settlement should cap at
		// ceiling_kobo). Treat as zero to avoid poisoning the lien with
		// a negative debit. Operator alerting on the structured log picks
		// this up.
		remaining = 0
	}

	// No-op release: ceiling was fully spent. Still flip the status so
	// the row moves out of ACTIVE/RECOVERY_PENDING and the sweeper stops
	// picking it up.
	if remaining == 0 {
		if err := repo.UpdateCeilingStatus(ctx, c.ID, terminal); err != nil {
			return err
		}
		slog.Info("wallet.ceiling_released",
			"outcome", "success",
			"user_id", userID,
			"ceiling_id", c.ID,
			"terminal", string(terminal),
			"kind", string(kind),
			"ceiling_kobo", c.CeilingAmount,
			"settled_kobo", settled,
			"remaining_kobo", int64(0),
			"note", "ceiling was fully spent; status flipped with no lien movement",
		)
		return nil
	}

	mainAcc, err := repo.GetAccountID(ctx, userID, sqlcgen.AccountKindMain)
	if err != nil {
		return fmt.Errorf("wallet: resolve main: %w", err)
	}
	lienAcc, err := repo.GetAccountID(ctx, userID, sqlcgen.AccountKindLienHolding)
	if err != nil {
		return fmt.Errorf("wallet: resolve lien: %w", err)
	}
	txnID := s.NewID()
	ceilingID := c.ID
	if err := repo.RecordTransaction(ctx, pgrepo.RecordTransactionParams{
		ID:         txnID,
		GroupID:    txnID,
		UserID:     userID,
		Kind:       kind,
		Status:     domain.TxStatusCompleted,
		Direction:  "CREDIT",
		AmountKobo: remaining,
		Memo:       memo,
		CeilingID:  &ceilingID,
	}); err != nil {
		return fmt.Errorf("wallet: record transaction: %w", err)
	}
	if err := repo.PostLedger(ctx, txnID, []pgrepo.LedgerLeg{
		{AccountID: lienAcc, Direction: "DEBIT", Amount: remaining, Memo: memo},
		{AccountID: mainAcc, Direction: "CREDIT", Amount: remaining, Memo: memo},
	}); err != nil {
		return fmt.Errorf("wallet: post ledger: %w", err)
	}
	if err := repo.DebitAccount(ctx, lienAcc, remaining); err != nil {
		return fmt.Errorf("wallet: debit lien: %w", err)
	}
	if err := repo.CreditAccount(ctx, mainAcc, remaining); err != nil {
		return fmt.Errorf("wallet: credit main: %w", err)
	}
	if err := repo.UpdateCeilingStatus(ctx, c.ID, terminal); err != nil {
		return fmt.Errorf("wallet: update ceiling status: %w", err)
	}
	slog.Info("wallet.ceiling_released",
		"outcome", "success",
		"user_id", userID,
		"ceiling_id", c.ID,
		"terminal", string(terminal),
		"kind", string(kind),
		"ceiling_kobo", c.CeilingAmount,
		"settled_kobo", settled,
		"remaining_kobo", remaining,
	)
	return nil
}

// CurrentCeiling is the flat view of a payer's most-recent non-terminal
// ceiling the mobile client needs to render tri-state (active /
// recovery_pending / none). `RemainingKobo` is CeilingKobo minus
// settled, matching the math `releaseCeiling` uses to size the lien
// release; `ReleaseAfter` is populated only for RECOVERY_PENDING rows.
type CurrentCeiling struct {
	ID            string
	Status        domain.CeilingStatus
	CeilingKobo   int64
	SettledKobo   int64
	RemainingKobo int64
	IssuedAt      time.Time
	ExpiresAt     time.Time
	ReleaseAfter  *time.Time
}

// GetCurrentCeiling returns the payer's most recent non-terminal
// ceiling and its live settled total. Returns (nil, nil) when the
// payer has no active or recovering ceiling — the BFF maps that to a
// 200 with an empty body so the client can render the "no offline
// wallet" state without a 404 distinction.
func (s *Service) GetCurrentCeiling(ctx context.Context, userID string) (*CurrentCeiling, error) {
	row, err := s.Repo.GetCurrentCeilingForPayer(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("wallet: load current ceiling: %w", err)
	}
	if row == nil {
		return nil, nil
	}
	return &CurrentCeiling{
		ID:            row.ID,
		Status:        row.Status,
		CeilingKobo:   row.CeilingKobo,
		SettledKobo:   row.SettledKobo,
		RemainingKobo: row.RemainingKobo,
		IssuedAt:      row.IssuedAt,
		ExpiresAt:     row.ExpiresAt,
		ReleaseAfter:  row.ReleaseAfter,
	}, nil
}

// GetBalances returns the per-user account snapshot.
func (s *Service) GetBalances(ctx context.Context, userID string) (Balances, error) {
	var b Balances
	pairs := []struct {
		kind sqlcgen.AccountKind
		out  *int64
	}{
		{sqlcgen.AccountKindMain, &b.Main},
		{sqlcgen.AccountKindLienHolding, &b.LienHolding},
		{sqlcgen.AccountKindReceivingPending, &b.ReceivingPending},
	}
	for _, p := range pairs {
		v, err := s.Repo.GetAccountBalance(ctx, userID, p.kind)
		if err != nil {
			return Balances{}, fmt.Errorf("wallet: balance %s: %w", p.kind, err)
		}
		*p.out = v
	}
	return b, nil
}

// isNoRows detects pgx ErrNoRows without importing pgx at the service layer.
// We deliberately match on substring to stay repo-independent — fake repos
// in tests return our own sentinel, real repo returns pgx.ErrNoRows.
func isNoRows(err error) bool {
	if err == nil {
		return false
	}
	if errors.Is(err, errFakeNoRows) {
		return true
	}
	return err.Error() == "no rows in result set"
}

// errFakeNoRows is used by in-memory test doubles to signal absence.
var errFakeNoRows = errors.New("no rows in result set")

// ErrNoRows is the sentinel fakes and tests should return from Get* methods
// when the row is absent. It stringifies to the same text as pgx.ErrNoRows
// so isNoRows matches either.
var ErrNoRows = errFakeNoRows
