DELETE FROM ledger_entries WHERE txn_id = '01HGENES1S0000000000000MINT';
DELETE FROM transactions   WHERE id     = '01HGENES1S0000000000000MINT';
DELETE FROM accounts       WHERE user_id = 'system-mint';
DELETE FROM users          WHERE id     = 'system-mint';
