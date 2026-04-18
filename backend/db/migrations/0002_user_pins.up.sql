-- Per-user transaction PIN. Bcrypt-hashed. Separate table (not columns on
-- users) so credential rotation history can be added later without a
-- destructive migration, and so the auth-credential surface is isolated
-- from identity columns.
--
-- `attempts` tracks consecutive wrong-PIN attempts and resets on success.
-- `locked_at` stamps the most recent lockout; a non-null value within the
-- last 15 minutes is considered "locked" by the BFF.

CREATE TABLE user_pins (
    user_id    TEXT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    pin_hash   TEXT NOT NULL,
    attempts   INTEGER NOT NULL DEFAULT 0,
    locked_at  TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
