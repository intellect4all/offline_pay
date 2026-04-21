#!/usr/bin/env bash
# Common helpers for chaos test scripts.
# Sourced (not executed) by each test script.

set -euo pipefail

COMPOSE="docker compose -f ${REPO_ROOT:?}/docker-compose.yml"
BFF_URL="http://localhost:8082"
DB_DSN="postgres://offlinepay:offlinepay@localhost:5432/offlinepay?sslmode=disable"

# ---------- json helper ----------
json_val() {
  local json="$1" key="$2"
  if command -v jq &>/dev/null; then
    echo "$json" | jq -r "$key"
  else
    python3 -c "import sys,json; print(json.loads(sys.stdin.read())${key})" <<< "$json"
  fi
}

# ---------- lifecycle ----------
wait_for_health() {
  local url="$1" timeout_s="${2:-60}" elapsed=0
  echo "  waiting for $url (timeout ${timeout_s}s)"
  while ! curl -sf "$url" >/dev/null 2>&1; do
    sleep 1; elapsed=$((elapsed+1))
    if [ "$elapsed" -ge "$timeout_s" ]; then
      echo "TIMEOUT waiting for $url"; return 1
    fi
  done
  echo "  $url healthy after ${elapsed}s"
}

wait_for_postgres() {
  local timeout_s="${1:-60}" elapsed=0
  echo "  waiting for postgres (timeout ${timeout_s}s)"
  while ! $COMPOSE exec -T postgres pg_isready -U offlinepay >/dev/null 2>&1; do
    sleep 1; elapsed=$((elapsed+1))
    if [ "$elapsed" -ge "$timeout_s" ]; then
      echo "TIMEOUT waiting for postgres"; return 1
    fi
  done
  echo "  postgres ready after ${elapsed}s"
}

# ---------- auth ----------
signup_user() {
  local phone="$1" email="$2" password="${3:-Password1!}"
  local body
  body=$(printf '{"phone":"%s","password":"%s","first_name":"Chaos","last_name":"Test","email":"%s"}' "$phone" "$password" "$email")
  local resp
  resp=$(curl -sf -X POST "$BFF_URL/v1/auth/signup" \
    -H "Content-Type: application/json" -d "$body")
  echo "$resp"
}

set_pin() {
  local token="$1" pin="${2:-1234}"
  curl -sf -X POST "$BFF_URL/v1/auth/pin" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"pin\":\"$pin\"}" >/dev/null
}

# ---------- wallet ----------
top_up_or_seed() {
  local token="$1" user_id="$2" amount_kobo="$3"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BFF_URL/v1/wallet/top-up" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"amount_kobo\":$amount_kobo}")
  if [ "$code" = "200" ]; then
    echo "  topped up via API ($amount_kobo kobo)"
    return 0
  fi
  echo "  top-up API returned $code; seeding via SQL"
  $COMPOSE exec -T postgres psql -U offlinepay -d offlinepay -c \
    "UPDATE accounts SET balance_kobo = balance_kobo + $amount_kobo WHERE user_id = '$user_id' AND kind = 'ACCOUNT_KIND_MAIN';" >/dev/null
}

get_balance() {
  local token="$1" kind="$2"
  local resp
  resp=$(curl -sf -X GET "$BFF_URL/v1/wallet/balances" \
    -H "Authorization: Bearer $token")
  if command -v jq &>/dev/null; then
    echo "$resp" | jq -r ".balances[] | select(.kind==\"$kind\") | .balance_kobo"
  else
    python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
for b in data['balances']:
    if b['kind'] == '$kind':
        print(b['balance_kobo'])
        break
" <<< "$resp"
  fi
}

# ---------- transfers ----------
submit_transfer() {
  local token="$1" receiver_acct="$2" amount="$3" ref="$4" pin="${5:-1234}"
  local resp
  resp=$(curl -sf -X POST "$BFF_URL/v1/transfers" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"receiver_account_number\":\"$receiver_acct\",\"amount_kobo\":$amount,\"reference\":\"$ref\",\"pin\":\"$pin\"}")
  json_val "$resp" '["id"]'
}

poll_transfer() {
  local token="$1" tid="$2" expected="$3" timeout_s="${4:-30}" elapsed=0
  while true; do
    local resp status
    resp=$(curl -sf -X GET "$BFF_URL/v1/transfers/$tid" \
      -H "Authorization: Bearer $token") || true
    status=$(json_val "$resp" '["status"]' 2>/dev/null || echo "UNKNOWN")
    if [ "$status" = "$expected" ]; then
      echo "$status"; return 0
    fi
    sleep 1; elapsed=$((elapsed+1))
    if [ "$elapsed" -ge "$timeout_s" ]; then
      echo "$status"; return 1
    fi
  done
}

# ---------- db helpers ----------
db_query() {
  $COMPOSE exec -T postgres psql -U offlinepay -d offlinepay -tAc "$1"
}

outbox_pending_count() {
  db_query "SELECT COUNT(*) FROM outbox WHERE dispatched_at IS NULL;"
}

processed_events_count() {
  db_query "SELECT COUNT(*) FROM processed_events;"
}

# ---------- assertions ----------
assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $msg: expected=$expected actual=$actual"
    return 1
  fi
  echo "  OK: $msg ($actual)"
}

pass() {
  echo ""
  echo "========================================="
  echo "  PASS: $1"
  echo "========================================="
  exit 0
}

fail() {
  echo ""
  echo "========================================="
  echo "  FAIL: $1"
  echo "========================================="
  exit 1
}
