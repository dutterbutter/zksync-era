ALTER TABLE l1_batches
    ADD COLUMN batch_chain_global_merkle_path BYTEA;

ALTER TABLE miniblocks
    ADD COLUMN message_roots_assigned BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE eth_txs_history
    ADD COLUMN confirmed_at_block INTEGER;

-- postgres doesn't allow dropping enum variant, so nothing is done in down.sql
ALTER TYPE event_type ADD VALUE 'MessageRoot';
