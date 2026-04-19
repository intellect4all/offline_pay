package reconciliation

import (
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
)

// PgRepoAdapter wraps *pgrepo.Repo to satisfy reconciliation.Repository.
// No Tx — reconciliation is read-heavy with a single trailing INSERT.
type PgRepoAdapter struct {
	*pgrepo.Repo
}

func NewPgRepoAdapter(r *pgrepo.Repo) *PgRepoAdapter { return &PgRepoAdapter{Repo: r} }
