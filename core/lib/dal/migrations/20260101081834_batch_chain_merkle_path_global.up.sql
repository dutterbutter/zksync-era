ALTER TABLE l1_batches
    ADD COLUMN batch_chain_global_merkle_path BYTEA;

ALTER TABLE l1_batches
    ADD COLUMN batch_chain_local_merkle_path BYTEA;

ALTER TABLE miniblocks
    ADD COLUMN interop_roots_assigned BOOLEAN NOT NULL DEFAULT FALSE;

-- postgres doesn't allow dropping enum variant, so nothing is done in down.sql
ALTER TYPE event_type ADD VALUE 'InteropRoot';
