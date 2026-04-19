package identity

import (
	"context"

	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/repository/userauthrepo"
)

// PgRepoAdapter satisfies [Repository] by combining a bank-key source with
// a user-profile source. The bank key lives in *pgrepo.Repo; the /me
// projection lives in *userauthrepo.Repo. Passing them as function values
// avoids an import-cycle between the two repository packages.
type PgRepoAdapter struct {
	Me                   func(ctx context.Context, userID string) (userauthrepo.Me, error)
	BankKey              func(ctx context.Context) (domain.BankSigningKey, error)
}

var _ Repository = (*PgRepoAdapter)(nil)

// NewPgRepoAdapter constructs the adapter from closures over concrete
// repos. Call from cmd/bff/main.go after both repos are live.
func NewPgRepoAdapter(
	me func(ctx context.Context, userID string) (userauthrepo.Me, error),
	bankKey func(ctx context.Context) (domain.BankSigningKey, error),
) *PgRepoAdapter {
	return &PgRepoAdapter{Me: me, BankKey: bankKey}
}

// GetMe implements [Repository].
func (a *PgRepoAdapter) GetMe(ctx context.Context, userID string) (MeRow, error) {
	me, err := a.Me(ctx, userID)
	if err != nil {
		return MeRow{}, err
	}
	return MeRow{
		UserID:        me.ID,
		FirstName:     me.FirstName,
		LastName:      me.LastName,
		AccountNumber: me.AccountNumber,
	}, nil
}

// GetActiveBankSigningKey implements [Repository].
func (a *PgRepoAdapter) GetActiveBankSigningKey(ctx context.Context) (domain.BankSigningKey, error) {
	return a.BankKey(ctx)
}
