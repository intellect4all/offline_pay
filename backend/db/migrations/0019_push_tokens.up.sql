-- FCM push token registry. One row per token; upsert on register so the
-- same token on a new user reassigns ownership; delete on logout. No
-- preferences, no delivery tracking — keep the surface minimal.

CREATE TABLE push_tokens (
    fcm_token   TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    platform    TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_push_tokens_user ON push_tokens (user_id);
