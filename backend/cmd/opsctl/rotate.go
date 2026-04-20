package main

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"flag"
	"fmt"
	"log/slog"
	"time"

	"github.com/intellect/offlinepay/internal/config"
	"github.com/intellect/offlinepay/internal/crypto"
	"github.com/intellect/offlinepay/internal/repository/opsrepo"
)

// cmdRotateRealmKey mirrors the standalone rotate_realm_key command:
// new key gets max(version)+1, prior active rows get retired_at = now+overlap,
// expired rows are pruned.
func cmdRotateRealmKey(ctx context.Context, cfg config.Config, args []string) error {
	fs := flag.NewFlagSet("rotate-realm-key", flag.ExitOnError)
	overlap := fs.Int("overlap-days", 30, "days the previous key remains decrypt-only")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if *overlap < 0 {
		return fmt.Errorf("--overlap-days must be >= 0")
	}

	pool, err := openPool(ctx, cfg)
	if err != nil {
		return err
	}
	defer pool.Close()

	keyBytes := make([]byte, 32)
	if _, err := rand.Read(keyBytes); err != nil {
		return fmt.Errorf("rand: %w", err)
	}

	overlapDur := time.Duration(*overlap) * 24 * time.Hour
	newVersion, err := opsrepo.New(pool).RotateRealmKey(ctx, keyBytes, overlapDur)
	if err != nil {
		return err
	}
	slog.Info("realm key rotated", "version", newVersion, "overlap_days", *overlap)
	return nil
}

// cmdRotateBankKey mints a fresh Ed25519 keypair, inserts it into
// bank_signing_keys, and (optionally) retires the previous active key.
// The encrypted-private-key column is populated with the raw private key
// for local-signer parity; production deployments swap in KMS via wallet.Signer.
func cmdRotateBankKey(ctx context.Context, cfg config.Config, args []string) error {
	fs := flag.NewFlagSet("rotate-bank-key", flag.ExitOnError)
	keyID := fs.String("key-id", "", "key id for the new bank key (required)")
	retirePrev := fs.Bool("retire-previous", true, "mark currently-active keys as retired")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if *keyID == "" {
		return fmt.Errorf("--key-id required")
	}

	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return fmt.Errorf("generate ed25519: %w", err)
	}

	pool, err := openPool(ctx, cfg)
	if err != nil {
		return err
	}
	defer pool.Close()

	if err := opsrepo.New(pool).RotateBankKey(ctx, *keyID, pub, priv, *retirePrev); err != nil {
		return err
	}
	slog.Info("bank key rotated", "key_id", *keyID, "pubkey_hex", hex.EncodeToString(pub), "retired_previous", *retirePrev)
	return nil
}

// cmdRotateSealedBoxKey generates a fresh X25519 keypair and prints the env
// vars an operator must update (SERVER_SEALED_BOX_PRIVKEY plus an addition to
// SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS for the overlap window).
func cmdRotateSealedBoxKey(ctx context.Context, cfg config.Config, args []string) error {
	_ = ctx
	_ = cfg
	_ = args
	pub, priv, err := crypto.GenerateSealedBoxKeyPair()
	if err != nil {
		return fmt.Errorf("generate keypair: %w", err)
	}
	fmt.Printf("# New sealed-box keypair generated. Update env and restart server.\n")
	fmt.Printf("SERVER_SEALED_BOX_PRIVKEY=%s\n", hex.EncodeToString(priv[:]))
	fmt.Printf("# Public key (for clients): %s\n", hex.EncodeToString(pub[:]))
	fmt.Printf("# Append the previous SERVER_SEALED_BOX_PRIVKEY to SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS\n")
	fmt.Printf("# (comma-separated) for the overlap window.\n")
	return nil
}

// cmdGenDeviceSessionKey mints a fresh Ed25519 keypair for the BFF's
// device-session-token signer and prints the env block an operator should
// paste into their secrets manager. No DB writes — this signer is
// configured purely via env (BFF_DEVICE_SESSION_PRIVKEY / _KEY_ID /
// _TTL_HOURS); see docs/OFFLINE_AUTH.md for the rotation playbook.
//
// `--key-id` and `--ttl-hours` are advisory — they're echoed into the
// printed env block for convenience. Defaults match cmd/bff: a dated
// `kid` so multiple keys can coexist during rotation, and a 14-day TTL.
func cmdGenDeviceSessionKey(ctx context.Context, cfg config.Config, args []string) error {
	_ = ctx
	_ = cfg
	fs := flag.NewFlagSet("gen-device-session-key", flag.ExitOnError)
	keyID := fs.String("key-id", "", "advisory key id for the new signer (default: device-session-YYYYMMDD)")
	ttlHours := fs.Int("ttl-hours", 14*24, "advisory device-session TTL in hours")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if *ttlHours <= 0 {
		return fmt.Errorf("--ttl-hours must be > 0")
	}

	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return fmt.Errorf("generate ed25519: %w", err)
	}

	kid := *keyID
	if kid == "" {
		kid = "device-session-" + time.Now().UTC().Format("20060102")
	}

	fmt.Printf("# New device-session Ed25519 keypair. Paste into secrets manager + restart BFF.\n")
	fmt.Printf("# Key id    : %s\n", kid)
	fmt.Printf("# Public key: %s\n", hex.EncodeToString(pub))
	fmt.Printf("BFF_DEVICE_SESSION_PRIVKEY=%s\n", hex.EncodeToString(priv))
	fmt.Printf("BFF_DEVICE_SESSION_KEY_ID=%s\n", kid)
	fmt.Printf("BFF_DEVICE_SESSION_TTL_HOURS=%d\n", *ttlHours)
	fmt.Printf("# Rotation: run this again with a new --key-id, ship alongside the old key\n")
	fmt.Printf("# for one TTL window (devices mint new tokens on their next online refresh),\n")
	fmt.Printf("# then retire the old key. See docs/OFFLINE_AUTH.md.\n")
	return nil
}
