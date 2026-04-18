-- Online intra-bank P2P transfers. Two parallel accept-insert forms:
-- one for paths that don't fraud-score (tests, internal tooling) and
-- one that captures the fraud decision. Projection reads (the suffix
-- `Projection` variants) omit the `flagged` column so the BFF surface
-- doesn't leak the internal fraud flag to the user-facing client.

-- name: CreateTransferAccepted :one
INSERT INTO transfers (id, sender_user_id, receiver_user_id, receiver_account_number, amount_kobo, status, reference)
VALUES ($1, $2, $3, $4, $5, 'ACCEPTED', $6)
RETURNING *;

-- CreateTransferAcceptedFlagged is the accept-path insert that carries
-- the fraud-scorer's FLAG decision. BLOCK outcomes short-circuit
-- upstream and never produce a transfer row; ALLOW outcomes use the
-- narrow form above.
--
-- name: CreateTransferAcceptedFlagged :one
INSERT INTO transfers (id, sender_user_id, receiver_user_id, receiver_account_number, amount_kobo, status, reference, flagged)
VALUES ($1, $2, $3, $4, $5, 'ACCEPTED', $6, $7)
RETURNING id, sender_user_id, receiver_user_id, receiver_account_number,
          amount_kobo, status, reference, failure_reason, created_at, settled_at;

-- ListTransfersForUser returns transfers where the user is either
-- sender or receiver. Powers the BFF /v1/transfers list.
--
-- name: ListTransfersForUser :many
SELECT id, sender_user_id, receiver_user_id, receiver_account_number,
       amount_kobo, status, reference, failure_reason, created_at, settled_at
FROM transfers
WHERE sender_user_id = $1 OR receiver_user_id = $1
ORDER BY created_at DESC, id DESC
LIMIT $2 OFFSET $3;

-- GetTransferProjection is the user-facing single-row fetch. Omits
-- `flagged` so the BFF never surfaces the internal fraud flag.
--
-- name: GetTransferProjection :one
SELECT id, sender_user_id, receiver_user_id, receiver_account_number,
       amount_kobo, status, reference, failure_reason, created_at, settled_at
FROM transfers WHERE id = $1;

-- GetTransferByRefProjection mirrors GetTransferProjection but looks
-- up by (sender, reference) — the transfer idempotency key.
--
-- name: GetTransferByRefProjection :one
SELECT id, sender_user_id, receiver_user_id, receiver_account_number,
       amount_kobo, status, reference, failure_reason, created_at, settled_at
FROM transfers WHERE sender_user_id = $1 AND reference = $2;

-- name: GetTransfer :one
SELECT * FROM transfers WHERE id = $1;

-- name: GetTransferByRef :one
SELECT * FROM transfers WHERE sender_user_id = $1 AND reference = $2;

-- name: ListTransfersSent :many
SELECT * FROM transfers
WHERE sender_user_id = $1
ORDER BY created_at DESC, id DESC
LIMIT $2 OFFSET $3;

-- name: ListTransfersReceived :many
SELECT * FROM transfers
WHERE receiver_user_id = $1
ORDER BY created_at DESC, id DESC
LIMIT $2 OFFSET $3;

-- name: UpdateTransferStatus :exec
UPDATE transfers
SET status = $2,
    failure_reason = $3,
    settled_at = $4
WHERE id = $1;

-- CountRecentTransfersBySender counts transfers from one sender inside
-- a trailing time window, short-circuiting at $3 so velocity rules
-- stop scanning at threshold+1. Drives the fraud scorer's 1m and 1h
-- velocity rules; the caller passes the window as a Postgres interval
-- text (e.g. '60 seconds', '1 hour').
--
-- name: CountRecentTransfersBySender :one
SELECT COUNT(*)::BIGINT AS count FROM (
    SELECT 1 FROM transfers
    WHERE sender_user_id = $1
      AND created_at >= now() - $2::interval
    LIMIT $3
) t;

-- ExistsTransferBetween returns whether this sender has ever transferred
-- to this receiver before. Powers the novel-receiver fraud rule.
--
-- name: ExistsTransferBetween :one
SELECT EXISTS (
    SELECT 1 FROM transfers
    WHERE sender_user_id = $1 AND receiver_user_id = $2
    LIMIT 1
) AS exists;

-- SumSenderTransfersToday totals kobo spent today (Africa/Lagos) on
-- in-flight or settled transfers for one sender. Drives the high-daily-
-- share fraud rule.
--
-- name: SumSenderTransfersToday :one
SELECT COALESCE(SUM(amount_kobo), 0)::BIGINT AS total_kobo
FROM transfers
WHERE sender_user_id = $1
  AND status IN ('ACCEPTED','PROCESSING','SETTLED')
  AND created_at >= date_trunc('day', now() AT TIME ZONE 'Africa/Lagos');

-- MarkTransferSettled + MarkTransferFailed are the terminal status
-- setters used by the transfer processor. Named queries (rather than
-- parameterised UpdateTransferStatus calls) keep processor code free
-- of inline SQL.
--
-- name: MarkTransferSettled :exec
UPDATE transfers
SET status = 'SETTLED',
    failure_reason = NULL,
    settled_at = now()
WHERE id = $1;

-- name: MarkTransferFailed :exec
UPDATE transfers
SET status = 'FAILED',
    failure_reason = $2,
    settled_at = now()
WHERE id = $1;
