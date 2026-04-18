-- Mock KYC1 flow. id_number is validated against a deterministic pattern
-- derived from the user's phone (see internal/service/admin/kyc.go).

CREATE TABLE kyc_submissions (
    id                TEXT PRIMARY KEY,
    user_id           TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    id_type           TEXT NOT NULL CHECK (id_type IN ('BVN', 'NIN')),
    id_number         TEXT NOT NULL,
    status            TEXT NOT NULL CHECK (status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    rejection_reason  TEXT,
    tier_granted      TEXT,
    submitted_by      TEXT,
    submitted_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    verified_at       TIMESTAMPTZ
);

CREATE INDEX idx_kyc_submissions_user ON kyc_submissions (user_id, submitted_at DESC);
