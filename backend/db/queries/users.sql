-- End-user CRUD and narrow projections. Each fetch variant returns
-- exactly the columns its caller renders — SELECT * is reserved for the
-- generic GetUser path. Narrow projections keep the row cache hot on
-- the latency-sensitive auth + transfer-accept flows.

-- name: CreateUser :one
INSERT INTO users (id, phone, account_number, bvn, kyc_tier, device_attestation_id,
                   realm_key_version, first_name, last_name, email, password_hash)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
RETURNING *;

-- name: GetUser :one
SELECT * FROM users WHERE id = $1;

-- name: GetUserByPhone :one
SELECT * FROM users WHERE phone = $1;

-- GetUserByEmail locates a user by registered email (case-insensitive).
-- Used by the password-reset flow to issue a reset code.
--
-- name: GetUserByEmail :one
SELECT * FROM users WHERE lower(email) = lower($1);

-- name: UpdateUserKYC :exec
UPDATE users SET kyc_tier = $2, updated_at = now() WHERE id = $1;

-- GetUserAccountNumber fetches just the 10-digit account number.
-- Used by the refresh flow which already has a user id and needs the
-- account number to mint the next access token.
--
-- name: GetUserAccountNumber :one
SELECT account_number FROM users WHERE id = $1;

-- GetUserIDAndAccountNumberByPhone is the login-path lookup: normalise
-- the phone, then fetch id + account_number for session creation.
--
-- name: GetUserIDAndAccountNumberByPhone :one
SELECT id, account_number FROM users WHERE phone = $1;

-- GetUserLoginByPhone returns the password-login projection: id,
-- account_number, password_hash. Bundled so the login hot path
-- bcrypt-checks in a single round trip.
--
-- name: GetUserLoginByPhone :one
SELECT id, account_number, password_hash FROM users WHERE phone = $1;

-- GetUserPhoneAndTier returns the fields the KYC flow needs to decide
-- whether to promote: the phone (to compute the expected mock id) and
-- the current tier (so only strictly-higher promotions apply).
--
-- name: GetUserPhoneAndTier :one
SELECT phone, kyc_tier FROM users WHERE id = $1;

-- GetUserPhoneByID powers KYCHint; narrow projection keeps it
-- independent from GetUser even when the full row shape changes.
--
-- name: GetUserPhoneByID :one
SELECT phone FROM users WHERE id = $1;

-- GetUserIDByAccountNumber is the receiver-resolution step of the
-- transfer-accept flow.
--
-- name: GetUserIDByAccountNumber :one
SELECT id FROM users WHERE account_number = $1;

-- CheckAccountNumberExists powers /v1/accounts/resolve — returns the
-- account_number if the row exists so the caller can confirm a
-- receiver before committing to a transfer.
--
-- name: CheckAccountNumberExists :one
SELECT account_number FROM users WHERE account_number = $1;

-- GetUserKYCTier is the narrow tier lookup inside the transfer-accept
-- tx. Kept separate from GetUser so hot-path reads skip unused columns.
--
-- name: GetUserKYCTier :one
SELECT kyc_tier FROM users WHERE id = $1;

-- GetUserAccountAgeHours returns the sender's account age in hours
-- (EXTRACT yields a double; sqlc maps it to float64). Drives the
-- fraud scorer's new-account rule.
--
-- name: GetUserAccountAgeHours :one
SELECT (EXTRACT(EPOCH FROM now() - created_at) / 3600)::float8 AS age_hours
FROM users WHERE id = $1;

-- GetMeProjection is the /v1/me handler's narrow fetch — exactly the
-- profile fields the client renders.
--
-- name: GetMeProjection :one
SELECT id, phone, account_number, kyc_tier, first_name, last_name, email, email_verified
FROM users WHERE id = $1;

-- PromoteUserToTier moves the user to a new KYC tier, but only if the
-- target tier is strictly higher in the TIER_0..TIER_3 ordering. The
-- CASE guard makes the promotion idempotent and prevents a lower tier
-- from clobbering an already-granted higher one.
--
-- name: PromoteUserToTier :exec
UPDATE users
SET kyc_tier = $2, updated_at = now()
WHERE id = $1
  AND (
    CASE kyc_tier
      WHEN 'TIER_0' THEN 0
      WHEN 'TIER_1' THEN 1
      WHEN 'TIER_2' THEN 2
      WHEN 'TIER_3' THEN 3
      ELSE 0
    END
  ) < (
    CASE $2::text
      WHEN 'TIER_0' THEN 0
      WHEN 'TIER_1' THEN 1
      WHEN 'TIER_2' THEN 2
      WHEN 'TIER_3' THEN 3
      ELSE 0
    END
  );

-- MarkEmailVerified flips email_verified to true. Idempotent.
--
-- name: MarkEmailVerified :exec
UPDATE users SET email_verified = true, updated_at = now()
WHERE id = $1;

-- UpdateUserPassword replaces the bcrypt password hash. Used by the
-- forgot-password reset flow.
--
-- name: UpdateUserPassword :exec
UPDATE users SET password_hash = $2, updated_at = now()
WHERE id = $1;

-- ListUsersForAdmin returns one admin-projection page, newest first.
-- Shares its row shape with SearchUsersForAdminByPhone so scan adapters
-- can be reused across the listing and search paths.
--
-- name: ListUsersForAdmin :many
SELECT u.id,
       u.phone,
       u.kyc_tier,
       u.realm_key_version,
       u.created_at,
       COALESCE(am.balance_kobo, 0)::BIGINT AS main_balance_kobo,
       COALESCE(al.balance_kobo, 0)::BIGINT AS lien_balance_kobo,
       (SELECT MAX(last_seen_at) FROM devices d WHERE d.user_id = u.id)::timestamptz AS last_seen_at
FROM users u
LEFT JOIN accounts am ON am.user_id = u.id AND am.kind = 'main'
LEFT JOIN accounts al ON al.user_id = u.id AND al.kind = 'lien_holding'
ORDER BY u.created_at DESC
LIMIT $1 OFFSET $2;

-- SearchUsersForAdminByPhone matches phone or id against a lowercase
-- LIKE pattern (caller passes '%' + lower(q) + '%'). Column list
-- matches ListUsersForAdmin so the admin service layer shares scan
-- adapters.
--
-- name: SearchUsersForAdminByPhone :many
SELECT u.id,
       u.phone,
       u.kyc_tier,
       u.realm_key_version,
       u.created_at,
       COALESCE(am.balance_kobo, 0)::BIGINT AS main_balance_kobo,
       COALESCE(al.balance_kobo, 0)::BIGINT AS lien_balance_kobo,
       (SELECT MAX(last_seen_at) FROM devices d WHERE d.user_id = u.id)::timestamptz AS last_seen_at
FROM users u
LEFT JOIN accounts am ON am.user_id = u.id AND am.kind = 'main'
LEFT JOIN accounts al ON al.user_id = u.id AND al.kind = 'lien_holding'
WHERE lower(u.phone) LIKE $1 OR lower(u.id) LIKE $1
ORDER BY u.created_at DESC
LIMIT $2 OFFSET $3;

-- name: CountUsers :one
SELECT COUNT(*)::BIGINT AS total FROM users;

-- name: CountUsersByPhone :one
SELECT COUNT(*)::BIGINT AS total FROM users
WHERE lower(phone) LIKE $1 OR lower(id) LIKE $1;

-- CreateUserWithAccountNumber is the signup-path insert. Stores the
-- minimum identity + credential set (names, email, password_hash)
-- alongside phone + account_number. kyc_tier is caller-supplied so
-- tests can seed arbitrary tiers without hitting the promotion path.
--
-- name: CreateUserWithAccountNumber :one
INSERT INTO users (id, phone, account_number, kyc_tier, realm_key_version,
                   first_name, last_name, email, password_hash)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
RETURNING id, phone, account_number, kyc_tier, realm_key_version,
          first_name, last_name, email, email_verified,
          created_at, updated_at;

-- name: GetUserByAccountNumber :one
SELECT id, phone, account_number, kyc_tier, realm_key_version, created_at, updated_at
FROM users WHERE account_number = $1;

-- GetUserNameByAccountNumber powers the demo-mint name-enquiry step:
-- given a 10-digit account number, return the holder's names so the
-- frontend can confirm the recipient before funding. System accounts
-- (kyc_tier='SYSTEM') are excluded so treasury owners never appear as
-- valid recipients.
--
-- name: GetUserNameByAccountNumber :one
SELECT id, first_name, last_name, account_number
FROM users
WHERE account_number = $1 AND kyc_tier <> 'SYSTEM';

-- GetUserDisplayNamesByIDs batches the display-name join used by
-- activity feeds so the UI shows "Jane Doe" rather than a raw user id.
-- Returns one row per matching id; callers tolerate arbitrary
-- ordering and hash rows by id.
--
-- name: GetUserDisplayNamesByIDs :many
SELECT id, first_name, last_name
FROM users
WHERE id = ANY($1::text[]);
