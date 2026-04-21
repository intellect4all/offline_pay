#!/usr/bin/env bash
# Chaos test: Postgres restarts mid-settlement. On recovery, NATS
# redelivers and processed_events idempotency prevents double-spend.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/ops/chaos/_helpers.sh"

COMPOSE="docker compose -f $REPO_ROOT/docker-compose.yml"
TEST_NAME="postgres-restart"

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
RESP_A=$(signup_user "+2348200000001" "pgA@test.io")
TOKEN_A=$(json_val "$RESP_A" '["access_token"]')
USER_A=$(json_val "$RESP_A" '["user_id"]')
RESP_B=$(signup_user "+2348200000002" "pgB@test.io")
TOKEN_B=$(json_val "$RESP_B" '["access_token"]')
ACCT_B=$(json_val "$RESP_B" '["account_number"]')
set_pin "$TOKEN_A"
top_up_or_seed "$TOKEN_A" "$USER_A" 10000000  # 100k naira

# Step 4 — submit 3 transfers (10k each)
echo "[4] submit transfers p1-p3"
declare -a TIDS
for i in $(seq 1 3); do
  TIDS[$i]=$(submit_transfer "$TOKEN_A" "$ACCT_B" 1000000 "p$i")
  echo "  p$i -> ${TIDS[$i]}"
done

# Step 5 — wait briefly for 1-2 to settle
echo "[5] wait 3s"
sleep 3

# Step 6 — restart postgres
echo "[6] restarting postgres"
$COMPOSE restart postgres

# Step 7 — wait for postgres healthy
echo "[7] waiting for postgres"
wait_for_postgres 60

# Give services a moment to reconnect
sleep 3

# Step 8 — submit 2 more
echo "[8] submit transfers p4-p5"
for i in $(seq 4 5); do
  TIDS[$i]=$(submit_transfer "$TOKEN_A" "$ACCT_B" 1000000 "p$i")
  echo "  p$i -> ${TIDS[$i]}"
done

# Step 9 — wait for settlement
echo "[9] waiting 20s for all to settle"
sleep 20

# Step 10 — verify all SETTLED
echo "[10] verifying all 5 transfers are SETTLED"
ALL_SETTLED=true
for i in $(seq 1 5); do
  STATUS=$(poll_transfer "$TOKEN_A" "${TIDS[$i]}" "SETTLED" 30) || true
  echo "  p$i (${TIDS[$i]}): $STATUS"
  if [ "$STATUS" != "SETTLED" ]; then ALL_SETTLED=false; fi
done

# Step 11 — check balances
echo "[11] checking balances"
BAL_A=$(get_balance "$TOKEN_A" "ACCOUNT_KIND_MAIN")
BAL_B=$(get_balance "$TOKEN_B" "ACCOUNT_KIND_MAIN")
echo "  A main: $BAL_A  B main: $BAL_B"

# Step 12 — check processed_events exactly 5
echo "[12] checking processed_events count"
PE_COUNT=$(processed_events_count)
echo "  processed_events: $PE_COUNT"

# Step 13 — verdict
echo "[13] verdict"
$COMPOSE down -v 2>/dev/null || true

EXPECTED_A=$((10000000 - 5000000))
if [ "$ALL_SETTLED" != "true" ]; then
  fail "$TEST_NAME — not all transfers settled after postgres restart"
fi
if [ "$PE_COUNT" != "5" ]; then
  fail "$TEST_NAME — processed_events=$PE_COUNT (expected 5, possible double-processing)"
fi
if [ "$BAL_A" = "$EXPECTED_A" ] && [ "$BAL_B" = "5000000" ]; then
  pass "$TEST_NAME — 5 transfers settled, no doubles, balances correct"
else
  fail "$TEST_NAME — balances wrong (A=$BAL_A expected=$EXPECTED_A, B=$BAL_B expected=5000000)"
fi
