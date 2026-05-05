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

// AccountOwner is the resolve-account projection: the registered owner's
// name plus the account number, used by the sender's confirm step.
type AccountOwner struct {
	AccountNumber string
	FirstName     string
	LastName      string
}

// GetAccountOwner returns the owner's name for a registered account
// number, ErrNotFound otherwise.
func (r *Repo) GetAccountOwner(ctx context.Context, accountNumber string) (AccountOwner, error) {
	row, err := r.q.GetUserNameByAccountNumber(ctx, accountNumber)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AccountOwner{}, ErrNotFound
		}
		return AccountOwner{}, err
	}
	return AccountOwner{
		AccountNumber: row.AccountNumber,
		FirstName:     row.FirstName,
		LastName:      row.LastName,
	}, nil
}
