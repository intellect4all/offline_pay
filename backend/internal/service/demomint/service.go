// Package demomint is the server-side implementation of the demo
// "mint money" funding flow surfaced at /demo/fund on the BFF.
//
// The flow is not a real bank integration: every mint simply transfers
// kobo from a pre-seeded treasury (system-mint-treasury, funded to 5B
// via migration 0022) into the recipient's main wallet, producing a
// balanced double-entry ledger post so the ledger invariant continues
// to hold. It exists only to unblock downstream demos (offline wallet
// funding, transfers, settlement) until a real deposit integration
// ships.
package demomint

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/logging"
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

const (
	// TreasuryAccountID is the system-mint treasury that all demo mints
	// debit. Seeded with 5B NGN by migration 0022.
	TreasuryAccountID = "system-mint-treasury"

	// SupportedBankCode is the only bank accepted by the demo flow.
	SupportedBankCode = "TEST"

	// MinAmountKobo / MaxAmountKobo bound a single mint: ₦1 – ₦500,000.
	MinAmountKobo int64 = 100
	MaxAmountKobo int64 = 50_000_000
)

var (
	ErrAccountNotFound    = errors.New("demomint: account not found")
	ErrAmountOutOfRange   = errors.New("demomint: amount out of range")
	ErrUnsupportedBank    = errors.New("demomint: unsupported bank code")
	ErrTreasuryExhausted  = errors.New("demomint: treasury exhausted")
	ErrMissingAccountNum  = errors.New("demomint: missing account_number")
)

// Service wraps the demo-mint state transitions over pgrepo.
type Service struct {
	repo   *pgrepo.Repo
	logger *slog.Logger
}

func New(repo *pgrepo.Repo, logger *slog.Logger) *Service {
	return &Service{repo: repo, logger: logging.Or(logger)}
}

// NameEnquiryResult is returned by the name-lookup step.
type NameEnquiryResult struct {
	AccountNumber string
	FullName      string
}

// NameEnquiry looks up the account holder for the given account number
// + bank code combination. Returns ErrAccountNotFound if no user owns
// the account number (system accounts are filtered at the query level).
func (s *Service) NameEnquiry(ctx context.Context, accountNumber, bankCode string) (NameEnquiryResult, error) {
	if accountNumber == "" {
		return NameEnquiryResult{}, ErrMissingAccountNum
	}
	if bankCode != SupportedBankCode {
		return NameEnquiryResult{}, ErrUnsupportedBank
	}
	_, first, last, err := s.repo.GetUserNameByAccountNumber(ctx, accountNumber)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return NameEnquiryResult{}, ErrAccountNotFound
		}
		return NameEnquiryResult{}, fmt.Errorf("name enquiry: %w", err)
	}
	return NameEnquiryResult{AccountNumber: accountNumber, FullName: first + " " + last}, nil
}

// FundResult is returned by a successful mint.
type FundResult struct {
	TxnID          string
	NewBalanceKobo int64
}

// Fund transfers amountKobo from the treasury to the recipient's main
// wallet atomically. Produces a balanced ledger post (treasury DEBIT,
// recipient.main CREDIT) and a single DEMO_MINT transactions row from
// the recipient's POV.
func (s *Service) Fund(ctx context.Context, accountNumber, bankCode string, amountKobo int64) (FundResult, error) {
	if accountNumber == "" {
		return FundResult{}, ErrMissingAccountNum
	}
	if bankCode != SupportedBankCode {
		return FundResult{}, ErrUnsupportedBank
	}
	if amountKobo < MinAmountKobo || amountKobo > MaxAmountKobo {
		return FundResult{}, ErrAmountOutOfRange
	}

	var result FundResult
	err := s.repo.Tx(ctx, func(tx *pgrepo.Repo) error {
		userID, _, _, err := tx.GetUserNameByAccountNumber(ctx, accountNumber)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrAccountNotFound
			}
			return fmt.Errorf("lookup recipient: %w", err)
		}
		mainAccountID, err := tx.GetAccountID(ctx, userID, sqlcgen.AccountKindMain)
		if err != nil {
			return fmt.Errorf("resolve main account: %w", err)
		}

		txnID := pgrepo.NewID()

		if err := tx.DebitAccount(ctx, TreasuryAccountID, amountKobo); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrTreasuryExhausted
			}
			return fmt.Errorf("debit treasury: %w", err)
		}
		if err := tx.CreditAccount(ctx, mainAccountID, amountKobo); err != nil {
			return fmt.Errorf("credit recipient: %w", err)
		}

		// transactions row must exist before ledger_entries reference it
		// (fk_ledger_txn is immediate, not deferred).
		if err := tx.RecordTransaction(ctx, pgrepo.RecordTransactionParams{
			ID:         txnID,
			GroupID:    txnID,
			UserID:     userID,
			Kind:       domain.TxKindDemoMint,
			Status:     domain.TxStatusCompleted,
			Direction:  "CREDIT",
			AmountKobo: amountKobo,
			Memo:       "Demo mint from Test Bank",
		}); err != nil {
			return fmt.Errorf("record transaction: %w", err)
		}

		if err := tx.PostLedger(ctx, txnID, []pgrepo.LedgerLeg{
			{AccountID: TreasuryAccountID, Direction: "DEBIT", Amount: amountKobo, Memo: "demo mint"},
			{AccountID: mainAccountID, Direction: "CREDIT", Amount: amountKobo, Memo: "demo mint"},
		}); err != nil {
			return fmt.Errorf("post ledger: %w", err)
		}

		newBalance, err := tx.GetAccountBalance(ctx, userID, sqlcgen.AccountKindMain)
		if err != nil {
			return fmt.Errorf("read balance: %w", err)
		}
		result = FundResult{TxnID: txnID, NewBalanceKobo: newBalance}
		return nil
	})
	if err != nil {
		return FundResult{}, err
	}
	s.logger.Info("demo.mint.funded",
		"recipient_account", accountNumber,
		"amount_kobo", amountKobo,
		"txn_id", result.TxnID,
	)
	return result, nil
}
