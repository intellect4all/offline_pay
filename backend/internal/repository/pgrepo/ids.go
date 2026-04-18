// Package pgrepo wraps the sqlc-generated code in domain-typed methods.
//
// Identifier strategy: all table primary keys are stored as TEXT containing
// a lowercase canonical ULID (26 chars, Crockford base32, lexicographically
// sortable, time-seeded). ULIDs are preferred over UUIDs because they sort
// by creation time, which aligns well with ledger-append workloads.
package pgrepo

import (
	"crypto/rand"
	"time"

	"github.com/oklog/ulid/v2"
)

// NewID returns a fresh ULID as a string.
func NewID() string {
	return ulid.MustNew(ulid.Timestamp(time.Now()), rand.Reader).String()
}
