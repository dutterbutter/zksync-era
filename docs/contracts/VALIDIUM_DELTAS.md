# Validium Mode Deltas

This document describes the differences between **Rollup** and **Validium** modes for ZK Stack chain deployment.

## Overview

- **Rollup mode**: Posts full transaction data to L1 (via calldata or blobs), ensuring L1 data availability
- **Validium mode**: Posts only commitment hashes to L1, storing full data off-chain (requires external DA layer)

## Contract Differences

### L1 Contracts

| Contract | Rollup | Validium | Notes |
|----------|--------|----------|-------|
| **L1 DA Validator** | `RollupL1DAValidator` | `ValidiumL1DAValidator` | Validates data availability proofs |
| **L1 DA Manager** | `RollupL1DAManager` | Not deployed | Rollup mode manages DA commitments on-chain |
| **Expected DA Validator** | Populated in ecosystem config | Populated in ecosystem config | Used as default for new chains |

**Addresses from deployment**:
- Rollup: `deployed_addresses.rollup_l1_da_validator_addr`
- Validium: `deployed_addresses.no_da_validium_l1_validator_addr`
- (Also available: `avail_l1_da_validator_addr` for Avail DA integration)

### L2 Contracts

| Contract | Rollup | Validium | Notes |
|----------|--------|----------|-------|
| **L2 DA Validator** | Rollup L2 DA Validator | Validium L2 DA Validator | Deployed as part of L2 genesis |

Both are predeployed at genesis but have different implementations.

## Deployment Manifest Deltas

### Deploy Phase

In `deploy-manifest.yaml`, the following steps differ:

1. **rollup_da_validator_deploy**: Only deployed in rollup mode
2. **validium_da_validator_deploy**: Only deployed in validium mode
3. **rollup_da_manager_deploy**: Only deployed in rollup mode

Example deployment step (rollup-specific):

```yaml
- id: rollup_da_validator_deploy
  from_role: deployer
  to: "<create2_factory>"
  method: "create2(bytes32,bytes)"
  params:
    salt: "<create2_salt_rollup_da_validator>"
    bytecode: "<rollup_da_validator_bytecode>"
  deployment: create2
  depends_on: [create2_factory_deploy]
  idempotency_check: "code_at(<rollup_l1_da_validator_addr>) != 0x"
  postcondition: "code_at(<rollup_l1_da_validator_addr>) != 0x"
  notes: "Rollup L1 DA Validator (for rollup mode)"
  mode: rollup  # Only deploy if mode == rollup
```

Example deployment step (validium-specific):

```yaml
- id: validium_da_validator_deploy
  from_role: deployer
  to: "<create2_factory>"
  method: "create2(bytes32,bytes)"
  params:
    salt: "<create2_salt_validium_da_validator>"
    bytecode: "<validium_da_validator_bytecode>"
  deployment: create2
  depends_on: [create2_factory_deploy]
  idempotency_check: "code_at(<no_da_validium_l1_validator_addr>) != 0x"
  postcondition: "code_at(<no_da_validium_l1_validator_addr>) != 0x"
  notes: "Validium L1 DA Validator (for validium mode)"
  mode: validium  # Only deploy if mode == validium
```

## Initialization Manifest Deltas

### Chain Configuration

In `init-manifest.yaml`, the `register_zk_chain` step differs:

**Rollup mode**:
```yaml
- id: register_zk_chain
  # ... (other fields)
  params:
    # ...
    validium_mode: false  # Rollup mode
  # ...
```

**Validium mode**:
```yaml
- id: register_zk_chain
  # ... (other fields)
  params:
    # ...
    validium_mode: true  # Validium mode
  # ...
```

### DA Validator Pair Configuration

The `set_da_validator_pair` step uses different validator addresses:

**Rollup mode**:
```yaml
- id: set_da_validator_pair
  # ...
  params:
    # ...
    - "<rollup_l1_da_validator_addr>"  # L1 DA Validator
    - "<rollup_l2_da_validator_addr>"  # L2 DA Validator
    # ...
```

**Validium mode**:
```yaml
- id: set_da_validator_pair
  # ...
  params:
    # ...
    - "<validium_l1_da_validator_addr>"  # L1 DA Validator
    - "<validium_l2_da_validator_addr>"  # L2 DA Validator
    # ...
```

## Configuration File Deltas

### Chain Config (`chains/<chain-name>/ZkStack.yaml`)

```yaml
# Rollup mode
l1_batch_commit_data_generator_mode: Rollup

# Validium mode
l1_batch_commit_data_generator_mode: Validium
```

### Contracts Config (`chains/<chain-name>/configs/contracts.yaml`)

The deployed DA validator addresses differ:

**Rollup mode**:
```yaml
ecosystem_contracts:
  expected_rollup_l2_da_validator: "<rollup_l2_da_validator_addr>"
```

**Validium mode**:
```yaml
ecosystem_contracts:
  expected_rollup_l2_da_validator: "<validium_l2_da_validator_addr>"
```

(Note: The field name remains `expected_rollup_l2_da_validator` for historical reasons, but it contains the validium validator in validium mode)

## Operational Deltas

### Batch Commitment (L2 -> L1)

**Rollup mode**:
- Sequencer commits batches with **full transaction data** to L1
- Data posted via:
  - EIP-4844 blobs (preferred, cheaper)
  - Or calldata (fallback, more expensive)
- L1 DA Validator verifies blob/calldata availability

**Validium mode**:
- Sequencer commits batches with **only commitment hash** to L1
- Full transaction data stored off-chain (external DA layer)
- L1 DA Validator verifies off-chain DA proof

### Cost Implications

| Aspect | Rollup | Validium |
|--------|--------|----------|
| **L1 gas cost per batch** | High (data posting) | Low (only hash) |
| **L1 data availability** | Guaranteed by L1 | Depends on external DA |
| **Security assumptions** | L1-secured | DA layer security |
| **Censorship resistance** | L1-level | DA layer-level |

## Validation Deltas

### DA Validator Verification

**Rollup mode**:
```bash
# Verify L1 DA Validator
cast call $DIAMOND_PROXY_ADDR "getDAValidatorPair()(address,address)" --rpc-url $L1_RPC_URL
# Expected: (<rollup_l1_da_validator_addr>, <rollup_l2_da_validator_addr>)
```

**Validium mode**:
```bash
# Verify L1 DA Validator
cast call $DIAMOND_PROXY_ADDR "getDAValidatorPair()(address,address)" --rpc-url $L1_RPC_URL
# Expected: (<validium_l1_da_validator_addr>, <validium_l2_da_validator_addr>)
```

### Batch Commitment Verification

**Rollup mode**:
```bash
# Verify batch data is available on L1 (via blobs or calldata)
cast tx $COMMIT_TX_HASH --rpc-url $L1_RPC_URL
# Check for blob versioned hashes or calldata
```

**Validium mode**:
```bash
# Verify only commitment hash is posted to L1
cast tx $COMMIT_TX_HASH --rpc-url $L1_RPC_URL
# Check transaction contains only hash, no full data
```

## Migration Between Modes

**Rollup -> Validium**:
- Deploy validium L1 DA Validator
- Deploy validium L2 DA Validator
- Call `setDAValidatorPair` with validium addresses
- Update chain config to `Validium` mode
- Restart sequencer

**Validium -> Rollup**:
- Deploy rollup L1 DA Validator (if not already deployed)
- Deploy rollup L2 DA Validator
- Call `setDAValidatorPair` with rollup addresses
- Update chain config to `Rollup` mode
- Restart sequencer

⚠️ **Warning**: Switching modes should be done carefully with proper governance and sequencer coordination.

## External DA Integration (e.g., Avail)

For validium mode with external DA providers (e.g., Avail):

1. Deploy provider-specific L1 DA Validator:
   - `AvailL1DAValidator` deployed at `deployed_addresses.avail_l1_da_validator_addr`

2. Configure chain to use Avail DA:
   ```yaml
   # In chain config
   da_provider: Avail
   avail_config:
     # Avail-specific configuration
   ```

3. Set DA validator pair to use Avail validator:
   ```bash
   zkstack chain set-da-validator-pair \
     --l1-da-validator $AVAIL_L1_DA_VALIDATOR_ADDR
   ```

## TODO: Areas Requiring Further Documentation

- [ ] Document Avail DA integration in detail
- [ ] Document how to switch DA providers (Avail, Celestia, etc.)
- [ ] Document DA validator upgrade process
- [ ] Document fallback mechanisms if external DA is unavailable
- [ ] Document how to verify off-chain DA availability
- [ ] Add validation scripts for validium-specific checks

## References

- **DA Validator Contracts**: `l1-contracts/contracts/state-transition/data-availability/`
- **Chain Config**: `zkstack_cli/crates/config/src/chain.rs`
- **L1 Batch Commitment Mode**: `zkstack_cli/crates/types/src/l1_batch_commit_data_generator_mode.rs`
