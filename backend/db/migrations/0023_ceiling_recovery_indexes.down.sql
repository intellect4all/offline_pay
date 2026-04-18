DROP INDEX IF EXISTS idx_ceiling_recovery_sweep;
DROP INDEX IF EXISTS uq_ceiling_one_live_per_user;

CREATE UNIQUE INDEX uq_ceiling_one_active_per_user
    ON ceiling_tokens (payer_user_id)
    WHERE status = 'ACTIVE';
