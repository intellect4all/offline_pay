DROP INDEX IF EXISTS idx_payment_session_nonce;

ALTER TABLE payment_tokens
    DROP COLUMN IF EXISTS session_nonce,
    DROP COLUMN IF EXISTS request_hash,
    DROP COLUMN IF EXISTS request_amount_kobo;
