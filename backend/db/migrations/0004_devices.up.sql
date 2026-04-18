-- One active device per user. Attestation fields capture the platform
-- and the most recent successful verification timestamp; both nullable
-- so dev-mode registrations work without real attestation.

CREATE TABLE devices (
    id                       TEXT PRIMARY KEY,
    user_id                  TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    attestation_blob         BYTEA NOT NULL,
    public_key               BYTEA,
    active                   BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at             TIMESTAMPTZ,
    attestation_platform     TEXT,
    attestation_verified_at  TIMESTAMPTZ,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_device_one_active_per_user
    ON devices (user_id)
    WHERE active = TRUE;
