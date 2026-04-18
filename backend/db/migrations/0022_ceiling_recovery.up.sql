-- Ceiling recovery feature (part 1 of 2). Adds the "lost ceiling token
-- on device" recovery flow (see docs/OFFLINE_AUTH.md and docs/PROTOCOL.md
-- — "Recovery" section).
--
-- Shape:
--
--   * RECOVERY_PENDING is a middle state between ACTIVE and terminal
--     (REVOKED). The lien stays locked; new payments can no longer be
--     signed by the device (the user explicitly triggered recovery),
--     but already-signed payments being carried offline by merchants
--     must still land safely. The sweep releases the remaining lien
--     once release_after has passed.
--
--   * release_after is populated only for RECOVERY_PENDING rows.
--     `expires_at + auto_settle_timeout + grace` — after this point,
--     any claim that could have been carried by a merchant has had
--     long enough to propagate and settle.
--
-- The matching index swap lives in the next migration: PostgreSQL forbids
-- referencing a freshly-added enum value inside the same transaction
-- that added it.

ALTER TYPE ceiling_status ADD VALUE IF NOT EXISTS 'RECOVERY_PENDING' AFTER 'ACTIVE';

-- Extend the business-event enum so the sweep can tag its ledger rows
-- with a recovery-specific kind instead of reusing OFFLINE_DRAIN /
-- OFFLINE_EXPIRY_RELEASE (which would confuse the admin activity feed).
ALTER TYPE transaction_kind ADD VALUE IF NOT EXISTS 'OFFLINE_RECOVERY_RELEASE';

ALTER TABLE ceiling_tokens
    ADD COLUMN IF NOT EXISTS release_after TIMESTAMPTZ;
