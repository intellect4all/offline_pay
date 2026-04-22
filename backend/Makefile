.PHONY: test test-integration test-scale lint vet sqlc sqlc-install proto adminapi adminapi-build migrate migrate-down e2e tidy fmt cert-dev install-hooks check check-all bff bff-build bff-gen oapi-install flutter-client-gen transferworker transferworker-build chaos-nats chaos-postgres chaos-worker chaos-all

GO ?= go
SQLC ?= sqlc
BUF ?= buf
MIGRATE ?= migrate
OAPI_CODEGEN ?= oapi-codegen

DB_URL ?= postgres://offlinepay:offlinepay@localhost:5432/offlinepay?sslmode=disable

test:
	$(GO) test ./... -race -count=1

# Integration tests require Docker (testcontainers spins up Postgres 16).
test-integration:
	$(GO) test -tags=integration -count=1 ./internal/repository/...

vet:
	$(GO) vet ./...

lint:
	golangci-lint run ./...

fmt:
	$(GO) fmt ./...
	gofmt -s -w .

tidy:
	$(GO) mod tidy

sqlc:
	$(SQLC) generate

# Install sqlc locally (alternative: `brew install sqlc`, or grab a release
# binary from https://github.com/sqlc-dev/sqlc/releases).
sqlc-install:
	$(GO) install github.com/sqlc-dev/sqlc/cmd/sqlc@latest

proto:
	$(BUF) generate

adminapi:
	$(GO) run ./cmd/adminapi

adminapi-build:
	$(GO) build -o bin/adminapi ./cmd/adminapi

bff:
	$(GO) run ./cmd/bff

bff-build:
	$(GO) build -o bin/bff ./cmd/bff

transferworker:
	$(GO) run ./cmd/transferworker

transferworker-build:
	$(GO) build -o bin/transferworker ./cmd/transferworker

bff-gen:
	$(OAPI_CODEGEN) -config internal/transport/http/bff/gen/config.yaml api/openapi.yaml

flutter-client-gen:
	cd ../mobile/packages/offlinepay_api && \
	  npm_config_cache=/tmp/npm-cache-offlinepay npx -y @openapitools/openapi-generator-cli@latest generate \
	    -i ../../../backend/api/openapi.yaml -g dart-dio -o . \
	    --additional-properties=pubName=offlinepay_api,pubVersion=0.1.0 && \
	  dart pub get && \
	  dart run build_runner build --delete-conflicting-outputs

oapi-install:
	$(GO) install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@latest

migrate:
	$(MIGRATE) -path db/migrations -database "$(DB_URL)" up

migrate-down:
	$(MIGRATE) -path db/migrations -database "$(DB_URL)" down 1

e2e:
	WRITE_STRESS_REPORT=1 $(GO) test ./cmd/e2e -tags=e2e -count=1 -timeout 5m -v

# 100k-txn scale suite (see cmd/e2e/scale_test.go).
test-scale:
	$(GO) test ./cmd/e2e -tags=scale -count=1 -timeout 15m -run TestScaleHundredK -v

# Install the local pre-commit hook (substitute for remote CI in this PoC).
install-hooks:
	@hookdir="$$(git -C .. rev-parse --git-dir)/hooks"; \
	  mkdir -p "$$hookdir"; \
	  ln -sf ../../backend/ops/git-hooks/pre-commit "$$hookdir/pre-commit"; \
	  chmod +x ops/git-hooks/pre-commit; \
	  echo "installed pre-commit hook -> $$hookdir/pre-commit"

# Fast sanity: matches what the pre-commit hook runs.
check: vet test
	@if command -v dart >/dev/null 2>&1; then \
	  (cd ../mobile/packages/core && dart test); \
	else \
	  echo "dart not on PATH; skipping dart test"; \
	fi

# Full suite: unit + integration + e2e + dart. Slow.
check-all: check test-integration e2e

# ---------- chaos tests ----------

chaos-nats:
	bash ../ops/chaos/nats-kill.sh

chaos-postgres:
	bash ../ops/chaos/postgres-restart.sh

chaos-worker:
	bash ../ops/chaos/worker-stop.sh

chaos-all: chaos-nats chaos-postgres chaos-worker
