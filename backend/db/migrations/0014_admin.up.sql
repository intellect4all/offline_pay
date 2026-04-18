-- Backoffice dashboard: admin users, RBAC, refresh sessions, audit log.
-- Separate from the end-user `users` table — these are internal staff
-- accounts.

CREATE TABLE admin_users (
    id              TEXT PRIMARY KEY,
    email           TEXT NOT NULL UNIQUE,
    full_name       TEXT NOT NULL DEFAULT '',
    password_hash   TEXT NOT NULL,
    totp_secret     TEXT,
    totp_enrolled   BOOLEAN NOT NULL DEFAULT FALSE,
    status          TEXT NOT NULL DEFAULT 'ACTIVE',
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE admin_roles (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO admin_roles (id, name, description) VALUES
    ('role_viewer',      'VIEWER',      'Read-only access to dashboard'),
    ('role_support',     'SUPPORT',     'User lookups, KYC view, device view'),
    ('role_finance',     'FINANCE_OPS', 'Settlement actions, reconciliation'),
    ('role_fraud',       'FRAUD_OPS',   'Device suspend, ceiling revoke'),
    ('role_superadmin',  'SUPERADMIN',  'Full access incl. admin user management');

CREATE TABLE admin_user_roles (
    admin_user_id TEXT NOT NULL REFERENCES admin_users (id) ON DELETE CASCADE,
    role_id       TEXT NOT NULL REFERENCES admin_roles (id) ON DELETE CASCADE,
    granted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (admin_user_id, role_id)
);

-- Refresh session: one row per active refresh token. Rotation inserts a
-- new row and marks the prior one revoked_at.
CREATE TABLE admin_sessions (
    id              TEXT PRIMARY KEY,
    admin_user_id   TEXT NOT NULL REFERENCES admin_users (id) ON DELETE CASCADE,
    refresh_hash    TEXT NOT NULL UNIQUE,
    user_agent      TEXT NOT NULL DEFAULT '',
    ip              TEXT NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ
);
CREATE INDEX idx_admin_sessions_user ON admin_sessions (admin_user_id);

CREATE TABLE admin_audit_log (
    id             BIGSERIAL PRIMARY KEY,
    admin_user_id  TEXT REFERENCES admin_users (id) ON DELETE SET NULL,
    admin_email    TEXT NOT NULL DEFAULT '',
    action         TEXT NOT NULL,
    target_type    TEXT NOT NULL DEFAULT '',
    target_id      TEXT NOT NULL DEFAULT '',
    payload        JSONB,
    ip             TEXT NOT NULL DEFAULT '',
    user_agent     TEXT NOT NULL DEFAULT '',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_admin_audit_created_at ON admin_audit_log (created_at DESC);
CREATE INDEX idx_admin_audit_actor ON admin_audit_log (admin_user_id);
