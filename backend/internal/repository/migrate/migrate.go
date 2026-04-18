// Package migrate runs the embedded SQL schema migrations against a Postgres
// database. The migration files come from backend/db/migrations and are
// embedded via backend/db.MigrationsFS.
package migrate

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	"github.com/golang-migrate/migrate/v4/source/iofs"
)

// Run applies all pending up migrations from fsys against dbURL. It is safe
// to call repeatedly — `migrate.ErrNoChange` is treated as a no-op. The
// migration source must contain a `migrations/` subdirectory laid out as
// `NNNN_*.up.sql` / `*.down.sql`.
func Run(ctx context.Context, dbURL string, fsys fs.FS) error {
	src, err := iofs.New(fsys, "migrations")
	if err != nil {
		return fmt.Errorf("migrate iofs: %w", err)
	}
	defer src.Close()

	m, err := migrate.NewWithSourceInstance("iofs", src, dbURL)
	if err != nil {
		return fmt.Errorf("migrate new: %w", err)
	}
	defer func() {
		_, _ = m.Close()
	}()

	before, _, _ := m.Version()
	if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("migrate up: %w", err)
	}
	after, _, _ := m.Version()
	if before == after {
		slog.InfoContext(ctx, "migrations: no changes", "version", after)
	} else {
		slog.InfoContext(ctx, "migrations applied", "from", before, "to", after)
	}
	return nil
}
