-- End-user auth surface: refresh sessions and OTP challenges.
--
-- Signup is password-based; OTP is used for email verification at signup
-- and for password-reset flows. `identifier` is the generic channel key
-- (email today, potentially SMS later) so future auth channels can reuse
-- the same table without another schema shift.

CREATE TABLE user_sessions (
    id            TEXT PRIMARY KEY,
    user_id       TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    refresh_hash  TEXT NOT NULL UNIQUE,
    user_agent    TEXT NOT NULL DEFAULT '',
    ip            TEXT NOT NULL DEFAULT '',
    device_id     TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at    TIMESTAMPTZ NOT NULL,
    revoked_at    TIMESTAMPTZ
);
CREATE INDEX idx_user_sessions_user ON user_sessions (user_id);

CREATE TABLE otp_challenges (
    identifier   TEXT NOT NULL,
    code_hash    TEXT NOT NULL,
    purpose      TEXT NOT NULL CHECK (purpose IN ('signup_email_verify', 'password_reset')),
    attempts     INTEGER NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at   TIMESTAMPTZ NOT NULL,
    consumed_at  TIMESTAMPTZ,
    PRIMARY KEY (identifier, purpose)
);
CREATE INDEX idx_otp_challenges_expires_at ON otp_challenges (expires_at);
