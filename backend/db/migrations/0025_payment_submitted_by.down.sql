DROP INDEX IF EXISTS idx_payment_submitted_by;
ALTER TABLE payment_tokens DROP COLUMN IF EXISTS submitted_by_user_id;
