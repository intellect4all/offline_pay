-- AES-256 realm keys (Layer 1 QR encryption). One row per version; QR
-- payloads carry a 1-byte version selector. Rotation inserts a new
-- highest-version row and retires the prior one with an overlap window.

CREATE TABLE realm_keys (
    version      INTEGER PRIMARY KEY,
    key_enc      BYTEA NOT NULL,
    active_from  TIMESTAMPTZ NOT NULL DEFAULT now(),
    retired_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_realm_keys_active
    ON realm_keys (active_from)
    WHERE retired_at IS NULL;
