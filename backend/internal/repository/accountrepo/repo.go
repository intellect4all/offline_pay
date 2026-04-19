package accountrepo

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/intellect/offlinepay/internal/repository/sqlcgen"
)

var ErrNotFound = errors.New("accountrepo: not found")

type Repo struct {
	q *sqlcgen.Queries
}

func New(pool *pgxpool.Pool) *Repo {
	return &Repo{q: sqlcgen.New(pool)}
}

// CheckAccountNumberExists returns the account number when a registered
// user owns it, ErrNotFound otherwise.
func (r *Repo) CheckAccountNumberExists(ctx context.Context, accountNumber string) (string, error) {
	s, err := r.q.CheckAccountNumberExists(ctx, accountNumber)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", ErrNotFound
		}
		return "", err
	}
	return s, nil
}
