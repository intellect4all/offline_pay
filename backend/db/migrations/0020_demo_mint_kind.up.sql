-- Demo-funding feature (part 1 of 2). Adds DEMO_MINT to transaction_kind
-- so the demo-mint service can record user-facing history rows for
-- top-ups sourced from the Test Bank treasury.
--
-- PostgreSQL disallows using a freshly-added enum value in the same
-- transaction that introduced it; the treasury seed in the next
-- migration needs this value to be committed first.

ALTER TYPE transaction_kind ADD VALUE IF NOT EXISTS 'DEMO_MINT';
