package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"

	"github.com/oklog/ulid/v2"

	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/config"
	"github.com/intellect/offlinepay/internal/repository/opsrepo"
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/service/reconciliation"
	"github.com/intellect/offlinepay/internal/service/wallet"
)

// cmdForceExpireCeiling flips a ceiling_tokens row to status='EXPIRED'. The
// next wallet.ReleaseOnExpiry sweep (or `release-lien`) will then refund
// the lien back to the main wallet.
func cmdForceExpireCeiling(ctx context.Context, cfg config.Config, args []string) error {
	fs := flag.NewFlagSet("force-expire-ceiling", flag.ExitOnError)
	id := fs.String("id", "", "ceiling token id (required)")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if *id == "" {
		return fmt.Errorf("--id required")
	}
	pool, err := openPool(ctx, cfg)
	if err != nil {
		return err
	}
	defer pool.Close()

	ok, err := opsrepo.New(pool).ForceExpireActiveCeiling(ctx, *id)
	if err != nil {
		return fmt.Errorf("update: %w", err)
	}
	if !ok {
		return fmt.Errorf("no ACTIVE ceiling with id %q", *id)
	}
	slog.Info("ceiling forced expired", "ceiling_id", *id)
	return nil
}

// cmdReleaseLien runs the wallet ReleaseOnExpiry sweep once. Combine with
// force-expire-ceiling to release a specific lien out-of-band.
func cmdReleaseLien(ctx context.Context, cfg config.Config, args []string) error {
	_ = args
	pool, err := openPool(ctx, cfg)
	if err != nil {
		return err
	}
	defer pool.Close()
	repo := pgrepo.New(pool, cache.Noop{})
	walletSvc := wallet.New(wallet.NewPgRepoAdapter(repo))
	n, err := walletSvc.ReleaseOnExpiry(ctx)
	if err != nil {
		return fmt.Errorf("release on expiry: %w", err)
	}
	slog.Info("liens released", "count", n)
	return nil
}

// cmdFreezeUser inserts a CRITICAL SIGNATURE_INVALID fraud signal with a
// large weight, which pushes the user's accumulated fraud score above the
// SUSPENDED threshold so the next ClampCeiling call refuses funding.
func cmdFreezeUser(ctx context.Context, cfg config.Config, args []string) error {
	fs := flag.NewFlagSet("freeze-user", flag.ExitOnError)
	user := fs.String("user", "", "user id to freeze (required)")
	reason := fs.String("reason", "manual ops freeze", "details written to the fraud signal row")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if *user == "" {
		return fmt.Errorf("--user required")
	}
	pool, err := openPool(ctx, cfg)
	if err != nil {
		return err
	}
	defer pool.Close()

	id := ulid.Make().String()
	if err := opsrepo.New(pool).FreezeUser(ctx, id, *user, *reason); err != nil {
		return fmt.Errorf("insert fraud signal: %w", err)
	}
	slog.Info("user frozen", "user_id", *user, "fraud_signal_id", id)
	return nil
}

// cmdReconNow invokes reconciliation.NightlyLedgerReconcile once and prints
// the resulting status + discrepancy count.
func cmdReconNow(ctx context.Context, cfg config.Config, args []string) error {
	_ = args
	pool, err := openPool(ctx, cfg)
	if err != nil {
		return err
	}
	defer pool.Close()
	repo := pgrepo.New(pool, cache.Noop{})
	rec := reconciliation.New(reconciliation.NewPgRepoAdapter(repo))
	res, err := rec.NightlyLedgerReconcile(ctx)
	if err != nil {
		return fmt.Errorf("reconcile: %w", err)
	}
	slog.Info("reconciliation complete",
		"run_id", res.ID,
		"status", string(res.Status),
		"discrepancies", len(res.Discrepancies),
	)
	return nil
}
