-- Admin audit log. The service's Audit() helper is best-effort — the
-- insert returns nothing and errors are logged, not surfaced. The
-- list/count pair powers the backoffice audit page.

-- InsertAdminAuditLog appends one audit row. `payload` is JSONB;
-- callers pre-marshal to []byte before invoking.
--
-- name: InsertAdminAuditLog :exec
INSERT INTO admin_audit_log
    (admin_user_id, admin_email, action, target_type, target_id, payload, ip, user_agent)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8);

-- name: CountAdminAuditLog :one
SELECT COUNT(*)::BIGINT AS total FROM admin_audit_log;

-- name: ListAdminAuditLog :many
SELECT id, admin_email, action, target_type, target_id, ip, created_at
FROM admin_audit_log
ORDER BY id DESC
LIMIT $1 OFFSET $2;
