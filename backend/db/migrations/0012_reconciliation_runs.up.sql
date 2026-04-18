-- Reconciliation run history: payer, merchant, and ledger sweeps.

CREATE TYPE reconciliation_type AS ENUM ('PAYER', 'MERCHANT', 'LEDGER');
CREATE TYPE reconciliation_status AS ENUM ('CLEAN', 'DISCREPANCY', 'IN_PROGRESS');

CREATE TABLE reconciliation_runs (
    id             TEXT PRIMARY KEY,
    type           reconciliation_type NOT NULL,
    entity_id      TEXT NOT NULL,
    run_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    status         reconciliation_status NOT NULL DEFAULT 'IN_PROGRESS',
    discrepancies  JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_recon_type_runat ON reconciliation_runs (type, run_at DESC);
