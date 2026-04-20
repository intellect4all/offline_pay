// Package config loads runtime configuration from environment variables.
package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Config is the process-wide runtime configuration.
type Config struct {
	Env       string
	LogLevel  string
	LogFormat string

	DBURL    string
	RedisURL string
	NATSURL  string

	GRPCListenAddr string
	HTTPListenAddr string

	CeilingTTL         time.Duration
	AutoSettleTimeout  time.Duration
	ClockGrace         time.Duration
	ServerSealedBoxKey string
	// ServerSealedBoxPreviousKeys is a comma-separated list of hex-encoded
	// retired X25519 private keys. The gossip service tries them (after the
	// current key) when opening inbound blobs — lets rotation keep an
	// overlap window where in-flight blobs sealed to the old key still
	// decrypt. Operators should securely delete a keyfile once the overlap
	// window ends; at that point blobs sealed to it become undecryptable,
	// which is the forward-secrecy property.
	ServerSealedBoxPreviousKeys string

	// GRPCReflection enables the gRPC reflection service. Off by default;
	// enable in dev compose or for `grpcurl` debugging.
	GRPCReflection bool

	// TLS configuration. TLSMode is "off", "server", or "mtls". Production
	// refuses to start when TLSMode == "off".
	TLSMode          string
	TLSCertFile      string
	TLSKeyFile       string
	TLSClientCAFile  string

	// JWT auth. AuthAudience is the expected `aud` claim. AuthTokenTTL caps
	// how long a freshly-minted device JWT stays valid. AuthClockSkew tolerates
	// minor clock drift when validating iat/exp.
	AuthAudience     string
	AuthTokenTTL     time.Duration
	AuthClockSkew    time.Duration

	// Rate limiting.
	RateLimitBucketSize  int
	RateLimitRefillPerSec int
	MaxRequestBytes      int

	// Observability + ops.
	MigrateOnBoot       bool
	OTelExporterEndpoint string
	OTelServiceName      string
	OTelSampleRatio      float64
	MetricsAddr          string

	// KMS / bank-signer selection. CryptoSigner ∈ {"local", "vault"}. When
	// "vault" the VaultAddr + VaultToken must be set and the transit engine
	// must hold an Ed25519 key whose name matches each bank_signing_keys
	// row's key_id.
	CryptoSigner      string
	VaultAddr         string
	VaultToken        string
	VaultTransitMount string

	// Device attestation. AttestationMode ∈ {"dev", "production"}.
	// "production" refuses to boot unless both Android + iOS verifiers
	// are fully configured; "dev" wires DevVerifier so homelab
	// deployments work without Google / Apple credentials.
	AttestationMode string
}

// Load reads environment variables into a Config. Unset values fall back to
// conservative defaults suitable for local development.
func Load() (Config, error) {
	c := Config{
		Env:                getenv("OFFLINEPAY_ENV", "local"),
		LogLevel:           getenv("OFFLINEPAY_LOG_LEVEL", "info"),
		LogFormat:          getenv("OFFLINEPAY_LOG_FORMAT", ""),
		DBURL:              getenv("DB_URL", "postgres://offlinepay:offlinepay@localhost:5432/offlinepay?sslmode=disable"),
		RedisURL:           getenv("REDIS_URL", "redis://localhost:6379/0"),
		NATSURL:            getenv("NATS_URL", "nats://localhost:4222"),
		GRPCListenAddr:     getenv("GRPC_LISTEN_ADDR", ":9090"),
		HTTPListenAddr:     getenv("HTTP_LISTEN_ADDR", ":8080"),
		ServerSealedBoxKey:          os.Getenv("SERVER_SEALED_BOX_PRIVKEY"),
		ServerSealedBoxPreviousKeys: os.Getenv("SERVER_SEALED_BOX_PREVIOUS_PRIVKEYS"),
		GRPCReflection:     getenvBool("GRPC_REFLECTION", false),
		TLSMode:            getenv("TLS_MODE", "off"),
		TLSCertFile:        os.Getenv("TLS_CERT_FILE"),
		TLSKeyFile:         os.Getenv("TLS_KEY_FILE"),
		TLSClientCAFile:    os.Getenv("TLS_CLIENT_CA_FILE"),
		AuthAudience:       getenv("AUTH_AUDIENCE", "offlinepay"),
		MigrateOnBoot:        getenvBool("MIGRATE_ON_BOOT", false),
		OTelExporterEndpoint: os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"),
		OTelServiceName:      getenv("OTEL_SERVICE_NAME", "offlinepay-server"),
		MetricsAddr:          getenv("METRICS_ADDR", ""),
		CryptoSigner:         getenv("CRYPTO_SIGNER", "local"),
		VaultAddr:            os.Getenv("VAULT_ADDR"),
		VaultToken:           os.Getenv("VAULT_TOKEN"),
		VaultTransitMount:    getenv("VAULT_TRANSIT_MOUNT", "transit"),
		AttestationMode:      getenv("ATTESTATION_MODE", "dev"),
	}

	ratioStr := getenv("OTEL_TRACES_SAMPLER_RATIO", "")
	if ratioStr == "" {
		if c.Env == "production" {
			c.OTelSampleRatio = 0.1
		} else {
			c.OTelSampleRatio = 1.0
		}
	} else {
		r, err := strconv.ParseFloat(ratioStr, 64)
		if err != nil {
			return c, fmt.Errorf("config: OTEL_TRACES_SAMPLER_RATIO must be a float: %w", err)
		}
		c.OTelSampleRatio = r
	}

	tokenMin, err := getenvInt("AUTH_TOKEN_TTL_MINUTES", 15)
	if err != nil {
		return c, err
	}
	c.AuthTokenTTL = time.Duration(tokenMin) * time.Minute

	skewS, err := getenvInt("AUTH_CLOCK_SKEW_SECONDS", 60)
	if err != nil {
		return c, err
	}
	c.AuthClockSkew = time.Duration(skewS) * time.Second

	bucket, err := getenvInt("RATELIMIT_BUCKET_SIZE", 60)
	if err != nil {
		return c, err
	}
	c.RateLimitBucketSize = bucket

	refill, err := getenvInt("RATELIMIT_REFILL_PER_SEC", 10)
	if err != nil {
		return c, err
	}
	c.RateLimitRefillPerSec = refill

	maxBytes, err := getenvInt("MAX_REQUEST_BYTES", 1<<20)
	if err != nil {
		return c, err
	}
	c.MaxRequestBytes = maxBytes

	ttlH, err := getenvInt("CEILING_TTL_HOURS", 24)
	if err != nil {
		return c, err
	}
	c.CeilingTTL = time.Duration(ttlH) * time.Hour

	autoH, err := getenvInt("AUTO_SETTLE_TIMEOUT_HOURS", 72)
	if err != nil {
		return c, err
	}
	c.AutoSettleTimeout = time.Duration(autoH) * time.Hour

	graceM, err := getenvInt("CLOCK_GRACE_MINUTES", 30)
	if err != nil {
		return c, err
	}
	c.ClockGrace = time.Duration(graceM) * time.Minute

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
	case "1", "true", "TRUE", "True", "yes", "on":
		return true
	}
	return false
}

func getenvInt(key string, def int) (int, error) {
	v, ok := os.LookupEnv(key)
	if !ok || v == "" {
		return def, nil
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return 0, fmt.Errorf("config: %s must be an integer: %w", key, err)
	}
	return n, nil
}
