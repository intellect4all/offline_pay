// Package account exposes lightweight lookups for customer-facing
// account-number resolution (e.g. the "confirm receiver" step of a
// transfer). This is NOT the ledger — mutations live in the transfer
// processor + wallet services.
package account

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/accountrepo"
)

// ErrNotFound is returned when the supplied account number does not map
// to a registered user.
var ErrNotFound = errors.New("account: not found")

type Service struct {
	Repo *accountrepo.Repo
}

func New(pool *pgxpool.Pool) *Service {
	return &Service{Repo: accountrepo.New(pool)}
}

// ResolvedAccount is the minimal envelope a sender needs to confirm a
// transfer. MaskedName is a privacy-preserving placeholder; a production
// implementation would pull the display name from the most recent KYC
// submission.
type ResolvedAccount struct {
	AccountNumber string `json:"account_number"`
	MaskedName    string `json:"masked_name"`
}

// ResolveAccount returns a masked identity snapshot for the given 10-digit
// account number. The users table has no display name yet; we return a
// stable "Account ***{last4}" placeholder. The KYC table carries the real
// name once Phase 2 KYC integration lands — substitute then.
func (s *Service) ResolveAccount(ctx context.Context, accountNumber string) (ResolvedAccount, error) {
	if err := domain.ValidateAccountNumber(accountNumber); err != nil {
		return ResolvedAccount{}, err
	}
	exists, err := s.Repo.CheckAccountNumberExists(ctx, accountNumber)
	if err != nil {
		if errors.Is(err, accountrepo.ErrNotFound) {
			return ResolvedAccount{}, ErrNotFound
		}
		return ResolvedAccount{}, err
	}
	return ResolvedAccount{
		AccountNumber: exists,
		MaskedName:    "Account ***" + exists[6:10],
	}, nil
}
