-- Submitter attribution. Either the payer or the payee device may upload
-- a claim once it reaches connectivity — whichever is online first drains
-- its QUEUED rows. `submitted_by_user_id` records which party actually
-- uploaded the token so auditors can trace provenance (e.g. "this claim
-- was submitted by the payer's device at T+12s; the payee's batch
-- arrived later and deduped").

ALTER TABLE payment_tokens
    ADD COLUMN submitted_by_user_id TEXT REFERENCES users (id);

CREATE INDEX idx_payment_submitted_by ON payment_tokens (submitted_by_user_id);
