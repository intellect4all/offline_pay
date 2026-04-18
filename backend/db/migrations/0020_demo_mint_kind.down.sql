-- PostgreSQL does not support removing an enum value cleanly (dropping
-- requires rebuilding the type and every dependent column). This down
-- is intentionally a no-op; rolling back the seed data in the next
-- migration's down is sufficient for all practical purposes.

SELECT 1;
