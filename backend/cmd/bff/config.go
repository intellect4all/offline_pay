package main

import (
	"errors"
	"log/slog"
	"os"
	"strconv"
	"time"
)

type config struct {
	Env       string
	LogFormat string
	LogLevel  string

	DBURL         string
	MigrateOnBoot bool

	HTTPAddr       string
	JWTSecret      string
	JWTAudience    string
	AccessTTL      time.Duration
	RefreshTTL     time.Duration
	OTPTTL         time.Duration
	OTPMaxAttempts int

	OTELEndpoint    string
	OTELServiceName string

	RateLimitRPS   float64
	RateLimitBurst int

	DevTopUpEnabled bool
	DemoMintEnabled bool

	// RedisURL is the (optional) cache backend.
	RedisURL string

	// Settlement / wallet service knobs (previously lived on cmd/server).
	CeilingTTL        time.Duration
	AutoSettleTimeout time.Duration
	ClockGrace        time.Duration

	// Sealed-box X25519 keys for gossip. Empty means "generate an
	// ephemeral pair at boot" — dev only; blobs sealed before a restart
	// become undecryptable.
	SealedBoxPrivKeyHex        string
	SealedBoxPreviousPrivKeysHex string

	// Crypto signer selection: "local" reads bank key from Postgres,
	// "vault" talks to HashiCorp Vault transit.
	CryptoSigner      string
	VaultAddr         string
	VaultToken        string
	VaultTransitMount string

	// Device attestation mode ("dev" or "production").
	AttestationMode string

	// Device session token signer. Hex-encoded 64-byte Ed25519 private
	// key (seed||pub). Empty means "generate an ephemeral keypair at
	// boot" — fine for dev, but tokens minted by a previous boot
	// silently fail signature verification on the device after restart.
	DeviceSessionPrivKeyHex string
	DeviceSessionKeyID      string
	DeviceSessionTTL        time.Duration
}

func loadConfig() (*config, error) {
	c := &config{
		Env:             getenv("OFFLINEPAY_ENV", "local"),
		LogFormat:       getenv("OFFLINEPAY_LOG_FORMAT", ""),
		LogLevel:        getenv("OFFLINEPAY_LOG_LEVEL", "info"),
		DBURL:           getenv("DB_URL", "postgres://offlinepay:offlinepay@localhost:5432/offlinepay?sslmode=disable"),
		MigrateOnBoot:   getenvBool("MIGRATE_ON_BOOT", false),
		HTTPAddr:        getenv("BFF_HTTP_ADDR", ":8082"),
		JWTSecret:       os.Getenv("BFF_JWT_SECRET"),
		JWTAudience:     getenv("BFF_JWT_AUDIENCE", "offlinepay-user"),
		AccessTTL:       time.Duration(intEnv("BFF_ACCESS_TTL_MINUTES", 15)) * time.Minute,
		RefreshTTL:      time.Duration(intEnv("BFF_REFRESH_TTL_HOURS", 168)) * time.Hour,
		OTPTTL:          time.Duration(intEnv("BFF_OTP_TTL_MINUTES", 5)) * time.Minute,
		OTPMaxAttempts:  intEnv("BFF_OTP_MAX_ATTEMPTS", 5),
		OTELEndpoint:    os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"),
		OTELServiceName: getenv("OTEL_SERVICE_NAME", "offlinepay-bff"),
		RateLimitRPS:    floatEnv("BFF_RATE_LIMIT_RPS", 20),
		RateLimitBurst:  intEnv("BFF_RATE_LIMIT_BURST", 40),
		RedisURL:        os.Getenv("REDIS_URL"),

		CeilingTTL:        time.Duration(intEnv("CEILING_TTL_HOURS", 24)) * time.Hour,
		AutoSettleTimeout: time.Duration(intEnv("AUTO_SETTLE_TIMEOUT_HOURS", 72)) * time.Hour,
		ClockGrace:        time.Duration(intEnv("CLOCK_GRACE_MINUTES", 30)) * time.Minute,

		SealedBoxPrivKeyHex:          os.Getenv("SERVER_SEALED_BOX_PRIVKEY"),
		SealedBoxPreviousPrivKeysHex: os.Getenv("SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS"),

		CryptoSigner:      getenv("CRYPTO_SIGNER", "local"),
		VaultAddr:         os.Getenv("VAULT_ADDR"),
		VaultToken:        os.Getenv("VAULT_TOKEN"),
		VaultTransitMount: getenv("VAULT_TRANSIT_MOUNT", "transit"),

		AttestationMode: getenv("ATTESTATION_MODE", "dev"),

		DeviceSessionPrivKeyHex: os.Getenv("BFF_DEVICE_SESSION_PRIVKEY"),
		DeviceSessionKeyID:      getenv("BFF_DEVICE_SESSION_KEY_ID", "device-session-1"),
		DeviceSessionTTL:        time.Duration(intEnv("BFF_DEVICE_SESSION_TTL_HOURS", 14*24)) * time.Hour,
	}

	prod := c.Env == "production"

	c.DevTopUpEnabled = getenvBool("BFF_ENABLE_DEV_TOPUP", !prod)
	c.DemoMintEnabled = getenvBool("BFF_ENABLE_DEMO_MINT", !prod)

	if len(c.JWTSecret) < 32 {
		if prod {
			return nil, errors.New("BFF_JWT_SECRET must be set (>= 32 bytes) in production")
		}
		slog.Warn("BFF_JWT_SECRET is short or unset; using insecure dev default")
		c.JWTSecret = "dev-insecure-bff-secret-change-me-0123456789"
	}

	return c, nil
}

func getenv(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return def
}

func getenvBool(key string, def bool) bool {
	v, ok := os.LookupEnv(key)
	if !ok || v == "" {
		return def
	}
	switch v {
	case "1", "true", "TRUE", "yes", "on":
		return true
	}
	return false
}

func floatEnv(key string, def float64) float64 {
	v, ok := os.LookupEnv(key)
	if !ok || v == "" {
		return def
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil {
		return def
	}
	return f
}

func intEnv(key string, def int) int {
	v, ok := os.LookupEnv(key)
	if !ok || v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return 0
	}
	return n
}
