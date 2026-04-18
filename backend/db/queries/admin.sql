-- Admin user + role queries for the backoffice. admin_users is the
-- internal-staff identity table — distinct from the end-user `users`
-- table and its auth surface in user_auth.sql. Session and audit
-- queries live in admin_sessions.sql / admin_audit.sql respectively.

-- CreateAdminUser inserts a bcrypt-hashed admin user. Role grants are
-- applied separately via GrantAdminRoleByName so the admin-create
-- service can iterate over a caller-supplied role slice.
--
-- name: CreateAdminUser :exec
INSERT INTO admin_users (id, email, full_name, password_hash)
VALUES ($1, $2, $3, $4);

-- GrantAdminRoleByName binds one role to an admin user by role name.
-- A non-existent role name silently no-ops — the inner SELECT returns
-- zero rows and the INSERT inserts zero.
--
-- name: GrantAdminRoleByName :exec
INSERT INTO admin_user_roles (admin_user_id, role_id)
SELECT $1, id FROM admin_roles WHERE name = $2;

-- GetAdminUserByID returns the public-facing admin profile. Used after
-- create, and after refresh to reload the session's admin context.
--
-- name: GetAdminUserByID :one
SELECT id, email, full_name, status, created_at
FROM admin_users
WHERE id = $1;

-- GetAdminUserForLogin returns the login-path projection: the public
-- profile fields plus password_hash so the service bcrypt-checks in
-- one round trip.
--
-- name: GetAdminUserForLogin :one
SELECT id, email, full_name, status, created_at, password_hash
FROM admin_users
WHERE email = $1;

-- TouchAdminUserLastLogin stamps a successful login. Best-effort: the
-- service intentionally ignores errors so login never fails on this.
--
-- name: TouchAdminUserLastLogin :exec
UPDATE admin_users
SET last_login_at = now()
WHERE id = $1;

-- ListAdminRoleNamesForUser returns the caller's role names, alpha
-- sorted. Feeds both Login and Refresh so the issued JWT carries the
-- current role set.
--
-- name: ListAdminRoleNamesForUser :many
SELECT r.name
FROM admin_roles r
JOIN admin_user_roles ur ON ur.role_id = r.id
WHERE ur.admin_user_id = $1
ORDER BY r.name;
