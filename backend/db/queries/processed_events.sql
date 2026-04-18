-- Idempotency table for outbox event processing. The processor writes
-- one row per handled event; the check-before-apply step makes handler
-- execution at-most-once even under dispatcher retries.

-- name: MarkEventProcessed :exec
INSERT INTO processed_events (outbox_id, status)
VALUES ($1, $2)
ON CONFLICT (outbox_id) DO NOTHING;

-- name: IsEventProcessed :one
SELECT EXISTS (SELECT 1 FROM processed_events WHERE outbox_id = $1) AS exists;
