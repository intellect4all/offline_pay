// Package db exposes the embedded SQL migration files.
//
// The migrations live under db/migrations/ and are also runnable via
// `make migrate`. Embedding them lets the server (or opsctl) apply them
// without a separate binary on the host.
package db

import "embed"

// MigrationsFS holds the up/down SQL migration files.
//
//go:embed migrations/*.sql
var MigrationsFS embed.FS
