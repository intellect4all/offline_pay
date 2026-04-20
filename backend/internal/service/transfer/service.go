// Package transfer implements the user-to-user money-movement domain.
//
// InitiateTransfer accepts a transfer request, writes the transfer row +
// an outbox entry in a single pgx tx (so loss is impossible), and returns
// status=ACCEPTED synchronously. The Dispatcher and Processor types in
// this package complete the async half.
package transfer

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/oklog/ulid/v2"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
	"github.com/intellect/offlinepay/internal/repository/transferrepo"
	"github.com/intellect/offlinepay/internal/service/fraud"
)

var (
	ErrReceiverNotFound = errors.New("transfer: receiver account not found")
	ErrSelfTransfer     = errors.New("transfer: cannot transfer to self")
	// ErrFraudBlocked is returned when the fraud scorer returns a BLOCK
	// decision (e.g., velocity spike). The transfer is NOT persisted; the
	// BFF translates this to 403 fraud_block.
	ErrFraudBlocked = errors.New("transfer: blocked by fraud scoring")
)

// Service is the accept-side of the transfer domain.
type Service struct {
	Pool  *pgxpool.Pool
	Repo  *transferrepo.Repo
	Fraud *fraud.TransferService
}

// New Fraud scoring is optional — pass nil to skip
// rule evaluation (tests that don't exercise the fraud path can supply nil
// instead of wiring a full fraud.TransferService). Cache may also be
// nil (tests); cache.Noop is used when that happens.
func New(pool *pgxpool.Pool, c cache.Cache, fraudSvc *fraud.TransferService) *Service {
	return &Service{Pool: pool, Repo: transferrepo.New(pool, c), Fraud: fraudSvc}
}

// InitiateTransferInput is the accept-side request.
type InitiateTransferInput struct {
	SenderUserID          string
	ReceiverAccountNumber string
	AmountKobo            int64
	Reference             string
}

func newID() string {
	return strings.ToLower(ulid.MustNew(ulid.Timestamp(time.Now()), rand.Reader).String())
}

// InitiateTransfer is idempotent on (sender_user_id, reference). Repeated
// calls with the same reference return the previously accepted transfer
// as-is (whatever its current status).
func (s *Service) InitiateTransfer(ctx context.Context, in InitiateTransferInput) (*domain.Transfer, error) {
	if in.SenderUserID == "" {
		return nil, errors.New("transfer: sender_user_id required")
	}
	if err := domain.ValidateAccountNumber(in.ReceiverAccountNumber); err != nil {
		return nil, err
	}
	if err := domain.ValidateAmount(in.AmountKobo); err != nil {
		return nil, err
	}
	if err := domain.ValidateReference(in.Reference); err != nil {
		return nil, err
	}

	// Pre-tx cached resolves. Receiver account_number is immutable; tier
	// only moves upward via kycrepo.Submit which invalidates the cache
	// on commit. Lifting these two reads out of the accept tx keeps the
	// tx narrow and lets every transfer hit Redis on the hot path.
	receiverID, err := s.Repo.ResolveReceiverUserID(ctx, in.ReceiverAccountNumber)
	if err != nil {
		if errors.Is(err, transferrepo.ErrNotFound) {
			return nil, ErrReceiverNotFound
		}
		return nil, err
	}
	if receiverID == in.SenderUserID {
		return nil, ErrSelfTransfer
	}
	tier, err := s.Repo.GetSenderKYCTier(ctx, in.SenderUserID)
	if err != nil {
		return nil, fmt.Errorf("lookup sender tier: %w", err)
	}

	var out *domain.Transfer
	err = s.Repo.AcceptTx(ctx, func(q transferrepo.AcceptQueries) error {
		// Idempotency check first — if we've already accepted this
		// (sender, reference) pair, return what we have.
		existing, err := q.GetByRef(ctx, in.SenderUserID, in.Reference)
		if err == nil {
			out = existing.ToDomain()
			return nil
		}
		if !errors.Is(err, transferrepo.ErrNotFound) {
			return err
		}
		limits := LimitsForTier(tier)
		if limits.SingleMaxKobo == 0 {
			return ErrTierBlocked
		}
		if in.AmountKobo > limits.SingleMaxKobo {
			return fmt.Errorf("%w: amount=%d limit=%d",
				ErrExceedsSingleLimit, in.AmountKobo, limits.SingleMaxKobo)
		}
		spentToday, err := q.SumTodaySenderTransfers(ctx, in.SenderUserID)
		if err != nil {
			return fmt.Errorf("lookup daily spend: %w", err)
		}
		if spentToday+in.AmountKobo > limits.DailyMaxKobo {
			return fmt.Errorf("%w: attempted=%d already_today=%d daily_limit=%d",
				ErrExceedsDailyLimit, in.AmountKobo, spentToday, limits.DailyMaxKobo)
		}

		// Fraud scoring — runs inside the same tx so velocity counts see
		// the exact same set of prior transfers the tier check did. The
		// scorer is optional (nil in older call-sites and tests); skip
		// when absent.
		var fraudScore fraud.Score
		if s.Fraud != nil {
			// Pull the sender's account age in-tx so the rule sees a
			// consistent view with the limit check above.
			ageHours, err := q.GetUserAccountAgeHours(ctx, in.SenderUserID)
			if err != nil {
				return fmt.Errorf("lookup sender age: %w", err)
			}
			scoreIn := fraud.ScoreInput{
				SenderUserID:          in.SenderUserID,
				ReceiverUserID:        receiverID,
				AmountKobo:            in.AmountKobo,
				SenderTier:            tier,
				DailyTierLimitKobo:    limits.DailyMaxKobo,
				SenderAccountAgeHours: int64(ageHours),
			}
			sc, err := s.Fraud.ScoreTransfer(ctx, q.Tx, scoreIn)
			if err != nil {
				return fmt.Errorf("fraud score: %w", err)
			}
			fraudScore = sc
			if sc.Decision == fraud.DecisionBlock {
				// Write the BLOCK row outside the tx (tx will rollback)
				// so the audit survives. Best-effort: a failure here is
				// logged and the block still propagates.
				if recErr := s.Fraud.RecordScore(ctx, q.Tx, "", scoreIn, sc); recErr != nil {
					slog.WarnContext(ctx, "transfer: fraud score record (block) failed",
						"err", recErr, "sender", in.SenderUserID, "rule", sc.Rule)
				}
				return fmt.Errorf("%w: rule=%s reason=%s",
					ErrFraudBlocked, sc.Rule, sc.Reason)
			}
		}

		flagged := fraudScore.Decision == fraud.DecisionFlag
		row, err := q.InsertAccepted(ctx, transferrepo.InsertAcceptedParams{
			ID:                    newID(),
			SenderUserID:          in.SenderUserID,
			ReceiverUserID:        receiverID,
			ReceiverAccountNumber: in.ReceiverAccountNumber,
			AmountKobo:            in.AmountKobo,
			Reference:             in.Reference,
			Flagged:               flagged,
		})
		if err != nil {
			return fmt.Errorf("insert transfer: %w", err)
		}

		// Paired business-event rows. Both share group_id; sender's row
		// is DEBIT (money about to leave), receiver's is CREDIT.
		groupID := newID()
		transferRef := row.ID
		recvCounter := receiverID
		sendCounter := in.SenderUserID
		if err := q.RecordTransaction(ctx, sqlcgen.RecordTransactionParams{
			ID:                 newID(),
			GroupID:            groupID,
			UserID:             in.SenderUserID,
			CounterpartyUserID: &recvCounter,
			Kind:               sqlcgen.TransactionKindTRANSFERSENT,
			Status:             sqlcgen.TransactionLifecycleStatusPENDING,
			Direction:          sqlcgen.LedgerDirectionDEBIT,
			AmountKobo:         in.AmountKobo,
			TransferID:         &transferRef,
		}); err != nil {
			return fmt.Errorf("record sender transaction: %w", err)
		}
		if err := q.RecordTransaction(ctx, sqlcgen.RecordTransactionParams{
			ID:                 newID(),
			GroupID:            groupID,
			UserID:             receiverID,
			CounterpartyUserID: &sendCounter,
			Kind:               sqlcgen.TransactionKindTRANSFERRECEIVED,
			Status:             sqlcgen.TransactionLifecycleStatusPENDING,
			Direction:          sqlcgen.LedgerDirectionCREDIT,
			AmountKobo:         in.AmountKobo,
			TransferID:         &transferRef,
		}); err != nil {
			return fmt.Errorf("record receiver transaction: %w", err)
		}
		if flagged && s.Fraud != nil {
			scoreIn := fraud.ScoreInput{
				SenderUserID:          in.SenderUserID,
				ReceiverUserID:        receiverID,
				AmountKobo:            in.AmountKobo,
				SenderTier:            tier,
				DailyTierLimitKobo:    limits.DailyMaxKobo,
				SenderAccountAgeHours: 0,
			}
			if err := s.Fraud.RecordScore(ctx, q.Tx, row.ID, scoreIn, fraudScore); err != nil {
				return fmt.Errorf("fraud score record: %w", err)
			}
		}

		payload := domain.TransferPayload{
			TransferID:            row.ID,
			SenderUserID:          row.SenderUserID,
			ReceiverUserID:        row.ReceiverUserID,
			ReceiverAccountNumber: row.ReceiverAccountNumber,
			AmountKobo:            row.AmountKobo,
			Reference:             row.Reference,
		}
		body, err := json.Marshal(payload)
		if err != nil {
			return fmt.Errorf("marshal payload: %w", err)
		}
		if err := q.InsertOutbox(ctx, newID(), row.ID, body); err != nil {
			return fmt.Errorf("insert outbox: %w", err)
		}
		out = row.ToDomain()
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

// GetTransfer returns a single transfer by id, populating the sender /
// receiver display names so activity UIs don't fall back to raw ulids.
// Display-name resolution is best-effort: a lookup failure is logged
// and swallowed so a transient users-table outage doesn't cascade into
// a transfer read error.
func (s *Service) GetTransfer(ctx context.Context, id string) (*domain.Transfer, error) {
	t, err := s.Repo.GetTransfer(ctx, id)
	if err != nil {
		if errors.Is(err, transferrepo.ErrNotFound) {
			return nil, nil
		}
		return nil, err
	}
	if t == nil {
		return nil, nil
	}
	s.enrichDisplayNames(ctx, []*domain.Transfer{t})
	return t, nil
}

// ListTransfers returns recent transfers where the user is sender OR receiver.
func (s *Service) ListTransfers(ctx context.Context, userID string, limit, offset int) ([]domain.Transfer, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}
	rows, err := s.Repo.ListTransfersForUser(ctx, userID, int32(limit), int32(offset))
	if err != nil {
		return nil, err
	}
	ptrs := make([]*domain.Transfer, len(rows))
	for i := range rows {
		ptrs[i] = &rows[i]
	}
	s.enrichDisplayNames(ctx, ptrs)
	return rows, nil
}

// enrichDisplayNames is a best-effort batch lookup of
// SenderDisplayName / ReceiverDisplayName for a slice of transfers.
// Errors are swallowed (logged) so the caller's happy path still
// renders — the UI already falls back to the raw id when the name is
// nil.
func (s *Service) enrichDisplayNames(ctx context.Context, transfers []*domain.Transfer) {
	if len(transfers) == 0 {
		return
	}
	seen := make(map[string]struct{}, len(transfers)*2)
	ids := make([]string, 0, len(transfers)*2)
	for _, t := range transfers {
		if t == nil {
			continue
		}
		if _, ok := seen[t.SenderUserID]; !ok && t.SenderUserID != "" {
			seen[t.SenderUserID] = struct{}{}
			ids = append(ids, t.SenderUserID)
		}
		if _, ok := seen[t.ReceiverUserID]; !ok && t.ReceiverUserID != "" {
			seen[t.ReceiverUserID] = struct{}{}
			ids = append(ids, t.ReceiverUserID)
		}
	}
	if len(ids) == 0 {
		return
	}
	names, err := s.Repo.LookupDisplayNames(ctx, ids)
	if err != nil {
		slog.WarnContext(ctx, "transfer.list: display-name lookup failed", "err", err)
		return
	}
	for _, t := range transfers {
		if t == nil {
			continue
		}
		if n, ok := names[t.SenderUserID]; ok {
			nameCopy := n
			t.SenderDisplayName = &nameCopy
		}
		if n, ok := names[t.ReceiverUserID]; ok {
			nameCopy := n
			t.ReceiverDisplayName = &nameCopy
		}
	}
}
