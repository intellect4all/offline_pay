package settlement

import (
	"context"

	"github.com/intellect/offlinepay/internal/repository/pgrepo"
)

// PgRepoAdapter adapts *pgrepo.Repo to settlement.Repository. See
// wallet.PgRepoAdapter — same pattern, different Repository interface.
type PgRepoAdapter struct {
	*pgrepo.Repo
}

func NewPgRepoAdapter(r *pgrepo.Repo) *PgRepoAdapter { return &PgRepoAdapter{Repo: r} }

func (a *PgRepoAdapter) Tx(ctx context.Context, fn func(Repository) error) error {
	return a.Repo.Tx(ctx, func(r *pgrepo.Repo) error {
		return fn(&PgRepoAdapter{Repo: r})
	})
}
