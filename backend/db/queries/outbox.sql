-- Transactional outbox for async event dispatch. Writes land in the
-- same tx as the aggregate mutation; the dispatcher picks rows up
-- with Claim → Mark (on success) / BumpAttempt (on retry) so at-least-
-- once delivery is preserved across crashes.

-- name: InsertOutboxEntry :exec
INSERT INTO outbox (id, aggregate, aggregate_id, payload)
VALUES ($1, $2, $3, $4);

-- ClaimOutboxBatch pulls up to $1 ready-to-dispatch rows and locks
-- them so competing dispatchers don't double-process. SKIP LOCKED lets
-- the dispatcher fan out horizontally without explicit coordination.
--
-- name: ClaimOutboxBatch :many
SELECT id, aggregate, aggregate_id, payload, attempts
FROM outbox
WHERE dispatched_at IS NULL AND next_attempt_at <= now()
ORDER BY created_at
LIMIT $1
FOR UPDATE SKIP LOCKED;

-- name: MarkOutboxDispatched :exec
UPDATE outbox SET dispatched_at = now() WHERE id = $1;

-- name: BumpOutboxAttempt :exec
UPDATE outbox
SET attempts = attempts + 1,
    next_attempt_at = $2
WHERE id = $1;
