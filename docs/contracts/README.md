# ZK Stack Contract Deployment Manifest

This directory contains a canonical, machine-consumable manifest of all L1/L2 contracts and transactions required to deploy and initialize a ZK Stack chain for local development (Localhost rollup mode, no-proofs).

## Purpose

These manifests serve as the **source of truth** for:

1. **Contract inventory**: Complete list of L1 contracts, their deployment methods, and roles
2. **Deployment sequence**: Ordered transaction plan for deploying ecosystem contracts
3. **Initialization sequence**: Ordered transaction plan for registering and configuring a chain
4. **Source traceability**: Mapping from manifest steps to source code locations
5. **Validation procedures**: Runbook for verifying deployment correctness and idempotency

## Files

| File | Description |
|------|-------------|
| **[CONTRACTS.md](./CONTRACTS.md)** | Human-readable contract inventory table with all L1/L2 contracts |
| **[contracts.json](./contracts.json)** | Machine-readable contract inventory (same data as CONTRACTS.md) |
| **[deploy-manifest.yaml](./deploy-manifest.yaml)** | Deployment transaction manifest (L1 ecosystem contracts) |
| **[init-manifest.yaml](./init-manifest.yaml)** | Initialization transaction manifest (chain registration & config) |
| **[source-map.json](./source-map.json)** | Maps manifest steps to zkstack CLI functions and Foundry scripts |
| **[validation.md](./validation.md)** | Validation runbook with preconditions, checks, and troubleshooting |
| **[VALIDIUM_DELTAS.md](./VALIDIUM_DELTAS.md)** | Differences between rollup and validium modes |

## Quick Start

### 1. Review the Contract Inventory

Start by reviewing the complete contract inventory to understand the system architecture:

```bash
# Human-readable table
cat docs/contracts/CONTRACTS.md

# Machine-readable JSON (for tooling)
cat docs/contracts/contracts.json | jq
```

### 2. Understand the Deployment Flow

Review the deployment manifest to see the ordered sequence of contract deployments:

```bash
# View deployment plan
cat docs/contracts/deploy-manifest.yaml | less

# Extract deployment steps
yq e '.deploy_plan[] | .id' docs/contracts/deploy-manifest.yaml
```

### 3. Understand the Initialization Flow

Review the initialization manifest to see how a chain is registered and configured:

```bash
# View initialization plan
cat docs/contracts/init-manifest.yaml | less

# Extract initialization steps
yq e '.init_plan[] | .id' docs/contracts/init-manifest.yaml
```

### 4. Trace Steps to Source Code

Use the source map to find where each step is implemented:

```bash
# Find source for a specific deployment step
cat docs/contracts/source-map.json | jq '.deploy_plan.bridgehub_proxy_deploy'

# Find source for a specific init step
cat docs/contracts/source-map.json | jq '.init_plan.register_zk_chain'
```

### 5. Validate a Deployment

After deploying, use the validation runbook to verify correctness:

```bash
# Follow the validation runbook
cat docs/contracts/validation.md | less

# Or run the provided health check script (see validation.md)
```

## Manifest Structure

### Deploy Manifest (`deploy-manifest.yaml`)

Each deployment step includes:

- **id**: Unique identifier for the step
- **from_role**: Role of the transaction sender (e.g., `deployer`, `governor`)
- **to**: Target address (`0x0` for contract creation)
- **method**: Contract constructor or function signature
- **params**: Constructor/function parameters (symbolic placeholders)
- **deployment**: Deployment type (`create`, `create2`, `proxy`)
- **depends_on**: List of step IDs that must complete first
- **idempotency_check**: Condition to check if step is already done
- **postcondition**: Condition to verify step succeeded
- **notes**: Additional context

Example:
```yaml
- id: bridgehub_proxy_deploy
  from_role: deployer
  to: "0x0"
  method: "TransparentUpgradeableProxy.constructor(address,address,bytes)"
  params:
    - "<bridgehub_impl>"
    - "<proxy_admin>"
    - "0x"
  deployment: create
  depends_on: [bridgehub_impl_deploy, proxy_admin_deploy]
  idempotency_check: "code_at(<bridgehub_proxy>) != 0x"
  postcondition: "proxy_impl(<bridgehub_proxy>) == <bridgehub_impl>"
  notes: "Bridgehub proxy - main entry point for chain registration"
```

### Init Manifest (`init-manifest.yaml`)

Each initialization step includes similar fields, plus:

- **optional**: Boolean indicating if step is optional (e.g., `make_permanent_rollup`)

Example:
```yaml
- id: register_zk_chain
  from_role: governor
  to: "<bridgehub_proxy>"
  method: "createNewChain(uint256,address,address,uint256,address,bytes,bytes)"
  params:
    chain_id: "<chain_id>"
    chain_type_manager: "<state_transition_proxy>"
    base_token: "<base_token_addr>"
    salt: "<bridgehub_create_new_chain_salt>"
    admin: "<chain_admin_addr>"
    init_data: "<diamond_cut_data>"
    factory_deps: "<force_deployments_data>"
  depends_on: [register_ctm, deploy_chain_admin]
  idempotency_check: "bridgehub.getZKChain(<chain_id>) != 0x0"
  postcondition: "event(Bridgehub.ChainRegistered, chainId=<chain_id>)"
  notes: "Register new ZK chain and deploy its diamond proxy via Bridgehub"
```

### Source Map (`source-map.json`)

Maps each step ID to:

- **file**: Rust source file in zkstack CLI
- **function**: Function name
- **forge_script**: Foundry script path
- **lines**: Line range in source file
- **broadcast**: Broadcast JSON output path (for Foundry)
- **notes**: Additional context

## Symbolic Placeholders

Manifests use symbolic placeholders (e.g., `<bridgehub_proxy>`, `<governor>`) that are resolved at runtime from configuration files:

| Placeholder | Source | Example |
|-------------|--------|---------|
| `<owner_address>` | `configs/wallets.yaml` → `governor.address` | `0x36615Cf349d7F6344891B1e7CA7C72883F5dc049` |
| `<bridgehub_proxy>` | `configs/contracts.yaml` → `ecosystem_contracts.bridgehub_proxy_addr` | `0x1234...` |
| `<chain_id>` | `chains/*/ZkStack.yaml` → `chain_id` | `270` |
| `<create2_salt_bridgehub>` | `configs/initial_deployments.yaml` → `create2_factory_salt` | `0xabcd...` |

See `source-map.json` → `wallet_roles` for complete role mapping.

## Idempotency

All deployment and initialization steps are designed to be **idempotent**:

- **Idempotency check**: Condition to verify if step is already completed
- **Postcondition**: Condition to verify step succeeded (used for both initial run and re-runs)

Benefits:
- **Resume on failure**: If deployment fails midway, re-running continues from where it left off
- **Safe re-runs**: Re-running a complete deployment is safe (no duplicate contracts, no state corruption)
- **Validation**: Idempotency checks serve as validation that the system is in the expected state

## Usage in zksup (Future)

These manifests are designed to be consumed by a future `zksup` tool for single-command local setup:

```bash
# Hypothetical future usage
zksup deploy --manifest docs/contracts/deploy-manifest.yaml --config my-config.yaml
zksup init --manifest docs/contracts/init-manifest.yaml --chain my-chain
zksup validate --manifest docs/contracts/validation.md
```

The tool would:
1. Load manifests and configuration
2. Resolve symbolic placeholders from config
3. Execute steps in order, respecting dependencies
4. Check idempotency before each step (skip if already done)
5. Verify postconditions after each step
6. Generate a deployment report with addresses and transaction hashes

## Deltas for Validium Mode

Most contracts and steps are the same for rollup and validium modes. Key differences are documented in **[VALIDIUM_DELTAS.md](./VALIDIUM_DELTAS.md)**.

Summary of key differences:

| Component | Rollup | Validium |
|-----------|--------|----------|
| **L1 DA Validator** | `RollupL1DAValidator` | `ValidiumL1DAValidator` |
| **L2 DA Validator** | Rollup L2 DA Validator | Validium L2 DA Validator |
| **DA Manager** | `RollupL1DAManager` | Not used (validium uses off-chain DA) |
| **Commitment Data** | Full data posted to L1 (blobs or calldata) | Only commitment hash posted to L1 |

For complete details including configuration, validation, and migration procedures, see **[VALIDIUM_DELTAS.md](./VALIDIUM_DELTAS.md)**.

To use validium mode:
- Set `validium_mode: true` in chain config
- Use `ValidiumL1DAValidator` address for L1 DA validator
- Deploy validium-specific L2 DA validator

## Contributing

When modifying ZK Stack deployment logic:

1. **Update manifests**: Ensure changes are reflected in the appropriate manifest files
2. **Update source map**: Add/modify entries to trace new/changed steps
3. **Test idempotency**: Verify new steps can be safely re-run
4. **Update validation**: Add new checks to `validation.md`
5. **Document deltas**: If changes affect validium mode differently, document in this README

## Related Documentation

- **ZK Stack Documentation**: https://docs.zksync.io/zk-stack
- **zkstack CLI Source**: `zkstack_cli/crates/zkstack/src/commands/`
- **Foundry Scripts**: `l1-contracts/deploy-scripts/`, `l2-contracts/script/`
- **Contract Configs**: `configs/contracts.yaml`, `chains/*/configs/contracts.yaml`
- **Wallet Configs**: `configs/wallets.yaml`

## License

This documentation is part of the ZK Stack project and follows the same license as the zksync-era repository.
