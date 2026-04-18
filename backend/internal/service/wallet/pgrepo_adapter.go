package wallet

import (
	"context"

	"github.com/intellect/offlinepay/internal/repository/pgrepo"
)

// PgRepoAdapter adapts *pgrepo.Repo to wallet.Repository. Only Tx needs
// adapting (its fn signature differs); the rest is promoted via embedding.
type PgRepoAdapter struct {
	*pgrepo.Repo
}

func NewPgRepoAdapter(r *pgrepo.Repo) *PgRepoAdapter { return &PgRepoAdapter{Repo: r} }

func (a *PgRepoAdapter) Tx(ctx context.Context, fn func(Repository) error) error {
	return a.Repo.Tx(ctx, func(r *pgrepo.Repo) error {
		return fn(&PgRepoAdapter{Repo: r})
	})
}
