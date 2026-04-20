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

	HTTPAddr    string
	CORSOrigin  string
	JWTSecret   string
	JWTAudience string
	AccessTTL   time.Duration
	RefreshTTL  time.Duration

	OTELEndpoint    string
	OTELServiceName string
}

func loadConfig() (*config, error) {
	c := &config{
		Env:             getenv("OFFLINEPAY_ENV", "local"),
		LogFormat:       getenv("OFFLINEPAY_LOG_FORMAT", ""),
		LogLevel:        getenv("OFFLINEPAY_LOG_LEVEL", "info"),
		DBURL:           getenv("DB_URL", "postgres://offlinepay:offlinepay@localhost:5432/offlinepay?sslmode=disable"),
		MigrateOnBoot:   getenvBool("MIGRATE_ON_BOOT", false),
		HTTPAddr:        getenv("ADMIN_HTTP_ADDR", ":8081"),
		CORSOrigin:      getenv("ADMIN_CORS_ORIGIN", "http://localhost:3000"),
		JWTSecret:       os.Getenv("ADMIN_JWT_SECRET"),
		JWTAudience:     getenv("ADMIN_JWT_AUDIENCE", "offlinepay-admin"),
		AccessTTL:       time.Duration(intEnv("ADMIN_ACCESS_TTL_MINUTES", 15)) * time.Minute,
		RefreshTTL:      time.Duration(intEnv("ADMIN_REFRESH_TTL_HOURS", 168)) * time.Hour,
		OTELEndpoint:    os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"),
		OTELServiceName: getenv("OTEL_SERVICE_NAME", "offlinepay-adminapi"),
	}

	if len(c.JWTSecret) < 32 {
		if c.Env == "production" {
			return nil, errors.New("ADMIN_JWT_SECRET must be set (>= 32 bytes) in production")
		}
		slog.Warn("ADMIN_JWT_SECRET is short or unset; using insecure dev default")
		c.JWTSecret = "dev-insecure-adminapi-secret-change-me-0123456789"
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

func intEnv(key string, def int) int {
	v, ok := os.LookupEnv(key)
	if !ok || v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return def
	}
	return n
}
