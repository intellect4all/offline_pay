package main

import (
	"os"
	"strconv"
	"time"

	"github.com/nats-io/nats.go"
)

type config struct {
	Env       string
	LogFormat string
	LogLevel  string

	DBURL         string
	MigrateOnBoot bool

	NATSURL     string
	BatchSize   int
	Interval    time.Duration
	MetricsAddr string

	OTELEndpoint    string
	OTELServiceName string

	FCMProjectID       string
	FCMServiceAccount  string
}

func loadConfig() *config {
	return &config{
		Env:             getenv("OFFLINEPAY_ENV", "local"),
		LogFormat:       getenv("OFFLINEPAY_LOG_FORMAT", ""),
		LogLevel:        getenv("OFFLINEPAY_LOG_LEVEL", "info"),
		DBURL:           getenv("DB_URL", "postgres://offlinepay:offlinepay@localhost:5432/offlinepay?sslmode=disable"),
		MigrateOnBoot:   getenvBool("MIGRATE_ON_BOOT", false),
		NATSURL:         getenv("NATS_URL", nats.DefaultURL),
		BatchSize:       intEnv("WORKER_BATCH_SIZE", 16),
		Interval:        time.Duration(intEnv("WORKER_DISPATCH_INTERVAL_MS", 500)) * time.Millisecond,
		MetricsAddr:     getenv("WORKER_METRICS_ADDR", ":9102"),
		OTELEndpoint:    os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"),
		OTELServiceName: getenv("OTEL_SERVICE_NAME", "offlinepay-transferworker"),

		FCMProjectID:      os.Getenv("FCM_PROJECT_ID"),
		FCMServiceAccount: os.Getenv("FCM_SERVICE_ACCOUNT_JSON"),
	}
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
