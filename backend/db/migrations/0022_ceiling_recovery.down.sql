-- Undo the recovery enum + column. Postgres can't drop an enum value
-- in-place, so we recreate ceiling_status without RECOVERY_PENDING.
-- Any rows in that intermediate state must be resolved (released or
-- restored) before this migration runs — otherwise the ALTER type
-- cast fails, which is the safer default.
--
-- The partial unique index carries a `status = 'ACTIVE'` predicate
-- whose literal is bound to the enum type; Postgres will refuse the
-- column-type ALTER while it exists, so we drop it first and let the
-- matching up migration in this module (0023_ceiling_recovery_indexes
-- down) recreate the ACTIVE-only form. The idx_ceiling_payer_status
-- b-tree has no predicate and survives the type swap.
--
-- transaction_kind's new value OFFLINE_RECOVERY_RELEASE is left in
-- place as harmless dead weight. Recreating that enum would require
-- dropping every FK/CHECK that references it for no real benefit.

DROP INDEX IF EXISTS uq_ceiling_one_active_per_user;

ALTER TABLE ceiling_tokens ALTER COLUMN status DROP DEFAULT;
ALTER TABLE ceiling_tokens
    ALTER COLUMN status TYPE TEXT USING status::text;

DROP TYPE IF EXISTS ceiling_status;
CREATE TYPE ceiling_status AS ENUM ('ACTIVE', 'EXPIRED', 'EXHAUSTED', 'REVOKED');

ALTER TABLE ceiling_tokens
    ALTER COLUMN status TYPE ceiling_status USING status::ceiling_status;
ALTER TABLE ceiling_tokens ALTER COLUMN status SET DEFAULT 'ACTIVE';

CREATE UNIQUE INDEX uq_ceiling_one_active_per_user
    ON ceiling_tokens (payer_user_id)
    WHERE status = 'ACTIVE';

ALTER TABLE ceiling_tokens DROP COLUMN IF EXISTS release_after;
