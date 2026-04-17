// Package domain contains the pure domain models of the offlinepay system.
//
// Types in this package have no dependencies beyond the Go standard library.
// All monetary amounts are int64 kobo — never use floating point for money.
package domain

import "time"

// Wallet represents a user's main (online) wallet.
type Wallet struct {
	// ID is the unique wallet identifier.
	ID string
	// UserID is the owning user's identifier.
	UserID string
	// AvailableBalance is the spendable balance in kobo (excludes held amounts).
	AvailableBalance int64
	// LedgerBalance is the total ledger balance in kobo, including held amounts.
	LedgerBalance int64
	// Currency is the ISO currency code. Always "NGN" for this system.
	Currency string
	// CreatedAt is the wallet creation timestamp.
	CreatedAt time.Time
	// UpdatedAt is the last-modified timestamp.
	UpdatedAt time.Time
}

// OfflineWallet represents a user's offline spending wallet, funded from the
// main wallet. Its balance is backed by a Lien on the main wallet and
// authorized by a CeilingToken.
type OfflineWallet struct {
	// ID is the unique offline wallet identifier.
	ID string
	// UserID is the owning user's identifier.
	UserID string
	// WalletID is the parent main wallet's identifier.
	WalletID string
	// Balance is the current offline spending power in kobo.
	Balance int64
	// InitialBalance is the offline balance at funding time in kobo.
	InitialBalance int64
	// CeilingTokenID is the active ceiling token backing this wallet.
	CeilingTokenID string
	// Status is the current lifecycle status.
	Status OfflineWalletStatus
	// FundedAt is the timestamp when the offline wallet was funded.
	FundedAt time.Time
	// ExpiresAt mirrors the backing ceiling token's expiry.
	ExpiresAt time.Time
	// CreatedAt is the creation timestamp.
	CreatedAt time.Time
	// UpdatedAt is the last-modified timestamp.
	UpdatedAt time.Time
}

// OfflineWalletStatus is the lifecycle status of an OfflineWallet.
type OfflineWalletStatus string

const (
	// OfflineWalletActive means the wallet is usable for offline payments.
	OfflineWalletActive OfflineWalletStatus = "ACTIVE"
	// OfflineWalletExpired means the backing ceiling token has expired.
	OfflineWalletExpired OfflineWalletStatus = "EXPIRED"
	// OfflineWalletDrained means the balance has been fully spent.
	OfflineWalletDrained OfflineWalletStatus = "DRAINED"
	// OfflineWalletRevoked means the wallet was manually closed.
	OfflineWalletRevoked OfflineWalletStatus = "REVOKED"
)

// Lien represents a hard hold placed on the main wallet when funding an
// offline wallet. It guarantees that offline spend can be settled.
type Lien struct {
	// ID is the unique lien identifier.
	ID string
	// WalletID is the main wallet the lien is placed against.
	WalletID string
	// OfflineWalletID is the offline wallet backed by this lien.
	OfflineWalletID string
	// Amount is the held amount in kobo.
	Amount int64
	// Status is the current lien status.
	Status LienStatus
	// CreatedAt is the lien creation timestamp.
	CreatedAt time.Time
	// ReleasedAt is set when the lien has been resolved (settled/released/partial).
	ReleasedAt *time.Time
}

// LienStatus is the lifecycle status of a Lien.
type LienStatus string

const (
	// LienActive means funds are currently held.
	LienActive LienStatus = "ACTIVE"
	// LienSettled means held funds were debited via settlement.
	LienSettled LienStatus = "SETTLED"
	// LienReleased means unused held funds were returned to the main wallet.
	LienReleased LienStatus = "RELEASED"
	// LienPartial means the lien was partially settled; remainder released.
	LienPartial LienStatus = "PARTIAL"
)
