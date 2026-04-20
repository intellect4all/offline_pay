// Package main is the entrypoint for the offlinepay BFF.
//
// The BFF is a single HTTP binary exposing the REST JSON API (generated
// from backend/api/openapi.yaml) and running wallet / settlement /
// gossip / reconciliation / registration service logic in-process. The
// prior gRPC settlement server was folded in during the POC cleanup.
//
// Required env (with dev fallbacks):
//
//	DB_URL                      — Postgres connection string
//	BFF_JWT_SECRET              — HMAC secret for access tokens (>= 32 bytes)
//
// Optional env:
//
//	BFF_HTTP_ADDR               — listen addr (default :8082)
//	BFF_JWT_AUDIENCE            — aud claim (default offlinepay-user)
//	BFF_ACCESS_TTL_MINUTES      — access token TTL (default 15)
//	BFF_REFRESH_TTL_HOURS       — refresh token TTL (default 168)
//	BFF_OTP_TTL_MINUTES         — OTP challenge TTL (default 5)
//	BFF_OTP_MAX_ATTEMPTS        — OTP verify attempts cap (default 5)
//	MIGRATE_ON_BOOT             — run embedded migrations on start (default false)
//	CEILING_TTL_HOURS           — default ceiling token TTL (24)
//	AUTO_SETTLE_TIMEOUT_HOURS   — auto-settle sweep cutoff (72)
//	CLOCK_GRACE_MINUTES         — clock-skew grace window (30)
//	SERVER_SEALED_BOX_PRIVKEY   — hex X25519 for gossip (ephemeral when unset)
package main

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/intellect/offlinepay/db"
	"github.com/intellect/offlinepay/internal/cache"
	"github.com/intellect/offlinepay/internal/crypto"
	"github.com/intellect/offlinepay/internal/crypto/kms"
	"github.com/intellect/offlinepay/internal/domain"
	"github.com/intellect/offlinepay/internal/logging"
	"github.com/intellect/offlinepay/internal/observability"
	migraterunner "github.com/intellect/offlinepay/internal/repository/migrate"
	"github.com/intellect/offlinepay/internal/repository/pgrepo"
	"github.com/intellect/offlinepay/internal/service/account"
	"github.com/intellect/offlinepay/internal/service/demomint"
	"github.com/intellect/offlinepay/internal/service/fraud"
	"github.com/intellect/offlinepay/internal/service/gossip"
	"github.com/intellect/offlinepay/internal/service/identity"
	"github.com/intellect/offlinepay/internal/service/kyc"
	"github.com/intellect/offlinepay/internal/service/reconciliation"
	"github.com/intellect/offlinepay/internal/service/registration/attestation"
	"github.com/intellect/offlinepay/internal/service/settlement"
	"github.com/intellect/offlinepay/internal/service/transfer"
	"github.com/intellect/offlinepay/internal/service/userauth"
	"github.com/intellect/offlinepay/internal/service/wallet"
	grpcsrv "github.com/intellect/offlinepay/internal/transport/grpc/server"
	"github.com/intellect/offlinepay/internal/transport/http/bff"
	"github.com/intellect/offlinepay/internal/transport/http/bff/demo"
	bffgen "github.com/intellect/offlinepay/internal/transport/http/bff/gen"
)

func main() {
	if err := run(); err != nil {
		slog.Error("bff exited", "err", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := loadConfig()
	if err != nil {
		return err
	}

	logging.Setup(cfg.Env, cfg.LogFormat, cfg.LogLevel)

	rootCtx, cancel := context.WithCancel(context.Background())
	defer cancel()

	otelShutdown, err := observability.Setup(rootCtx, observability.TracingConfig{
		Endpoint:    cfg.OTELEndpoint,
		ServiceName: cfg.OTELServiceName,
		Env:         cfg.Env,
		SampleRatio: 1.0,
	})
	if err != nil {
		return fmt.Errorf("otel: %w", err)
	}
	defer func() {
		shutdownCtx, c := context.WithTimeout(context.Background(), 5*time.Second)
		defer c()
		_ = otelShutdown(shutdownCtx)
	}()

	if cfg.MigrateOnBoot {
		if err := migraterunner.Run(rootCtx, cfg.DBURL, db.MigrationsFS); err != nil {
			return fmt.Errorf("migrate on boot: %w", err)
		}
	}

	pool, err := pgxpool.New(rootCtx, cfg.DBURL)
	if err != nil {
		return fmt.Errorf("pgxpool: %w", err)
	}
	defer pool.Close()
	if err := pool.Ping(rootCtx); err != nil {
		return fmt.Errorf("pg ping: %w", err)
	}

	var appCache cache.Cache = cache.Noop{}
	if cfg.RedisURL != "" {
		rdb, err := cache.NewRedis(rootCtx, cfg.RedisURL, slog.Default())
		if err != nil {
			slog.Warn("redis unavailable, continuing without cache", "err", err)
		} else {
			appCache = rdb
			defer rdb.Close()
			slog.Info("redis cache enabled")
		}
	}

	repo := pgrepo.New(pool, appCache)

	// Defensive seed of the system suspense account
	if err := repo.EnsureSystemSuspenseAccount(rootCtx); err != nil {
		return fmt.Errorf("ensure system suspense: %w", err)
	}

	// Sealed-box X25519 key for gossip blobs.
	sealedPub, sealedPriv, err := resolveSealedBoxKey(cfg.SealedBoxPrivKeyHex)
	if err != nil {
		return fmt.Errorf("sealed-box key: %w", err)
	}
	previousKeys, err := resolvePreviousSealedBoxKeys(cfg.SealedBoxPreviousPrivKeysHex)
	if err != nil {
		return fmt.Errorf("sealed-box previous keys: %w", err)
	}

	fraudSvc := fraud.New(repo, nil)
	fraudRecorder := fraud.NewRecorderAdapter(fraudSvc)
	bankSigner, err := buildSigner(cfg, repo)
	if err != nil {
		return fmt.Errorf("crypto signer: %w", err)
	}
	walletSvc := wallet.New(wallet.NewPgRepoAdapter(repo))
	walletSvc.Fraud = fraudSvc
	walletSvc.Signer = bankSigner
	// Share the auto-settle timeout with the wallet service so the
	// recovery quarantine window matches the settlement service's cutoff
	// for late-arriving offline claims.
	walletSvc.AutoSettleTimeout = cfg.AutoSettleTimeout

	settlementSvc := settlement.New(settlement.NewPgRepoAdapter(repo))
	settlementSvc.ClockGrace = cfg.ClockGrace
	settlementSvc.AutoSettleTimeout = cfg.AutoSettleTimeout
	settlementSvc.Fraud = fraudRecorder
	settlementSvc.Detector = fraud.NewDetector(fraudRecorder)

	reconSvc := reconciliation.New(reconciliation.NewPgRepoAdapter(repo))
	reconSvc.Fraud = fraudRecorder

	gossipKeyring := gossip.SealedBoxKeyring{
		Current:  gossip.SealedBoxKey{KeyID: "sealed-box-1", Public: sealedPub, Private: sealedPriv},
		Previous: previousKeys,
	}
	gossipSvc := gossip.New(settlementSvc, gossipKeyring)

	signer := userauth.JWTSigner{Secret: []byte(cfg.JWTSecret), Audience: cfg.JWTAudience, TTL: cfg.AccessTTL}
	sender := userauth.LoggerOTPSender{Logger: slog.Default()}
	authSvc := userauth.New(pool, appCache, signer, sender, cfg.AccessTTL, cfg.RefreshTTL, cfg.OTPTTL)
	authSvc.OTPMaxAttempts = cfg.OTPMaxAttempts

	dsSigner, err := resolveDeviceSessionSigner(cfg)
	if err != nil {
		return fmt.Errorf("device session signer: %w", err)
	}
	authSvc.DeviceSession = dsSigner
	authSvc.DeviceLookup = func(ctx context.Context, deviceID string) (string, bool, error) {
		userID, _, active, err := repo.LookupDeviceForAuth(ctx, deviceID)
		if err != nil {
			return "", false, err
		}
		return userID, active, nil
	}
	slog.Info("device session signer ready",
		"key_id", dsSigner.KeyID,
		"ttl", dsSigner.TTL.String(),
		"pubkey_b64", hex.EncodeToString(dsSigner.PublicKey),
	)

	fraudTransferSvc := fraud.NewTransferService(pool)
	transferSvc := transfer.New(pool, appCache, fraudTransferSvc)
	accountSvc := account.New(pool)
	kycSvc := kyc.New(pool, appCache)

	// In-process "server" handlers (former gRPC servers).
	walletHandler := grpcsrv.NewWalletServer(walletSvc, repo)
	settlementHandler := grpcsrv.NewSettlementServer(settlementSvc, reconSvc, gossipSvc)
	keysHandler := grpcsrv.NewKeysServer(repo, sealedPub[:], "sealed-box-1")
	regHandler := grpcsrv.NewRegistrationServer(repo)
	if err := wireAttestation(cfg, regHandler); err != nil {
		return fmt.Errorf("attestation: %w", err)
	}

	identitySvc := identity.New(
		identity.NewPgRepoAdapter(
			authSvc.Repo.GetMe,
			repo.GetActiveBankSigningKey,
		),
		walletSvc.Signer, // optional KMS signer; nil falls back to in-process bank key
	)

	handler := bff.NewHandler(authSvc, transferSvc, accountSvc, kycSvc, slog.Default())
	handler.Pool = pool
	handler.DevTopUpEnabled = cfg.DevTopUpEnabled
	handler.Identity = identitySvc
	handler.Wallet = walletHandler
	handler.Settlement = settlementHandler
	handler.Keys = keysHandler
	handler.Registration = regHandler
	if cfg.DevTopUpEnabled {
		slog.Warn("dev top-up endpoint enabled -- disable in production")
	}

	demoMintSvc := demomint.New(repo, slog.Default())
	if cfg.DemoMintEnabled {
		slog.Warn("demo-mint funding endpoint enabled -- disable in production")
	}
	strict := bffgen.NewStrictHandler(handler, nil)

	requireJWT := bff.RequireUserJWT(signer)

	// Per-user rate limiter: prefer Redis so multi-pod deployments share
	// one budget, fall back to the in-memory limiter on any Redis failure
	// or when REDIS_URL is unset (POC-friendly default).
	userLimiter := resolveUserLimiter(rootCtx, cfg)
	defer userLimiter.Stop()

	r := chi.NewRouter()
	r.Use(bff.RequestMetadata)
	r.Use(bff.RateLimitByUser(userLimiter))
	r.Use(func(next http.Handler) http.Handler {
		protected := requireJWT(next)
		return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			p := req.URL.Path
			devicesAuthed := strings.HasPrefix(p, "/v1/devices") && p != "/v1/devices/recover"
			// All /v1/keys/realm/* endpoints are device-scoped and hand out
			// the symmetric realm key; they must be authenticated. The
			// sealed-box and bank-public-keys endpoints remain keyless —
			// they only expose public key material.
			keysAuthed := strings.HasPrefix(p, "/v1/keys/realm/") || strings.HasPrefix(p, "/v1/keys/realm?")
			// `/v1/auth/device-session/public-keys` is intentionally
			// unauthed — devices may need it before their access JWT
			// is fresh, and the keys are public material.
			deviceSessionAuthed := p == "/v1/auth/device-session"
			if strings.HasPrefix(p, "/v1/me") ||
				strings.HasPrefix(p, "/v1/accounts/") ||
				p == "/v1/auth/pin" ||
				strings.HasPrefix(p, "/v1/auth/sessions") ||
				strings.HasPrefix(p, "/v1/auth/email/verify") ||
				deviceSessionAuthed ||
				strings.HasPrefix(p, "/v1/kyc/") ||
				strings.HasPrefix(p, "/v1/identity/") ||
				p == "/v1/transfers" ||
				strings.HasPrefix(p, "/v1/transfers/") ||
				strings.HasPrefix(p, "/v1/transfers?") ||
				// /v1/wallet/recover-offline-ceiling is covered by the
				// /v1/wallet/ prefix below — intentionally authed.
				strings.HasPrefix(p, "/v1/wallet/") ||
				strings.HasPrefix(p, "/v1/settlement/") ||
				devicesAuthed ||
				keysAuthed {
				protected.ServeHTTP(w, req)
				return
			}
			next.ServeHTTP(w, req)
		})
	})
	bffgen.HandlerFromMux(strict, r)
	demo.Mount(r, demoMintSvc, slog.Default(), cfg.DemoMintEnabled)

	r.Get("/openapi.yaml", bff.ServeOpenAPISpec)
	r.Get("/docs", bff.ServeSwaggerUI)

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
	}

	// Background crons
	var wg sync.WaitGroup
	wg.Add(3)
	go func() {
		defer wg.Done()
		cronLoop(rootCtx, "wallet.ReleaseOnExpiry", 5*time.Minute, func(ctx context.Context) (int, error) {
			return walletSvc.ReleaseOnExpiry(ctx)
		})
	}()
	go func() {
		defer wg.Done()
		cronLoop(rootCtx, "settlement.AutoSettleSweep", 15*time.Minute, func(ctx context.Context) (int, error) {
			return settlementSvc.AutoSettleSweep(ctx)
		})
	}()
	go func() {
		defer wg.Done()
		dailyAt(rootCtx, "reconciliation.NightlyLedgerReconcile", 3, 0, func(ctx context.Context) {
			rec, err := reconSvc.NightlyLedgerReconcile(ctx)
			if err != nil {
				slog.Error("nightly ledger reconcile failed", "err", err)
				return
			}
			if rec.Status == domain.ReconDiscrepancy {
				slog.Error("ledger reconciliation discrepancy",
					"run_id", rec.ID,
					"discrepancies", len(rec.Discrepancies),
					"severity", "critical",
				)
				return
			}
			slog.Info("nightly ledger reconcile complete", "status", string(rec.Status), "run_id", rec.ID)
		})
	}()

	serverErr := make(chan error, 1)
	go func() {
		slog.Info("bff listening", "addr", cfg.HTTPAddr)
		serverErr <- srv.ListenAndServe()
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-sigCh:
		slog.Info("shutdown signal", "signal", sig.String())
	case err := <-serverErr:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			cancel()
			wg.Wait()
			return fmt.Errorf("http serve: %w", err)
		}
	}

	shutdownCtx, c := context.WithTimeout(context.Background(), 10*time.Second)
	defer c()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Warn("http shutdown error", "err", err)
	}
	cancel()
	wg.Wait()
	return nil
}

// wireAttestation configures the device-attestation verifier. Dev mode
// accepts DevBlob envelopes; production mode refuses to boot unless a
// real Play Integrity + DeviceCheck verifier has been wired separately.
func wireAttestation(cfg *config, reg *grpcsrv.RegistrationServer) error {
	switch cfg.AttestationMode {
	case "", "dev":
		dev := attestation.NewDevVerifier(reg.Nonces)
		reg.Attestation = &attestation.Composite{ByPlatform: map[attestation.Platform]attestation.Verifier{
			attestation.PlatformDev:     dev,
			attestation.PlatformAndroid: dev,
			attestation.PlatformIOS:     dev,
		}}
		return nil
	case "production":
		return fmt.Errorf("ATTESTATION_MODE=production requires wiring real PlayIntegrity + DeviceCheck verifiers")
	default:
		return fmt.Errorf("unknown ATTESTATION_MODE %q", cfg.AttestationMode)
	}
}

func buildSigner(cfg *config, loader kms.KeyLoader) (wallet.Signer, error) {
	switch cfg.CryptoSigner {
	case "", "local":
		return kms.NewLocalSigner(loader), nil
	case "vault":
		return kms.NewVaultSigner(kms.VaultConfig{
			Addr:  cfg.VaultAddr,
			Token: cfg.VaultToken,
			Mount: cfg.VaultTransitMount,
		})
	default:
		return nil, fmt.Errorf("unknown CRYPTO_SIGNER %q (expected local|vault)", cfg.CryptoSigner)
	}
}

// resolveDeviceSessionSigner builds the Ed25519 signer used to mint
// offline device-session tokens. Hex env input is expected to be the
// 64-byte private key (seed||pub) format produced by ed25519.GenerateKey
// — same shape as the ceiling token bank keys for consistency.
func resolveDeviceSessionSigner(cfg *config) (*userauth.DeviceSessionSigner, error) {
	if cfg.DeviceSessionPrivKeyHex == "" {
		pub, priv, err := ed25519.GenerateKey(rand.Reader)
		if err != nil {
			return nil, fmt.Errorf("generate ephemeral device session key: %w", err)
		}
		slog.Warn("BFF_DEVICE_SESSION_PRIVKEY unset — minting ephemeral key; tokens issued before next restart will fail to verify after",
			"pub_hex", hex.EncodeToString(pub))
		return &userauth.DeviceSessionSigner{
			KeyID:      cfg.DeviceSessionKeyID,
			PrivateKey: priv,
			PublicKey:  pub,
			Audience:   cfg.JWTAudience,
			TTL:        cfg.DeviceSessionTTL,
		}, nil
	}
	raw, err := hex.DecodeString(cfg.DeviceSessionPrivKeyHex)
	if err != nil {
		return nil, fmt.Errorf("BFF_DEVICE_SESSION_PRIVKEY hex decode: %w", err)
	}
	if len(raw) != ed25519.PrivateKeySize {
		return nil, fmt.Errorf("BFF_DEVICE_SESSION_PRIVKEY: expected %d bytes, got %d", ed25519.PrivateKeySize, len(raw))
	}
	priv := ed25519.PrivateKey(raw)
	pub, ok := priv.Public().(ed25519.PublicKey)
	if !ok {
		return nil, errors.New("BFF_DEVICE_SESSION_PRIVKEY: cannot derive public key")
	}
	return &userauth.DeviceSessionSigner{
		KeyID:      cfg.DeviceSessionKeyID,
		PrivateKey: priv,
		PublicKey:  pub,
		Audience:   cfg.JWTAudience,
		TTL:        cfg.DeviceSessionTTL,
	}, nil
}

func resolveSealedBoxKey(hexPriv string) (*[32]byte, *[32]byte, error) {
	if hexPriv == "" {
		return crypto.GenerateSealedBoxKeyPair()
	}
	raw, err := hex.DecodeString(hexPriv)
	if err != nil {
		return nil, nil, fmt.Errorf("hex decode: %w", err)
	}
	if len(raw) != 32 {
		return nil, nil, fmt.Errorf("expected 32-byte X25519 key, got %d", len(raw))
	}
	var priv [32]byte
	copy(priv[:], raw)
	pub, err := crypto.DerivePublicFromSealedBoxPrivate(&priv)
	if err != nil {
		return nil, nil, err
	}
	return pub, &priv, nil
}

func resolvePreviousSealedBoxKeys(hexList string) ([]gossip.SealedBoxKey, error) {
	if hexList == "" {
		return nil, nil
	}
	out := make([]gossip.SealedBoxKey, 0)
	for idx, piece := range splitCSV(hexList) {
		raw, err := hex.DecodeString(piece)
		if err != nil {
			return nil, fmt.Errorf("previous key %d: hex decode: %w", idx, err)
		}
		if len(raw) != 32 {
			return nil, fmt.Errorf("previous key %d: expected 32 bytes, got %d", idx, len(raw))
		}
		var priv [32]byte
		copy(priv[:], raw)
		pub, err := crypto.DerivePublicFromSealedBoxPrivate(&priv)
		if err != nil {
			return nil, fmt.Errorf("previous key %d: derive pub: %w", idx, err)
		}
		out = append(out, gossip.SealedBoxKey{
			KeyID:   fmt.Sprintf("sealed-box-prev-%d", idx),
			Public:  pub,
			Private: &priv,
		})
	}
	return out, nil
}

func splitCSV(s string) []string {
	if s == "" {
		return nil
	}
	out := make([]string, 0, 2)
	for _, piece := range strings.Split(s, ",") {
		p := strings.TrimSpace(piece)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

// cronLoop / dailyAt are lifted wholesale from cmd/server.

func cronLoop(ctx context.Context, name string, every time.Duration, fn func(context.Context) (int, error)) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			start := time.Now()
			n, err := fn(ctx)
			dur := time.Since(start)
			if err != nil {
				slog.Error("cron failed", "job", name, "err", err, "duration_ms", dur.Milliseconds())
				continue
			}
			if n > 0 {
				slog.Info("cron processed", "job", name, "processed", n, "duration_ms", dur.Milliseconds())
			}
		}
	}
}

func dailyAt(ctx context.Context, name string, hour, minute int, fn func(context.Context)) {
	for {
		now := time.Now()
		next := time.Date(now.Year(), now.Month(), now.Day(), hour, minute, 0, 0, now.Location())
		if !next.After(now) {
			next = next.Add(24 * time.Hour)
		}
		wait := time.Until(next)
		select {
		case <-ctx.Done():
			return
		case <-time.After(wait):
		}
		slog.Info("cron starting", "job", name)
		fn(ctx)
	}
}
