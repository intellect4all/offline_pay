-- Ceiling recovery feature (part 2 of 2). Broaden "one live ceiling per
-- user" to cover both ACTIVE and RECOVERY_PENDING rows so a user can't
-- accidentally double-fund while a recovery is in flight, and add the
-- sweep index for the background release job.

DROP INDEX IF EXISTS uq_ceiling_one_active_per_user;

CREATE UNIQUE INDEX uq_ceiling_one_live_per_user
    ON ceiling_tokens (payer_user_id)
    WHERE status IN ('ACTIVE', 'RECOVERY_PENDING');

CREATE INDEX IF NOT EXISTS idx_ceiling_recovery_sweep
    ON ceiling_tokens (status, release_after)
    WHERE status = 'RECOVERY_PENDING';
