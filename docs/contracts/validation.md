# ZK Stack Deployment Validation Runbook

This document provides detailed instructions for validating a ZK Stack chain deployment, checking preconditions, verifying idempotency, and confirming the health of the deployed system.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Precondition Checks](#precondition-checks)
3. [Deployment Validation](#deployment-validation)
4. [Initialization Validation](#initialization-validation)
5. [Idempotency Testing](#idempotency-testing)
6. [Role Mapping Verification](#role-mapping-verification)
7. [Healthy End-State Checklist](#healthy-end-state-checklist)
8. [Common Issues and Troubleshooting](#common-issues-and-troubleshooting)

---

## Prerequisites

Before validating a deployment, ensure you have:

- Access to an Ethereum RPC endpoint (L1)
- Access to the ZK Stack chain RPC endpoint (L2, if running)
- `cast` (Foundry CLI tool) installed
- The following configuration files:
  - `configs/wallets.yaml` (wallet addresses and private keys)
  - `configs/contracts.yaml` (deployed contract addresses)
  - `chains/<chain-name>/configs/contracts.yaml` (chain-specific contracts)
  - `configs/initial_deployments.yaml` (deployment parameters)

---

## Precondition Checks

### 1. Verify L1 Network Connectivity

```bash
# Check L1 block number
cast block-number --rpc-url $L1_RPC_URL

# Verify deployer has sufficient ETH balance (minimum 5 ETH recommended for localhost)
cast balance $DEPLOYER_ADDRESS --rpc-url $L1_RPC_URL
```

**Expected**: Block number returns successfully, deployer has >5 ETH.

### 2. Verify Wallet Configuration

```bash
# Check that all required wallets are configured
cat configs/wallets.yaml

# Verify governor address
grep "governor:" configs/wallets.yaml

# Verify operator addresses
grep "operator:" configs/wallets.yaml
grep "blob_operator:" configs/wallets.yaml
```

**Expected**: All required wallet roles are present with valid addresses and private keys.

### 3. Check Initial Deployment Parameters

```bash
# Verify initial_deployments.yaml exists and contains required params
cat configs/initial_deployments.yaml
```

**Expected**: File contains `create2_factory_salt`, `governance_min_delay`, `validator_timelock_execution_delay`, etc.

---

## Deployment Validation

### 1. Verify Contract Deployments (L1)

For each contract in the deployment manifest, verify it has non-zero code:

```bash
# Example: Check ProxyAdmin
cast code $PROXY_ADMIN_ADDR --rpc-url $L1_RPC_URL

# Example: Check Bridgehub Proxy
cast code $BRIDGEHUB_PROXY_ADDR --rpc-url $L1_RPC_URL

# Example: Check Governance
cast code $GOVERNANCE_ADDR --rpc-url $L1_RPC_URL
```

**Expected**: Each address returns bytecode (not `0x`).

### 2. Verify Proxy Implementations

For each transparent proxy, verify the implementation address:

```bash
# Get implementation address from EIP-1967 storage slot
# Implementation slot: 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc

cast storage $BRIDGEHUB_PROXY_ADDR 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $L1_RPC_URL

# Verify it matches the implementation address from contracts.yaml
```

**Expected**: Implementation address matches the deployed implementation contract.

### 3. Verify Proxy Admin

For each transparent proxy, verify the admin address:

```bash
# Admin slot: 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103

cast storage $BRIDGEHUB_PROXY_ADDR 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url $L1_RPC_URL
```

**Expected**: Admin address matches the ProxyAdmin contract address.

### 4. Verify Contract Ownership

Check ownership of key contracts:

```bash
# Governance owner
cast call $GOVERNANCE_ADDR "owner()(address)" --rpc-url $L1_RPC_URL

# Bridgehub owner
cast call $BRIDGEHUB_PROXY_ADDR "owner()(address)" --rpc-url $L1_RPC_URL

# ChainTypeManager owner
cast call $STATE_TRANSITION_PROXY_ADDR "owner()(address)" --rpc-url $L1_RPC_URL

# ValidatorTimelock owner
cast call $VALIDATOR_TIMELOCK_ADDR "owner()(address)" --rpc-url $L1_RPC_URL
```

**Expected**: All contracts are owned by the governance address (or deployer if ownership not yet transferred).

### 5. Verify CREATE2 Deterministic Addresses

For contracts deployed via CREATE2, verify the address matches the expected deterministic address:

```bash
# Example: Verify Bridgehub Implementation
# Expected address = CREATE2(deployer, salt, initcode_hash)
# This can be computed using the Create2 library or Foundry's create2 command

cast create2 --starts-with 0x --case-sensitive --deployer $CREATE2_FACTORY_ADDR --init-code-hash $INIT_CODE_HASH --salt $SALT
```

**Expected**: Computed address matches the deployed address in `contracts.yaml`.

---

## Initialization Validation

### 1. Verify ChainTypeManager Registration

```bash
# Check if CTM is registered with Bridgehub
cast call $BRIDGEHUB_PROXY_ADDR "chainTypeManagerIsRegistered(address)(bool)" $STATE_TRANSITION_PROXY_ADDR --rpc-url $L1_RPC_URL
```

**Expected**: Returns `true`.

### 2. Verify ZK Chain Registration

```bash
# Check if chain is registered
cast call $BRIDGEHUB_PROXY_ADDR "getZKChain(uint256)(address)" $CHAIN_ID --rpc-url $L1_RPC_URL
```

**Expected**: Returns the diamond proxy address for the chain (not zero address).

### 3. Verify Chain Admin

```bash
# Get chain admin from diamond proxy
cast call $DIAMOND_PROXY_ADDR "getAdmin()(address)" --rpc-url $L1_RPC_URL
```

**Expected**: Returns the ChainAdmin contract address.

### 4. Verify DA Validator Pair

```bash
# Get DA validator pair from diamond proxy
cast call $DIAMOND_PROXY_ADDR "getDAValidatorPair()(address,address)" --rpc-url $L1_RPC_URL
```

**Expected**: Returns `(<l1_da_validator_addr>, <l2_da_validator_addr>)`.

### 5. Verify Validators in ValidatorTimelock

```bash
# Check if commit validator is registered
cast call $VALIDATOR_TIMELOCK_ADDR "validators(uint256,address)(bool)" $CHAIN_ID $OPERATOR_COMMIT_ADDR --rpc-url $L1_RPC_URL

# Check if blob operator is registered
cast call $VALIDATOR_TIMELOCK_ADDR "validators(uint256,address)(bool)" $CHAIN_ID $OPERATOR_BLOBS_ADDR --rpc-url $L1_RPC_URL
```

**Expected**: Both return `true`.

### 6. Verify Token Multiplier Setter (if using non-ETH base token)

```bash
# Get token multiplier setter
cast call $DIAMOND_PROXY_ADDR "getTokenMultiplierSetter()(address)" --rpc-url $L1_RPC_URL
```

**Expected**: Returns the token multiplier setter address (if configured).

### 7. Verify Permanent Rollup Status (if applicable)

```bash
# Check if chain is marked as permanent rollup
cast call $DIAMOND_PROXY_ADDR "isPermanentRollup()(bool)" --rpc-url $L1_RPC_URL
```

**Expected**: Returns `true` if `--make-permanent-rollup` was set, otherwise `false`.

---

## Idempotency Testing

### 1. Re-run Deployment (Dry Run)

Re-run the deployment with the `--dry-run` flag (no broadcast):

```bash
zkstack ecosystem init --dry-run
```

**Expected**: All deployment checks pass, no new transactions are created (all contracts already exist).

### 2. Re-run Chain Initialization (Dry Run)

```bash
zkstack chain init --dry-run
```

**Expected**: All initialization checks pass, registration is skipped (chain already registered).

### 3. Verify No Duplicate Deployments

Check that re-running deployment does not create duplicate contracts:

```bash
# Count transactions in broadcast logs
ls -la contracts/l1-contracts/broadcast/DeployCTM.s.sol/*/run-*.json | wc -l
```

**Expected**: Only one set of broadcast logs exists (or subsequent runs produce no new transactions).

### 4. Test Individual Idempotent Steps

For each init step, verify it can be safely re-run:

```bash
# Example: Re-add validator (should be no-op)
zkstack chain admin update-validator --validator $OPERATOR_COMMIT_ADDR --add true

# Verify validator is still registered (unchanged)
cast call $VALIDATOR_TIMELOCK_ADDR "validators(uint256,address)(bool)" $CHAIN_ID $OPERATOR_COMMIT_ADDR --rpc-url $L1_RPC_URL
```

**Expected**: Command succeeds without errors, state remains unchanged.

---

## Role Mapping Verification

### 1. Map Private Keys to Roles

Verify each role has a corresponding wallet with a private key:

```yaml
# From configs/wallets.yaml
deployer:
  address: "0x..."
  private_key: "0x..."

governor:
  address: "0x..."
  private_key: "0x..."

operator:
  address: "0x..."
  private_key: "0x..."

blob_operator:
  address: "0x..."
  private_key: "0x..."
```

**Expected**: All required roles (deployer, governor, operator, blob_operator) have valid addresses and private keys.

### 2. Verify Role Permissions

Check that each role has the expected permissions:

| Role | Expected Permissions | Verification Method |
|------|----------------------|---------------------|
| **deployer** | Can deploy contracts, no ongoing control after ownership transfer | Check owner of contracts is not deployer |
| **governor** | Owner of Governance, Bridgehub, CTM, ValidatorTimelock | `cast call <contract> "owner()(address)"` |
| **operator_commit** | Registered in ValidatorTimelock for chain | `cast call $VALIDATOR_TIMELOCK_ADDR "validators(uint256,address)(bool)" $CHAIN_ID $OPERATOR_ADDR` |
| **operator_blobs** | Registered in ValidatorTimelock for chain | Same as above |
| **chain_admin** | Admin of chain diamond proxy | `cast call $DIAMOND_PROXY_ADDR "getAdmin()(address)"` |

### 3. Verify No Hardcoded Private Keys

Ensure private keys are never hardcoded in scripts or configs committed to git:

```bash
# Check for potential private key leaks
git grep -i "private_key" --and --not "wallets.yaml"
git grep "0x[a-fA-F0-9]{64}" --and --not "wallets.yaml"
```

**Expected**: No matches (or only references in `wallets.yaml` which should be .gitignored).

---

## Healthy End-State Checklist

After deployment and initialization, verify the following end-state conditions:

### L1 Contract Health

- [ ] All L1 contracts have non-zero bytecode
- [ ] All proxies point to correct implementations
- [ ] All proxies have correct admin (ProxyAdmin contract)
- [ ] Governance owns Bridgehub, CTM, and ValidatorTimelock
- [ ] ChainAdmin owns the chain diamond proxy
- [ ] ChainTypeManager is registered with Bridgehub
- [ ] ZK chain is registered in Bridgehub (returns non-zero diamond proxy address)
- [ ] DA validator pair is set correctly
- [ ] All validators (commit, blobs, prove, execute) are registered in ValidatorTimelock
- [ ] Token multiplier setter is configured (if using non-ETH base token)

### L2 Genesis Health (if running)

- [ ] L2 chain starts successfully
- [ ] Genesis block is created with correct root hash
- [ ] L2 predeployed contracts are accessible:
  - L2AssetRouter at `L2_ASSET_ROUTER_ADDRESS`
  - L2NativeTokenVault at `L2_NATIVE_TOKEN_VAULT_ADDRESS`
  - L2DAValidator at the configured address
  - Multicall3, TimestampAsserter, ConsensusRegistry

### Operational Health

- [ ] Sequencer can start without errors
- [ ] L2 RPC endpoint is responsive: `cast block-number --rpc-url $L2_RPC_URL`
- [ ] L1->L2 deposits can be initiated (test with small amount)
- [ ] L2->L1 withdrawals can be initiated (test with small amount)
- [ ] Batch commitment works (sequencer commits batches to L1)
- [ ] Batch execution works (batches are executed on L1 after timelock)

### Configuration Files

- [ ] `configs/contracts.yaml` contains all ecosystem contract addresses
- [ ] `chains/<chain-name>/configs/contracts.yaml` contains chain-specific addresses
- [ ] `configs/wallets.yaml` contains all required wallets
- [ ] `configs/genesis.yaml` contains genesis parameters
- [ ] `ZkStack.yaml` contains ecosystem and chain configuration

---

## Common Issues and Troubleshooting

### Issue: Contract deployment fails with "nonce too low"

**Cause**: Nonce conflict from previous deployment attempt.

**Solution**: 
- Use `--resume` flag to resume from last successful transaction
- Or wait for pending transactions to be mined
- Or use `--reset` to start fresh (will re-deploy all contracts)

### Issue: Ownership transfer fails with "caller is not the owner"

**Cause**: Ownership already transferred, or wrong wallet used.

**Solution**:
- Check current owner: `cast call $CONTRACT_ADDR "owner()(address)" --rpc-url $L1_RPC_URL`
- Verify you're using the correct wallet (deployer for initial transfer, governance for subsequent operations)
- Check if ownership transfer is idempotent (already completed)

### Issue: Chain registration fails with "chain already registered"

**Cause**: Chain already registered in Bridgehub.

**Solution**:
- This is expected behavior during idempotent re-runs
- Verify chain is registered correctly: `cast call $BRIDGEHUB_PROXY_ADDR "getZKChain(uint256)(address)" $CHAIN_ID`
- If address is correct, skip re-registration

### Issue: Validator addition fails with "validator already added"

**Cause**: Validator already registered in ValidatorTimelock.

**Solution**:
- This is expected behavior during idempotent re-runs
- Verify validator is registered: `cast call $VALIDATOR_TIMELOCK_ADDR "validators(uint256,address)(bool)" $CHAIN_ID $VALIDATOR_ADDR`
- If returns `true`, skip re-adding

### Issue: DA validator pair mismatch

**Cause**: Wrong L1 or L2 DA validator configured.

**Solution**:
- Check expected DA validator for mode:
  - Rollup: `rollup_l1_da_validator_addr` (L1), `rollup_l2_da_validator_addr` (L2)
  - Validium: `no_da_validium_l1_validator_addr` (L1), `validium_l2_da_validator_addr` (L2)
- Re-run `zkstack chain set-da-validator-pair` with correct addresses

### Issue: L2 genesis fails to initialize

**Cause**: Missing or incorrect genesis parameters.

**Solution**:
- Check `configs/genesis.yaml` for required fields:
  - `genesis_root`
  - `genesis_rollup_leaf_index`
  - `genesis_batch_commitment`
  - `bootloader_hash`
  - `default_aa_hash`
- Verify `force_deployments_data` is correctly encoded in `contracts.yaml`
- Check L2 contract deployment succeeded: `zkstack chain deploy-l2-contracts`

### Issue: Sequencer cannot commit batches

**Cause**: Operator not registered as validator.

**Solution**:
- Verify operator is registered: `cast call $VALIDATOR_TIMELOCK_ADDR "validators(uint256,address)(bool)" $CHAIN_ID $OPERATOR_ADDR`
- If `false`, add operator: `zkstack chain admin update-validator --validator $OPERATOR_ADDR --add true`

---

## Verification Scripts

### Quick Health Check Script

```bash
#!/bin/bash
set -e

echo "=== ZK Stack Deployment Health Check ==="

# Load addresses from contracts.yaml
BRIDGEHUB=$(yq e '.ecosystem_contracts.bridgehub_proxy_addr' configs/contracts.yaml)
CTM=$(yq e '.ecosystem_contracts.state_transition_proxy_addr' configs/contracts.yaml)
GOVERNANCE=$(yq e '.l1.governance_addr' configs/contracts.yaml)
CHAIN_ID=$(yq e '.chain_id' chains/*/ZkStack.yaml)
DIAMOND_PROXY=$(yq e '.l1.diamond_proxy_addr' chains/*/configs/contracts.yaml)

echo "Bridgehub: $BRIDGEHUB"
echo "CTM: $CTM"
echo "Governance: $GOVERNANCE"
echo "Chain ID: $CHAIN_ID"
echo "Diamond Proxy: $DIAMOND_PROXY"

echo ""
echo "Checking contract deployments..."
cast code $BRIDGEHUB --rpc-url $L1_RPC_URL > /dev/null && echo "✓ Bridgehub deployed"
cast code $CTM --rpc-url $L1_RPC_URL > /dev/null && echo "✓ CTM deployed"
cast code $GOVERNANCE --rpc-url $L1_RPC_URL > /dev/null && echo "✓ Governance deployed"
cast code $DIAMOND_PROXY --rpc-url $L1_RPC_URL > /dev/null && echo "✓ Diamond Proxy deployed"

echo ""
echo "Checking ownership..."
BRIDGEHUB_OWNER=$(cast call $BRIDGEHUB "owner()(address)" --rpc-url $L1_RPC_URL)
echo "Bridgehub owner: $BRIDGEHUB_OWNER (expected: $GOVERNANCE)"
[ "$BRIDGEHUB_OWNER" = "$GOVERNANCE" ] && echo "✓ Bridgehub ownership correct"

echo ""
echo "Checking chain registration..."
REGISTERED_CHAIN=$(cast call $BRIDGEHUB "getZKChain(uint256)(address)" $CHAIN_ID --rpc-url $L1_RPC_URL)
echo "Registered chain address: $REGISTERED_CHAIN (expected: $DIAMOND_PROXY)"
[ "$REGISTERED_CHAIN" = "$DIAMOND_PROXY" ] && echo "✓ Chain registered correctly"

echo ""
echo "=== Health check complete ==="
```

---

## Conclusion

This runbook provides comprehensive validation steps for a ZK Stack deployment. Follow these steps in order after deployment and initialization to ensure a healthy, correctly configured system. All checks should pass before moving to production or operating the chain with real value.

For additional support, refer to:
- ZK Stack documentation: https://docs.zksync.io/zk-stack
- GitHub issues: https://github.com/matter-labs/zksync-era/issues
