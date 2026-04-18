-- KYC submissions + history reads. Tier promotion itself mutates the
-- users table and lives in users.sql (PromoteUserToTier).

-- InsertKYCSubmission records one submission. Status is caller-
-- computed ('VERIFIED' or 'REJECTED'); the column's check constraint
-- rejects stray values.
--
-- name: InsertKYCSubmission :exec
INSERT INTO kyc_submissions
    (id, user_id, id_type, id_number, status, rejection_reason,
     tier_granted, submitted_by, verified_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9);

-- GetKYCSubmissionSubmittedAt reads back the DB-assigned default
-- timestamp post-insert so the caller's returned struct reflects the
-- server clock rather than a client-supplied value.
--
-- name: GetKYCSubmissionSubmittedAt :one
SELECT submitted_at FROM kyc_submissions WHERE id = $1;

-- ListKYCSubmissionsByUser powers the per-user KYC history view.
--
-- name: ListKYCSubmissionsByUser :many
SELECT id, user_id, id_type, id_number, status, rejection_reason,
       tier_granted, submitted_by, submitted_at, verified_at
FROM kyc_submissions
WHERE user_id = $1
ORDER BY submitted_at DESC;
