package pgrepo

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

// AllAccountKinds is the canonical per-user account set.
//
// Four kinds, not five — the former `offline` kind was retired in
// migration 0021 because nothing ever wrote to it. The real offline-
// wallet float lives in `lien_holding`, credited by wallet.FundOffline
// and debited during Phase 4b settlement.
var AllAccountKinds = []sqlcgen.AccountKind{
	sqlcgen.AccountKindMain,
	sqlcgen.AccountKindLienHolding,
	sqlcgen.AccountKindReceivingPending,
}

// Repo is a thin wrapper over a pgx pool + sqlc.Queries, exposing
// domain-typed methods. All multi-statement sequences go through Tx.
//
// `cache` is never nil — callers pass cache.Noop{} when Redis is
// disabled or unreachable, so cached call sites don't need nil checks.
type Repo struct {
	pool  *pgxpool.Pool
	q     *sqlcgen.Queries
	cache cache.Cache
}

// New constructs a Repo from a live pgx pool. c may be nil, in which
// case cache.Noop is used.
func New(pool *pgxpool.Pool, c cache.Cache) *Repo {
	if c == nil {
		c = cache.Noop{}
	}
	return &Repo{pool: pool, q: sqlcgen.New(pool), cache: c}
}

// Tx runs fn inside a serializable transaction, passing a Repo view scoped
// to that transaction. On error the tx is rolled back; otherwise committed.
//
// The *Repo passed to fn is bound to the open tx; ALL writes through it
// commit or roll back as one unit. Callers should name the parameter
// `repo` (not `tx`) — it is a Repository view, not a raw pgx.Tx.
func (r *Repo) Tx(ctx context.Context, fn func(*Repo) error) error {
	tx, err := r.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return fmt.Errorf("pgrepo: begin tx: %w", err)
	}
	txRepo := &Repo{pool: r.pool, q: r.q.WithTx(tx), cache: r.cache}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback(context.Background())
		}
	}()
	if err := fn(txRepo); err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return err
	}
	committed = true
	return nil
}

// RegisterUser inserts a user row and its five accounts atomically.
// Returns the user id. `bvn` may be empty (stored as NULL).
//
// This is the legacy/test seed path — it synthesises a placeholder
// first_name/last_name/email/password_hash so the NOT NULL columns
// introduced in migration 0019 remain satisfied. Production signups
// go through userauth.Service.Signup which supplies real values.
func (r *Repo) RegisterUser(ctx context.Context, phone, accountNumber, bvn, kycTier string, realmKeyVersion int) (userID string, err error) {
	if kycTier == "" {
		kycTier = "TIER_0"
	}
	userID = NewID()
	err = r.Tx(ctx, func(tx *Repo) error {
		var bvnPtr *string
		if bvn != "" {
			bvnPtr = &bvn
		}
		if _, err := tx.q.CreateUser(ctx, sqlcgen.CreateUserParams{
			ID:                  userID,
			Phone:               phone,
			AccountNumber:       accountNumber,
			Bvn:                 bvnPtr,
			KycTier:             kycTier,
			DeviceAttestationID: nil,
			RealmKeyVersion:     int32(realmKeyVersion),
			FirstName:           "",
			LastName:            "",
			Email:               placeholderEmail(userID),
			PasswordHash:        "",
		}); err != nil {
			return fmt.Errorf("create user: %w", err)
		}
		for _, kind := range AllAccountKinds {
			if _, err := tx.q.CreateAccount(ctx, sqlcgen.CreateAccountParams{
				ID:          NewID(),
				UserID:      userID,
				Kind:        kind,
				BalanceKobo: 0,
			}); err != nil {
				return fmt.Errorf("create account %s: %w", kind, err)
			}
		}
		return nil
	})
	return
}

// GetUserNameByAccountNumber resolves an account number to the owner's
// user id and display names, filtering out system-tier users at the
// query level. Returns pgx.ErrNoRows when no non-system user owns the
// account number. Powers the demo-mint name-enquiry.
func (r *Repo) GetUserNameByAccountNumber(ctx context.Context, accountNumber string) (userID, firstName, lastName string, err error) {
	row, err := r.q.GetUserNameByAccountNumber(ctx, accountNumber)
	if err != nil {
		return "", "", "", err
	}
	return row.ID, row.FirstName, row.LastName, nil
}

// GetAccountID returns the account id for (userID, kind).
func (r *Repo) GetAccountID(ctx context.Context, userID string, kind sqlcgen.AccountKind) (string, error) {
	a, err := r.q.GetAccountByUserAndKind(ctx, sqlcgen.GetAccountByUserAndKindParams{
		UserID: userID, Kind: kind,
	})
	if err != nil {
		return "", err
	}
	return a.ID, nil
}

// GetAccountBalance returns the balance in kobo for (userID, kind).
func (r *Repo) GetAccountBalance(ctx context.Context, userID string, kind sqlcgen.AccountKind) (int64, error) {
	a, err := r.q.GetAccountByUserAndKind(ctx, sqlcgen.GetAccountByUserAndKindParams{
		UserID: userID, Kind: kind,
	})
	if err != nil {
		return 0, err
	}
	return a.BalanceKobo, nil
}

// DebitAccount decrements an account balance; fails if insufficient funds.
// The underlying UPDATE has a balance_kobo >= $2 guard: if the account has
// less than `amount` available, the row is not updated and pgx returns
// ErrNoRows.
func (r *Repo) DebitAccount(ctx context.Context, accountID string, amount int64) error {
	_, err := r.q.DecrementAccountBalance(ctx, sqlcgen.DecrementAccountBalanceParams{
		ID: accountID, BalanceKobo: amount,
	})
	return err
}

// ForceDebitAccount decrements without the balance >= amount guard. Intended
// for accounts that are permitted to go negative (e.g. the system suspense
// account between Phase 4a and 4b).
func (r *Repo) ForceDebitAccount(ctx context.Context, accountID string, amount int64) error {
	_, err := r.q.ForceDecrementAccountBalance(ctx, sqlcgen.ForceDecrementAccountBalanceParams{
		ID: accountID, BalanceKobo: amount,
	})
	return err
}

// CreditAccount increments an account balance.
func (r *Repo) CreditAccount(ctx context.Context, accountID string, amount int64) error {
	_, err := r.q.IncrementAccountBalance(ctx, sqlcgen.IncrementAccountBalanceParams{
		ID: accountID, BalanceKobo: amount,
	})
	return err
}

// SetUserPayerPubkey rotates the user's active Ed25519 signing key:
// retire any previously active row, then insert the new one. Old rows
// stay in the table for audit/rotation history.
func (r *Repo) SetUserPayerPubkey(ctx context.Context, userID string, pubkey []byte) error {
	return r.Tx(ctx, func(tx *Repo) error {
		if err := tx.q.RetireActiveSigningKey(ctx, userID); err != nil {
			return fmt.Errorf("retire signing key: %w", err)
		}
		if _, err := tx.q.InsertSigningKey(ctx, sqlcgen.InsertSigningKeyParams{
			ID:        NewID(),
			UserID:    userID,
			DeviceID:  nil,
			PublicKey: pubkey,
		}); err != nil {
			return fmt.Errorf("insert signing key: %w", err)
		}
		return nil
	})
}

// GetUserPayerPubkey fetches the user's currently active Ed25519 signing
// public key. Returns a nil slice if the user has not registered one.
func (r *Repo) GetUserPayerPubkey(ctx context.Context, userID string) ([]byte, error) {
	pub, err := r.q.GetActiveSigningKeyPubkey(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return pub, nil
}

// CountInFlightPaymentsForCeiling returns the number of PENDING or
// SUBMITTED payment tokens referencing this ceiling.
func (r *Repo) CountInFlightPaymentsForCeiling(ctx context.Context, ceilingID string) (int64, error) {
	return r.q.CountInFlightPaymentsForCeiling(ctx, ceilingID)
}

// SumSettledForCeiling returns the total settled_amount_kobo across
// every payment token referencing this ceiling. Used by releaseCeiling
// so we debit only the lien that's actually still held after any
// partial settlements.
func (r *Repo) SumSettledForCeiling(ctx context.Context, ceilingID string) (int64, error) {
	return r.q.SumSettledForCeiling(ctx, ceilingID)
}

// GetCurrentCeilingForPayer returns the payer's most recent non-terminal
// ceiling (ACTIVE or RECOVERY_PENDING) together with its live settled
// total. Returns (nil, nil) when the payer has no active ceiling.
// Used by the BFF ceiling-status endpoint so the mobile client can
// render tri-state without a second RPC.
func (r *Repo) GetCurrentCeilingForPayer(ctx context.Context, payerUserID string) (*CurrentCeilingRow, error) {
	row, err := r.q.GetCurrentCeilingForPayer(ctx, payerUserID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	out := CurrentCeilingRow{
		ID:            row.ID,
		Status:        domain.CeilingStatus(row.Status),
		CeilingKobo:   row.CeilingKobo,
		SettledKobo:   row.SettledKobo,
		RemainingKobo: row.RemainingKobo,
		IssuedAt:      row.IssuedAt.Time.UTC(),
		ExpiresAt:     row.ExpiresAt.Time.UTC(),
	}
	if row.ReleaseAfter.Valid {
		t := row.ReleaseAfter.Time.UTC()
		out.ReleaseAfter = &t
	}
	return &out, nil
}

// CurrentCeilingRow is the flat projection returned to the wallet
// service for rendering the ceiling-status card to mobile. Separate
// from domain.CeilingToken because we add the live settled / remaining
// derived fields.
type CurrentCeilingRow struct {
	ID            string
	Status        domain.CeilingStatus
	CeilingKobo   int64
	SettledKobo   int64
	RemainingKobo int64
	IssuedAt      time.Time
	ExpiresAt     time.Time
	ReleaseAfter  *time.Time
}

// ListReleasableExpiredCeilings returns ACTIVE ceilings whose expiry is
// before `before` and which have no in-flight claims.
func (r *Repo) ListReleasableExpiredCeilings(ctx context.Context, before time.Time) ([]domain.CeilingToken, error) {
	rows, err := r.q.ListReleasableExpiredCeilings(ctx, tsz(before))
	if err != nil {
		return nil, err
	}
	out := make([]domain.CeilingToken, len(rows))
	for i, row := range rows {
		out[i] = ceilingToDomain(row)
	}
	return out, nil
}

// IssueCeilingParams is the argument for IssueCeilingToken.
type IssueCeilingParams struct {
	ID             string
	PayerUserID    string
	CeilingAmount  int64
	SequenceStart  int64
	IssuedAt       time.Time
	ExpiresAt      time.Time
	PayerPublicKey []byte
	BankKeyID      string
	BankSignature  []byte
	LienAccountID  string
}

// IssueCeilingToken creates a new ACTIVE ceiling. Enforces one-active-per-user
// via the partial unique index at the DB level.
func (r *Repo) IssueCeilingToken(ctx context.Context, p IssueCeilingParams) (domain.CeilingToken, error) {
	if p.ID == "" {
		p.ID = NewID()
	}
	row, err := r.q.CreateCeilingToken(ctx, sqlcgen.CreateCeilingTokenParams{
		ID:            p.ID,
		PayerUserID:   p.PayerUserID,
		CeilingKobo:   p.CeilingAmount,
		SequenceStart: p.SequenceStart,
		IssuedAt:      tsz(p.IssuedAt),
		ExpiresAt:     tsz(p.ExpiresAt),
		PayerPubkey:   p.PayerPublicKey,
		BankKeyID:     p.BankKeyID,
		BankSig:       p.BankSignature,
		Status:        sqlcgen.CeilingStatusACTIVE,
		LienAccountID: p.LienAccountID,
	})
	if err != nil {
		return domain.CeilingToken{}, err
	}
	return ceilingToDomain(row), nil
}

// GetCeilingToken fetches by id.
func (r *Repo) GetCeilingToken(ctx context.Context, id string) (domain.CeilingToken, error) {
	row, err := r.q.GetCeilingToken(ctx, id)
	if err != nil {
		return domain.CeilingToken{}, err
	}
	return ceilingToDomain(row), nil
}

// GetActiveCeiling returns the one ACTIVE ceiling for a user, or ErrNoRows.
func (r *Repo) GetActiveCeiling(ctx context.Context, userID string) (domain.CeilingToken, error) {
	row, err := r.q.GetActiveCeilingForUser(ctx, userID)
	if err != nil {
		return domain.CeilingToken{}, err
	}
	return ceilingToDomain(row), nil
}

// UpdateCeilingStatus transitions a ceiling to a new status.
func (r *Repo) UpdateCeilingStatus(ctx context.Context, id string, status domain.CeilingStatus) error {
	return r.q.UpdateCeilingStatus(ctx, sqlcgen.UpdateCeilingStatusParams{
		ID:     id,
		Status: sqlcgen.CeilingStatus(status),
	})
}

// MarkCeilingRecoveryPending atomically flips the given (active) ceiling
// into the RECOVERY_PENDING state and stamps the release window. Returns
// the number of rows affected — 0 means the ceiling is not ACTIVE (race
// with another caller, already recovering, or already terminal).
func (r *Repo) MarkCeilingRecoveryPending(ctx context.Context, id string, releaseAfter time.Time) (int64, error) {
	return r.q.MarkCeilingRecoveryPending(ctx, sqlcgen.MarkCeilingRecoveryPendingParams{
		ID:           id,
		ReleaseAfter: tsz(releaseAfter),
	})
}

// CreatePaymentParams captures a server-recorded payment token. SignedAt
// is the device-clock timestamp included in the canonically-signed
// payload — the wire-side field is still called "timestamp" for
// backward compat with mobile/proto consumers.
type CreatePaymentParams struct {
	ID                string
	CeilingID         string
	PayerUserID       string
	PayeeUserID       string
	Amount            int64
	SequenceNumber    int64
	RemainingCeiling  int64
	SignedAt          time.Time
	PayerSignature    []byte
	Status            domain.TransactionStatus
	SessionNonce      []byte // from the PaymentRequest the payer signed over
	RequestHash       []byte // sha256(canonical(PaymentRequest))
	RequestAmountKobo int64  // PR.amount; 0 = unbound (P2P fallback)
	// SubmittedByUserID names the authenticated party whose /v1/settlement
	// /claims call landed this row. Either the payer or the payee — Phase
	// 4a accepts from either side (whichever reaches connectivity first).
	// Empty string persists as NULL (only for callers that pre-date 0028).
	SubmittedByUserID string
}

// CreatePayment inserts a new payment row. UNIQUE (payer_user_id, sequence_number)
// guarantees idempotency on the payer side. A second unique constraint on
// (payee_user_id, session_nonce) makes the receiver's session_nonce
// single-use, closing the PR-replay window.
func (r *Repo) CreatePayment(ctx context.Context, p CreatePaymentParams) (domain.Transaction, error) {
	if p.ID == "" {
		p.ID = NewID()
	}
	if p.Status == "" {
		p.Status = domain.TxQueued
	}
	var submittedBy *string
	if p.SubmittedByUserID != "" {
		sb := p.SubmittedByUserID
		submittedBy = &sb
	}
	row, err := r.q.CreatePaymentToken(ctx, sqlcgen.CreatePaymentTokenParams{
		ID:                   p.ID,
		CeilingID:            p.CeilingID,
		PayerUserID:          p.PayerUserID,
		PayeeUserID:          p.PayeeUserID,
		AmountKobo:           p.Amount,
		SequenceNumber:       p.SequenceNumber,
		RemainingCeilingKobo: p.RemainingCeiling,
		SignedAt:             tsz(p.SignedAt),
		PayerSig:             p.PayerSignature,
		Status:               sqlcgen.PaymentStatus(p.Status),
		SessionNonce:         p.SessionNonce,
		RequestHash:          p.RequestHash,
		RequestAmountKobo:    p.RequestAmountKobo,
		SubmittedByUserID:    submittedBy,
	})
	if err != nil {
		return domain.Transaction{}, err
	}
	return paymentToDomainTxn(row), nil
}

// GetPayment fetches a payment by id.
func (r *Repo) GetPayment(ctx context.Context, id string) (domain.Transaction, error) {
	row, err := r.q.GetPaymentToken(ctx, id)
	if err != nil {
		return domain.Transaction{}, err
	}
	return paymentToDomainTxn(row), nil
}

// GetPaymentBySequence looks up a payment by (payer_user_id, sequence_number).
// Returns ErrNoRows-shaped error from pgx on absence.
func (r *Repo) GetPaymentBySequence(ctx context.Context, payerUserID string, sequenceNumber int64) (domain.Transaction, error) {
	row, err := r.q.GetPaymentBySequence(ctx, sqlcgen.GetPaymentBySequenceParams{
		PayerUserID:    payerUserID,
		SequenceNumber: sequenceNumber,
	})
	if err != nil {
		return domain.Transaction{}, err
	}
	return paymentToDomainTxn(row), nil
}

// ListPayersWithStalePending returns distinct payer ids whose oldest
// PENDING payment was submitted before `olderThan`.
func (r *Repo) ListPayersWithStalePending(ctx context.Context, olderThan time.Time) ([]string, error) {
	rows, err := r.q.ListPayersWithStalePending(ctx, tsz(olderThan))
	if err != nil {
		return nil, err
	}
	out := make([]string, len(rows))
	for i, row := range rows {
		out[i] = row.PayerUserID
	}
	return out, nil
}

// ListPendingForPayer lists PENDING payments for a payer in sequence order.
func (r *Repo) ListPendingForPayer(ctx context.Context, payerUserID string) ([]domain.Transaction, error) {
	rows, err := r.q.ListPendingPaymentsByPayer(ctx, payerUserID)
	if err != nil {
		return nil, err
	}
	out := make([]domain.Transaction, len(rows))
	for i, r := range rows {
		out[i] = paymentToDomainTxn(r)
	}
	return out, nil
}

// UpdatePaymentStatus applies a status change with associated settlement metadata.
func (r *Repo) UpdatePaymentStatus(ctx context.Context, id string, status domain.TransactionStatus,
	settledAmount int64, rejectionReason string, batchID *string,
	submittedAt, settledAt *time.Time,
) (domain.Transaction, error) {
	row, err := r.q.UpdatePaymentStatus(ctx, sqlcgen.UpdatePaymentStatusParams{
		ID:                id,
		Status:            sqlcgen.PaymentStatus(status),
		RejectionReason:   strPtr(rejectionReason),
		SettledAmountKobo: settledAmount,
		SettlementBatchID: batchID,
		SubmittedAt:       tszPtr(submittedAt),
		SettledAt:         tszPtr(settledAt),
	})
	if err != nil {
		return domain.Transaction{}, err
	}
	return paymentToDomainTxn(row), nil
}

// EnsureSystemSuspenseAccount re-seeds the singleton suspense account +
// its owning system user. Idempotent — migration 0005 seeds both at
// install time, but we still call this at BFF startup so a partially-
// migrated DB can't leave Phase 4a ledger posts failing with a foreign-
// key violation ("ledger_entries_account_id_fkey").
func (r *Repo) EnsureSystemSuspenseAccount(ctx context.Context) error {
	return r.q.EnsureSystemSuspenseAccount(ctx)
}

// InsertFinalizeOutbox enqueues a Phase 4b finalize event for payerUserID.
// Callers run this inside an existing tx (via Repo.Tx) so the enqueue is
// atomic with the business write that motivated it — no lost events if
// the tx rolls back, no premature publishes before the state exists.
//
// Aggregate / subject are pinned to the settlement-finalize constants in
// `internal/domain/outbox.go` so both producer and consumer reference the
// same strings.
func (r *Repo) InsertFinalizeOutbox(ctx context.Context, outboxID, payerUserID string, payload []byte) error {
	return r.q.InsertOutboxEntry(ctx, sqlcgen.InsertOutboxEntryParams{
		ID:          outboxID,
		Aggregate:   domain.OutboxAggregateSettlementFinalize,
		AggregateID: payerUserID,
		Payload:     payload,
	})
}

// LedgerLeg is one side of a double-entry posting.
type LedgerLeg struct {
	AccountID string
	Direction string // "DEBIT" | "CREDIT"
	Amount    int64
	Memo      string
}

// PostLedger inserts a balanced set of ledger entries under a single txn_id.
// The ledger-balance constraint trigger is DEFERRED — mismatched legs will
// cause the enclosing transaction to fail at commit.
//
// Callers typically invoke PostLedger from inside r.Tx(...) so that other
// writes (balance updates, ceiling state transitions) are committed together.
func (r *Repo) PostLedger(ctx context.Context, txnID string, legs []LedgerLeg) error {
	if txnID == "" {
		return errors.New("pgrepo: txnID required")
	}
	if len(legs) < 2 {
		return errors.New("pgrepo: double-entry requires at least 2 legs")
	}
	for _, leg := range legs {
		dir := sqlcgen.LedgerDirectionDEBIT
		switch leg.Direction {
		case "DEBIT":
			dir = sqlcgen.LedgerDirectionDEBIT
		case "CREDIT":
			dir = sqlcgen.LedgerDirectionCREDIT
		default:
			return fmt.Errorf("pgrepo: unknown direction %q", leg.Direction)
		}
		if _, err := r.q.InsertLedgerEntry(ctx, sqlcgen.InsertLedgerEntryParams{
			ID:         NewID(),
			TxnID:      txnID,
			AccountID:  leg.AccountID,
			Direction:  dir,
			AmountKobo: leg.Amount,
			Memo:       strPtr(leg.Memo),
		}); err != nil {
			return fmt.Errorf("pgrepo: insert ledger leg: %w", err)
		}
	}
	return nil
}

// UpsertBankSigningKey stores a bank signing key (privkey should already be
// encrypted at rest by the caller).
func (r *Repo) UpsertBankSigningKey(ctx context.Context, k domain.BankSigningKey) error {
	activeFrom := k.ActiveFrom
	if activeFrom.IsZero() {
		activeFrom = time.Now().UTC()
	}
	_, err := r.q.CreateBankSigningKey(ctx, sqlcgen.CreateBankSigningKeyParams{
		KeyID:      k.KeyID,
		Pubkey:     k.PublicKey,
		PrivkeyEnc: k.PrivateKey,
		ActiveFrom: tsz(activeFrom),
	})
	if err == nil {
		_ = r.cache.Del(ctx, bankSigningActiveCacheKey)
	}
	return err
}

// GetBankSigningKey fetches a key by id.
func (r *Repo) GetBankSigningKey(ctx context.Context, keyID string) (domain.BankSigningKey, error) {
	row, err := r.q.GetBankSigningKey(ctx, keyID)
	if err != nil {
		return domain.BankSigningKey{}, err
	}
	return bankKeyToDomain(row), nil
}

// GetActiveBankSigningKey returns the currently-active bank signing key.
//
// Cached under bank:sig:active (TTL 1h). Hot on the settlement claim
// path: every SubmitClaim verifies offline payment signatures against
// this key. Rotation (UpsertBankSigningKey) invalidates the key.
func (r *Repo) GetActiveBankSigningKey(ctx context.Context) (domain.BankSigningKey, error) {
	var cached domain.BankSigningKey
	if hit, _ := cache.GetJSON(ctx, r.cache, bankSigningActiveCacheKey, &cached); hit {
		return cached, nil
	}
	row, err := r.q.GetActiveBankSigningKey(ctx)
	if err != nil {
		return domain.BankSigningKey{}, err
	}
	k := bankKeyToDomain(row)
	_ = cache.SetJSON(ctx, r.cache, bankSigningActiveCacheKey, k, bankSigningActiveCacheTTL)
	return k, nil
}

const (
	bankSigningActiveCacheKey = "bank:sig:active"
	bankSigningActiveCacheTTL = time.Hour
)

// UpsertRealmKey stores a realm key version (key_enc is caller-encrypted).
func (r *Repo) UpsertRealmKey(ctx context.Context, version int, keyEnc []byte, activeFrom time.Time) error {
	_, err := r.q.CreateRealmKey(ctx, sqlcgen.CreateRealmKeyParams{
		Version:    int32(version),
		KeyEnc:     keyEnc,
		ActiveFrom: tsz(activeFrom),
	})
	if err == nil {
		_ = r.cache.Del(ctx, realmActiveCacheKey, realmActiveListCacheKey)
	}
	return err
}

// GetActiveRealmKey returns the currently-active realm key row.
func (r *Repo) GetActiveRealmKey(ctx context.Context) (domain.RealmKey, error) {
	var cached domain.RealmKey
	if hit, _ := cache.GetJSON(ctx, r.cache, realmActiveCacheKey, &cached); hit {
		return cached, nil
	}
	row, err := r.q.GetActiveRealmKey(ctx)
	if err != nil {
		return domain.RealmKey{}, err
	}
	k := realmKeyToDomain(row)
	_ = cache.SetJSON(ctx, r.cache, realmActiveCacheKey, k, realmKeyCacheTTL)
	return k, nil
}

// GetRealmKey returns a specific realm-key version. Used by clients that
// discover an unknown key_version byte on a QR and want to backfill.
func (r *Repo) GetRealmKey(ctx context.Context, version int) (domain.RealmKey, error) {
	row, err := r.q.GetRealmKey(ctx, int32(version))
	if err != nil {
		return domain.RealmKey{}, err
	}
	return realmKeyToDomain(row), nil
}

// ListActiveRealmKeys returns all realm-key versions still inside their
// overlap window, ordered newest-first. Clients fetch the whole set so
// they can decrypt a backlog of QRs sealed under older versions. limit
// defaults to 3 when <= 0.
//
// Cached under realm:active:list (TTL 1h). Cache is keyed on the
// default (limit <= 0 / == 3) only — non-default limits bypass the
// cache to keep the key space bounded. Rotation invalidates via
// UpsertRealmKey/RetireRealmKey.
func (r *Repo) ListActiveRealmKeys(ctx context.Context, limit int) ([]domain.RealmKey, error) {
	useCache := limit <= 0 || limit == 3
	if limit <= 0 {
		limit = 3
	}
	if useCache {
		var cached []domain.RealmKey
		if hit, _ := cache.GetJSON(ctx, r.cache, realmActiveListCacheKey, &cached); hit {
			return cached, nil
		}
	}
	rows, err := r.q.ListActiveRealmKeys(ctx, int32(limit))
	if err != nil {
		return nil, err
	}
	out := make([]domain.RealmKey, 0, len(rows))
	for _, row := range rows {
		out = append(out, realmKeyToDomain(row))
	}
	if useCache {
		_ = cache.SetJSON(ctx, r.cache, realmActiveListCacheKey, out, realmKeyCacheTTL)
	}
	return out, nil
}

const (
	realmActiveCacheKey     = "realm:active"
	realmActiveListCacheKey = "realm:active:list"
	realmKeyCacheTTL        = time.Hour
)

// RetireRealmKey marks a version retired, after which it remains
// decrypt-only until retired_at elapses and it is GC'd.
func (r *Repo) RetireRealmKey(ctx context.Context, version int, retiredAt time.Time) error {
	if err := r.q.RetireRealmKey(ctx, sqlcgen.RetireRealmKeyParams{
		Version:   int32(version),
		RetiredAt: tsz(retiredAt),
	}); err != nil {
		return err
	}
	_ = r.cache.Del(ctx, realmActiveCacheKey, realmActiveListCacheKey)
	return nil
}

// DeleteExpiredRealmKeys hard-removes keys whose retired_at is in the
// past. Used by the rotate_realm_key ops command.
func (r *Repo) DeleteExpiredRealmKeys(ctx context.Context) error {
	return r.q.DeleteExpiredRealmKeys(ctx)
}

// InsertFraudSignal records a fraud event.
func (r *Repo) InsertFraudSignal(ctx context.Context, ev domain.FraudEvent, weight float64) (domain.FraudEvent, error) {
	if ev.ID == "" {
		ev.ID = NewID()
	}
	if ev.Severity == "" {
		ev.Severity = "LOW"
	}
	row, err := r.q.InsertFraudSignal(ctx, sqlcgen.InsertFraudSignalParams{
		ID:             ev.ID,
		UserID:         ev.UserID,
		SignalType:     sqlcgen.FraudSignalType(ev.SignalType),
		CeilingTokenID: ev.CeilingTokenID,
		TransactionID:  ev.TransactionID,
		Details:        ev.Details,
		Severity:       ev.Severity,
		Weight:         weight,
	})
	if err != nil {
		return domain.FraudEvent{}, err
	}
	return fraudToDomain(row), nil
}

// ListFraudSignalsForUser returns all fraud signals attributed to userID,
// ordered by created_at DESC.
func (r *Repo) ListFraudSignalsForUser(ctx context.Context, userID string) ([]domain.FraudEvent, error) {
	rows, err := r.q.ListFraudSignalsForUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]domain.FraudEvent, len(rows))
	for i, row := range rows {
		out[i] = fraudToDomain(row)
	}
	return out, nil
}

// RegisterDevice attests a device for a user. Enforces "one active device
// per user" via a partial unique index.
func (r *Repo) RegisterDevice(ctx context.Context, userID string, attestation, publicKey []byte) (string, error) {
	id := NewID()
	now := time.Now().UTC()
	_, err := r.q.CreateDevice(ctx, sqlcgen.CreateDeviceParams{
		ID:              id,
		UserID:          userID,
		AttestationBlob: attestation,
		PublicKey:       publicKey,
		Active:          true,
		LastSeenAt:      tsz(now),
	})
	if err == nil {
		// Fresh id; Del is defensive against a retry that re-registered
		// after the same JWT caused a stale miss to be cached.
		_ = r.cache.Del(ctx, deviceAuthCacheKey(id))
	}
	return id, err
}

// TouchDevice updates last_seen_at.
func (r *Repo) TouchDevice(ctx context.Context, deviceID string, seenAt time.Time) error {
	return r.q.TouchDevice(ctx, sqlcgen.TouchDeviceParams{
		ID:         deviceID,
		LastSeenAt: tsz(seenAt),
	})
}

// DeactivateDevice marks a device inactive. The partial-unique-index on
// (user_id) WHERE active=TRUE guarantees at most one active device per user,
// so a replacement can be inserted only once the old row is flipped here.
//
// Invalidates dev:auth:<deviceID> so the next auth lookup re-reads from
// Postgres and caches active=false. Safe even inside a transaction: if
// the tx rolls back, the next read just misses and rebuilds the cache
// from the (still-active) DB row.
func (r *Repo) DeactivateDevice(ctx context.Context, deviceID string) error {
	if err := r.q.DeactivateDevice(ctx, deviceID); err != nil {
		return err
	}
	_ = r.cache.Del(ctx, deviceAuthCacheKey(deviceID))
	return nil
}

// ActiveDeviceInfo is the minimal device slice callers outside pgrepo need.
type ActiveDeviceInfo struct {
	ID        string
	UserID    string
	PublicKey []byte
	Active    bool
}

// GetActiveDeviceForUser returns the single active device row for a user.
func (r *Repo) GetActiveDeviceForUser(ctx context.Context, userID string) (ActiveDeviceInfo, error) {
	row, err := r.q.GetActiveDeviceForUser(ctx, userID)
	if err != nil {
		return ActiveDeviceInfo{}, err
	}
	return ActiveDeviceInfo{
		ID:        row.ID,
		UserID:    row.UserID,
		PublicKey: row.PublicKey,
		Active:    row.Active,
	}, nil
}

// LookupDeviceForAuth returns the owning user id, the Ed25519 public key
// used to verify device JWTs, and whether the device is still active.
// A non-nil error means "unknown device"; callers map both inactive and
// unknown to Unauthenticated.
//
// Cache-aside on dev:auth:<deviceID>; TTL is 1 hour — a safety net only,
// since DeactivateDevice / RegisterDevice invalidate explicitly.
func (r *Repo) LookupDeviceForAuth(ctx context.Context, deviceID string) (string, []byte, bool, error) {
	key := deviceAuthCacheKey(deviceID)
	var cached cachedDeviceAuth
	if hit, _ := cache.GetJSON(ctx, r.cache, key, &cached); hit {
		return cached.UserID, cached.PublicKey, cached.Active, nil
	}
	row, err := r.q.GetDevice(ctx, deviceID)
	if err != nil {
		return "", nil, false, err
	}
	_ = cache.SetJSON(ctx, r.cache, key, cachedDeviceAuth{
		UserID:    row.UserID,
		PublicKey: row.PublicKey,
		Active:    row.Active,
	}, deviceAuthCacheTTL)
	return row.UserID, row.PublicKey, row.Active, nil
}

const deviceAuthCacheTTL = time.Hour

// cachedDeviceAuth is the JSON-serialised value stored under
// dev:auth:<device_id>. Go's encoding/json base64-encodes []byte so the
// stored form is valid UTF-8.
type cachedDeviceAuth struct {
	UserID    string `json:"user_id"`
	PublicKey []byte `json:"public_key"`
	Active    bool   `json:"active"`
}

func deviceAuthCacheKey(deviceID string) string { return "dev:auth:" + deviceID }

// RecordTransactionParams captures one row in the transactions table.
// For two-party events the caller inserts twice: once per user, with
// the same GroupID and inverse Direction. The DEBIT side's ID is the
// value used for ledger_entries.txn_id so the FK lands.
type RecordTransactionParams struct {
	ID                 string
	GroupID            string
	UserID             string
	CounterpartyUserID *string
	Kind               domain.TransactionKind
	Status             domain.TransactionLifecycleStatus
	Direction          string // "DEBIT" | "CREDIT"
	AmountKobo         int64
	SettledAmountKobo  *int64
	Memo               string
	PaymentTokenID     *string
	TransferID         *string
	CeilingID          *string
	FailureReason      *string
}

// RecordTransaction inserts one row into the transactions table. Must
// run inside the same Repo.Tx as the ledger posts and balance updates
// it documents — otherwise the deferred ledger FK fails at COMMIT.
func (r *Repo) RecordTransaction(ctx context.Context, p RecordTransactionParams) error {
	var memoPtr *string
	if p.Memo != "" {
		m := p.Memo
		memoPtr = &m
	}
	return r.q.RecordTransaction(ctx, sqlcgen.RecordTransactionParams{
		ID:                 p.ID,
		GroupID:            p.GroupID,
		UserID:             p.UserID,
		CounterpartyUserID: p.CounterpartyUserID,
		Kind:               sqlcgen.TransactionKind(p.Kind),
		Status:             sqlcgen.TransactionLifecycleStatus(p.Status),
		Direction:          sqlcgen.LedgerDirection(p.Direction),
		AmountKobo:         p.AmountKobo,
		SettledAmountKobo:  p.SettledAmountKobo,
		Memo:               memoPtr,
		PaymentTokenID:     p.PaymentTokenID,
		TransferID:         p.TransferID,
		CeilingID:          p.CeilingID,
		FailureReason:      p.FailureReason,
	})
}

// UpdateTransactionStatus flips one transactions row's status and
// optionally sets settled_amount_kobo / failure_reason. Pass nil for
// fields that should not change. Used by settlement/transfer finalise
// paths to advance PENDING → COMPLETED / FAILED.
func (r *Repo) UpdateTransactionStatus(ctx context.Context, id string, status domain.TransactionLifecycleStatus, settled *int64, failureReason *string) error {
	return r.q.UpdateTransactionStatus(ctx, sqlcgen.UpdateTransactionStatusParams{
		ID:                id,
		Status:            sqlcgen.TransactionLifecycleStatus(status),
		SettledAmountKobo: settled,
		FailureReason:     failureReason,
	})
}

// ListTransactionsByGroup returns every row sharing the given group_id.
// Used by finalise paths that must flip both rows of a paired event.
func (r *Repo) ListTransactionsByGroup(ctx context.Context, groupID string) ([]domain.UserTransaction, error) {
	rows, err := r.q.ListTransactionsByGroup(ctx, groupID)
	if err != nil {
		return nil, err
	}
	out := make([]domain.UserTransaction, len(rows))
	for i, row := range rows {
		out[i] = txnRowToDomain(row)
	}
	return out, nil
}

// TransactionAnchor identifies the DEBIT-side (payer / sender)
// transactions row for a given source record. Settlement / transfer
// finalise paths use this to reuse the same ledger txn_id as the
// initial accept and to flip both paired rows' status atomically.
type TransactionAnchor struct {
	ID      string
	GroupID string
}

// GetTransactionAnchorForPayment returns the DEBIT-side row's id +
// group_id for a payment_tokens row. Returns ErrNoRows when the
// payment has no transactions row yet.
func (r *Repo) GetTransactionAnchorForPayment(ctx context.Context, paymentTokenID string) (TransactionAnchor, error) {
	row, err := r.q.GetTransactionAnchorForPayment(ctx, &paymentTokenID)
	if err != nil {
		return TransactionAnchor{}, err
	}
	return TransactionAnchor{ID: row.ID, GroupID: row.GroupID}, nil
}

// GetTransactionAnchorForTransfer is the transfer analogue.
func (r *Repo) GetTransactionAnchorForTransfer(ctx context.Context, transferID string) (TransactionAnchor, error) {
	row, err := r.q.GetTransactionAnchorForTransfer(ctx, &transferID)
	if err != nil {
		return TransactionAnchor{}, err
	}
	return TransactionAnchor{ID: row.ID, GroupID: row.GroupID}, nil
}

// FinalizePairedTransactions flips every transactions row sharing
// groupID to the given status, optionally stamping settled_amount_kobo
// and failure_reason. Used by settlement / transfer finalise to
// advance both sides of a paired event in lockstep.
func (r *Repo) FinalizePairedTransactions(ctx context.Context, groupID string, status domain.TransactionLifecycleStatus, settled *int64, failureReason *string) error {
	rows, err := r.q.ListTransactionsByGroup(ctx, groupID)
	if err != nil {
		return err
	}
	for _, row := range rows {
		if err := r.q.UpdateTransactionStatus(ctx, sqlcgen.UpdateTransactionStatusParams{
			ID:                row.ID,
			Status:            sqlcgen.TransactionLifecycleStatus(status),
			SettledAmountKobo: settled,
			FailureReason:     failureReason,
		}); err != nil {
			return err
		}
	}
	return nil
}

// ListTransactionsForUser is the user-facing history feed.
func (r *Repo) ListTransactionsForUser(ctx context.Context, userID string, limit, offset int32) ([]domain.UserTransaction, error) {
	rows, err := r.q.ListTransactionsForUser(ctx, sqlcgen.ListTransactionsForUserParams{
		UserID: userID, Limit: limit, Offset: offset,
	})
	if err != nil {
		return nil, err
	}
	out := make([]domain.UserTransaction, len(rows))
	for i, row := range rows {
		out[i] = txnRowToDomain(row)
	}
	return out, nil
}

func txnRowToDomain(row sqlcgen.Transaction) domain.UserTransaction {
	memo := ""
	if row.Memo != nil {
		memo = *row.Memo
	}
	return domain.UserTransaction{
		ID:                 row.ID,
		GroupID:            row.GroupID,
		UserID:             row.UserID,
		CounterpartyUserID: row.CounterpartyUserID,
		Kind:               domain.TransactionKind(row.Kind),
		Status:             domain.TransactionLifecycleStatus(row.Status),
		Direction:          string(row.Direction),
		AmountKobo:         row.AmountKobo,
		SettledAmountKobo:  row.SettledAmountKobo,
		Memo:               memo,
		PaymentTokenID:     row.PaymentTokenID,
		TransferID:         row.TransferID,
		CeilingID:          row.CeilingID,
		FailureReason:      row.FailureReason,
		CreatedAt:          fromTSZ(row.CreatedAt),
		UpdatedAt:          fromTSZ(row.UpdatedAt),
	}
}
