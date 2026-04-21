#!/usr/bin/env bash
# Chaos test: NATS dies mid-processing. Outbox rows pile up.
# NATS restarts. All transfers settle.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/ops/chaos/_helpers.sh"

COMPOSE="docker compose -f $REPO_ROOT/docker-compose.yml"
TEST_NAME="nats-kill"

echo "=== Chaos: $TEST_NAME ==="

# Step 1 — clean start
echo "[1] compose down -v + up"
$COMPOSE down -v 2>/dev/null || true
$COMPOSE up -d postgres redis nats server bff transferworker

# Step 2 — wait for BFF health
echo "[2] waiting for BFF"
wait_for_health "$BFF_URL/health" 90

# Step 3 — signup users
echo "[3] signup user A + B, set PIN"
RESP_A=$(signup_user "+2348100000001" "chaosA@test.io")
TOKEN_A=$(json_val "$RESP_A" '["access_token"]')
USER_A=$(json_val "$RESP_A" '["user_id"]')
RESP_B=$(signup_user "+2348100000002" "chaosB@test.io")
TOKEN_B=$(json_val "$RESP_B" '["access_token"]')
ACCT_B=$(json_val "$RESP_B" '["account_number"]')
set_pin "$TOKEN_A"
top_up_or_seed "$TOKEN_A" "$USER_A" 50000000  # 500k naira

# Step 4 — submit 5 transfers (c1-c5)
echo "[4] submit transfers c1-c5"
declare -a TIDS
for i in $(seq 1 5); do
  TIDS[$i]=$(submit_transfer "$TOKEN_A" "$ACCT_B" 100000 "c$i")
  echo "  c$i -> ${TIDS[$i]}"
done

# Step 5 — wait for some to settle
echo "[5] wait 5s for settlement"
sleep 5

# Step 6 — kill NATS
echo "[6] stopping NATS"
$COMPOSE stop nats

# Step 7 — submit 5 more (c6-c10)
echo "[7] submit transfers c6-c10 (NATS down)"
for i in $(seq 6 10); do
  TIDS[$i]=$(submit_transfer "$TOKEN_A" "$ACCT_B" 100000 "c$i")
  echo "  c$i -> ${TIDS[$i]}"
done

# Step 8 — verify c6 is ACCEPTED (not SETTLED)
echo "[8] verify c6 is ACCEPTED"
RESP=$(curl -sf -X GET "$BFF_URL/v1/transfers/${TIDS[6]}" \
  -H "Authorization: Bearer $TOKEN_A")
STATUS=$(json_val "$RESP" '["status"]')
echo "  c6 status: $STATUS"
if [ "$STATUS" = "SETTLED" ]; then
  echo "  WARNING: c6 already SETTLED — NATS may have had buffered messages"
fi

# Step 9 — check outbox pending
echo "[9] check outbox pending"
sleep 5
PENDING=$(outbox_pending_count)
echo "  outbox pending: $PENDING"

# Step 10 — restart NATS
echo "[10] restarting NATS"
$COMPOSE start nats

# Step 11 — wait for catchup
echo "[11] waiting 20s for dispatcher + processor catchup"
sleep 20

# Step 12 — poll all 10 transfers -> SETTLED
echo "[12] verifying all 10 transfers are SETTLED"
ALL_SETTLED=true
for i in $(seq 1 10); do
  STATUS=$(poll_transfer "$TOKEN_A" "${TIDS[$i]}" "SETTLED" 30) || true
  echo "  c$i (${TIDS[$i]}): $STATUS"
  if [ "$STATUS" != "SETTLED" ]; then ALL_SETTLED=false; fi
done

# Step 13 — verify balances
echo "[13] checking balances"
BAL_A=$(get_balance "$TOKEN_A" "ACCOUNT_KIND_MAIN")
BAL_B=$(get_balance "$TOKEN_B" "ACCOUNT_KIND_MAIN")
echo "  A main: $BAL_A  B main: $BAL_B"

# Step 14 — verdict
echo "[14] verdict"
$COMPOSE down -v 2>/dev/null || true

if [ "$ALL_SETTLED" = "true" ]; then
  EXPECTED_A=$((50000000 - 1000000))
  if [ "$BAL_A" = "$EXPECTED_A" ] && [ "$BAL_B" = "1000000" ]; then
    pass "$TEST_NAME — all 10 transfers settled after NATS restart, balances correct"
  else
    fail "$TEST_NAME — transfers settled but balances wrong (A=$BAL_A expected=$EXPECTED_A, B=$BAL_B expected=1000000)"
  fi
else
  fail "$TEST_NAME — not all transfers settled after NATS restart"
fi
