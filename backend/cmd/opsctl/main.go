// opsctl is the operations CLI for the offlinepay backend. Each subcommand
// performs one well-defined ritual: a key rotation, a force-state-change, or
// an on-demand reconciliation.
//
// Usage:
//
//	opsctl <subcommand> [flags]
//
// Subcommands:
//
//	rotate-realm-key       Mint a new realm key version with overlap.
//	rotate-bank-key        Generate a new Ed25519 bank signing key.
//	rotate-sealedbox-key   Generate a new X25519 sealed-box keypair (prints env).
//	gen-device-session-key Generate the BFF device-session Ed25519 signer (prints env).
//	force-expire-ceiling   Mark a ceiling EXPIRED so the next sweep releases its lien.
//	release-lien           Run wallet.ReleaseOnExpiry once.
//	freeze-user            Insert a critical fraud signal forcing tier=SUSPENDED.
//	recon-now              Run reconciliation.NightlyLedgerReconcile once.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"sort"

	"github.com/intellect/offlinepay/internal/config"
	"github.com/intellect/offlinepay/internal/logging"
)

type subcommand struct {
	name string
	help string
	run  func(ctx context.Context, cfg config.Config, args []string) error
}

func main() {
	cmds := map[string]subcommand{
		"rotate-realm-key":     {name: "rotate-realm-key", help: "mint a new realm key", run: cmdRotateRealmKey},
		"rotate-bank-key":      {name: "rotate-bank-key", help: "mint a new bank signing key", run: cmdRotateBankKey},
		"rotate-sealedbox-key":   {name: "rotate-sealedbox-key", help: "generate a new sealed-box keypair", run: cmdRotateSealedBoxKey},
		"gen-device-session-key": {name: "gen-device-session-key", help: "generate the BFF device-session Ed25519 signer (prints env)", run: cmdGenDeviceSessionKey},
		"force-expire-ceiling": {name: "force-expire-ceiling", help: "mark a ceiling EXPIRED", run: cmdForceExpireCeiling},
		"release-lien":         {name: "release-lien", help: "run wallet.ReleaseOnExpiry once", run: cmdReleaseLien},
		"freeze-user":          {name: "freeze-user", help: "force a user into tier=SUSPENDED", run: cmdFreezeUser},
		"recon-now":            {name: "recon-now", help: "run NightlyLedgerReconcile once", run: cmdReconNow},
		"admin-create":         {name: "admin-create", help: "create a backoffice admin user", run: cmdAdminCreate},
	}

	if len(os.Args) < 2 || os.Args[1] == "-h" || os.Args[1] == "--help" {
		usage(cmds)
		return
	}
	cmd, ok := cmds[os.Args[1]]
	if !ok {
		fmt.Fprintf(os.Stderr, "unknown subcommand %q\n\n", os.Args[1])
		usage(cmds)
		os.Exit(2)
	}

	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "config: %v\n", err)
		os.Exit(1)
	}
	logging.Setup(cfg.Env, cfg.LogFormat, cfg.LogLevel)

	if err := cmd.run(context.Background(), cfg, os.Args[2:]); err != nil {
		slog.Error("opsctl failed", "subcommand", cmd.name, "err", err)
		os.Exit(1)
	}
}

func usage(cmds map[string]subcommand) {
	fmt.Fprintln(os.Stderr, "opsctl <subcommand> [flags]\n\nSubcommands:")
	names := make([]string, 0, len(cmds))
	for n := range cmds {
		names = append(names, n)
	}
	sort.Strings(names)
	for _, n := range names {
		fmt.Fprintf(os.Stderr, "  %-22s %s\n", n, cmds[n].help)
	}
}
