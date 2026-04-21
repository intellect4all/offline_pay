#!/usr/bin/env bash
# Chaos test: transferworker stopped for extended period. Outbox
# accumulates. Worker restarts. Entire backlog drains.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/ops/chaos/_helpers.sh"

COMPOSE="docker compose -f $REPO_ROOT/docker-compose.yml"
TEST_NAME="worker-stop"

echo "=== Chaos: $TEST_NAME ==="

# Step 1 — clean start
echo "[1] compose down -v + up"
$COMPOSE down -v 2>/dev/null || true
$COMPOSE up -d postgres redis nats server bff transferworker

# Step 2 — wait for BFF
echo "[2] waiting for BFF"
wait_for_health "$BFF_URL/health" 90

# Step 3 — signup + seed
echo "[3] signup A + B, set PIN, seed"
RESP_A=$(signup_user "+2348300000001" "wkA@test.io")
TOKEN_A=$(json_val "$RESP_A" '["access_token"]')
USER_A=$(json_val "$RESP_A" '["user_id"]')
RESP_B=$(signup_user "+2348300000002" "wkB@test.io")
TOKEN_B=$(json_val "$RESP_B" '["access_token"]')
ACCT_B=$(json_val "$RESP_B" '["account_number"]')
set_pin "$TOKEN_A"
top_up_or_seed "$TOKEN_A" "$USER_A" 50000000  # 500k naira

# Step 4 — stop the worker
echo "[4] stopping transferworker"
$COMPOSE stop transferworker

# Step 5 — submit 20 transfers
echo "[5] submit transfers w1-w20"
declare -a TIDS
for i in $(seq 1 20); do
  TIDS[$i]=$(submit_transfer "$TOKEN_A" "$ACCT_B" 100000 "w$i")
  echo "  w$i -> ${TIDS[$i]}"
done

# Step 6 — verify none are SETTLED
echo "[6] verify none are SETTLED (no worker running)"
sleep 1
SETTLED_COUNT=0
for i in $(seq 1 20); do
  RESP=$(curl -sf -X GET "$BFF_URL/v1/transfers/${TIDS[$i]}" \
    -H "Authorization: Bearer $TOKEN_A") || true
  STATUS=$(json_val "$RESP" '["status"]' 2>/dev/null || echo "UNKNOWN")
  if [ "$STATUS" = "SETTLED" ]; then SETTLED_COUNT=$((SETTLED_COUNT+1)); fi
done
echo "  settled while worker down: $SETTLED_COUNT"
if [ "$SETTLED_COUNT" -gt 0 ]; then
  echo "  WARNING: $SETTLED_COUNT transfers settled without worker (unexpected)"
fi

# Step 7 — check outbox pending
echo "[7] check outbox pending"
sleep 5
PENDING=$(outbox_pending_count)
echo "  outbox pending: $PENDING"

# Step 8 — restart worker
echo "[8] restarting transferworker"
$COMPOSE start transferworker

# Step 9 — wait for backlog drain
echo "[9] waiting 30s for backlog to drain"
sleep 30

# Step 10 — verify all 20 SETTLED
echo "[10] verifying all 20 transfers are SETTLED"
ALL_SETTLED=true
for i in $(seq 1 20); do
  STATUS=$(poll_transfer "$TOKEN_A" "${TIDS[$i]}" "SETTLED" 30) || true
  echo "  w$i (${TIDS[$i]}): $STATUS"
  if [ "$STATUS" != "SETTLED" ]; then ALL_SETTLED=false; fi
done

# Step 11 — verify balances
echo "[11] checking balances"
BAL_A=$(get_balance "$TOKEN_A" "ACCOUNT_KIND_MAIN")
BAL_B=$(get_balance "$TOKEN_B" "ACCOUNT_KIND_MAIN")
echo "  A main: $BAL_A  B main: $BAL_B"

# Step 12 — verdict
echo "[12] verdict"
$COMPOSE down -v 2>/dev/null || true

EXPECTED_A=$((50000000 - 2000000))
if [ "$ALL_SETTLED" = "true" ]; then
  if [ "$BAL_A" = "$EXPECTED_A" ] && [ "$BAL_B" = "2000000" ]; then
    pass "$TEST_NAME — all 20 transfers settled after worker restart, balances correct"
  else
    fail "$TEST_NAME — transfers settled but balances wrong (A=$BAL_A expected=$EXPECTED_A, B=$BAL_B expected=2000000)"
  fi
else
  fail "$TEST_NAME — not all transfers settled after worker restart"
fi
