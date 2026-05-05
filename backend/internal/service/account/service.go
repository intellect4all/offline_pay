// Package account exposes lightweight lookups for customer-facing
// account-number resolution (e.g. the "confirm receiver" step of a
// transfer). This is NOT the ledger — mutations live in the transfer
// processor + wallet services.
package account

import (
	"context"
	"errors"
	"strings"

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
// transfer. MaskedName carries the full registered display name — the
// "masked" wire field is a historical artefact kept to avoid churning
// the OpenAPI schema and generated clients.
type ResolvedAccount struct {
	AccountNumber string `json:"account_number"`
	MaskedName    string `json:"masked_name"`
}

// ResolveAccount returns the registered owner's display name and the
// canonical account number for the supplied 10-digit input.
func (s *Service) ResolveAccount(ctx context.Context, accountNumber string) (ResolvedAccount, error) {
	if err := domain.ValidateAccountNumber(accountNumber); err != nil {
		return ResolvedAccount{}, err
	}
	owner, err := s.Repo.GetAccountOwner(ctx, accountNumber)
	if err != nil {
		if errors.Is(err, accountrepo.ErrNotFound) {
			return ResolvedAccount{}, ErrNotFound
		}
		return ResolvedAccount{}, err
	}
	return ResolvedAccount{
		AccountNumber: owner.AccountNumber,
		MaskedName:    strings.TrimSpace(owner.FirstName + " " + owner.LastName),
	}, nil
}
