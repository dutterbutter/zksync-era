# ZK Stack Contract Inventory

This document provides a comprehensive inventory of all L1 contracts required for deploying a ZK Stack chain in Localhost mode (rollup, no-proofs).

## L1 Core Infrastructure Contracts

| Name | Artifact | Deployment | Create2 Salt | Constructor Args | Address Source | Admin/Owner | Events to Watch | Mode |
|------|----------|------------|--------------|------------------|----------------|-------------|-----------------|------|
| **Create2Factory** | Create2Factory | create | N/A | None | deterministic | none | N/A | both |
| **TransparentProxyAdmin** | TransparentUpgradeableProxy | create | N/A | None | from_event | deployer | N/A | both |
| **Governance** | Governance | create | N/A | `<owner_address>`, `<governance_security_council_address>`, `<governance_min_delay>` | from_event | owner (governor) | N/A | both |

## Bridgehub & State Transition Contracts

| Name | Artifact | Deployment | Create2 Salt | Constructor Args | Address Source | Admin/Owner | Events to Watch | Mode |
|------|----------|------------|--------------|------------------|----------------|-------------|-----------------|------|
| **Bridgehub Implementation** | Bridgehub | create2 | `<create2_salt_bridgehub>` | `<l1_chain_id>`, `<owner_address>`, `<max_number_of_chains>` | deterministic | none (logic contract) | N/A | both |
| **Bridgehub Proxy** | TransparentUpgradeableProxy | create | N/A | `<bridgehub_impl>`, `<proxy_admin>`, `0x` (empty init data) | from_event | proxy_admin | N/A | both |
| **CTM Deployment Tracker Implementation** | CTMDeploymentTracker | create2 | `<create2_salt_ctm_tracker>` | `<bridgehub_proxy>`, `<message_root_addr>` | deterministic | none (logic contract) | N/A | both |
| **CTM Deployment Tracker Proxy** | TransparentUpgradeableProxy | create | N/A | `<ctm_tracker_impl>`, `<proxy_admin>`, `0x` | from_event | proxy_admin | N/A | both |
| **MessageRoot Implementation** | MessageRoot | create2 | `<create2_salt_message_root>` | `<bridgehub_proxy>` | deterministic | none (logic contract) | N/A | both |
| **MessageRoot Proxy** | TransparentUpgradeableProxy | create | N/A | `<message_root_impl>`, `<proxy_admin>`, `0x` | from_event | proxy_admin | N/A | both |
| **ChainTypeManager Implementation** | ChainTypeManager | create2 | `<create2_salt_ctm>` | `<bridgehub_proxy>` | deterministic | none (logic contract) | N/A | both |
| **ChainTypeManager Proxy** | TransparentUpgradeableProxy | create | N/A | `<ctm_impl>`, `<proxy_admin>`, init_data | from_event | proxy_admin | N/A | both |

## Diamond Facets & Verification

| Name | Artifact | Deployment | Create2 Salt | Constructor Args | Address Source | Admin/Owner | Events to Watch | Mode |
|------|----------|------------|--------------|------------------|----------------|-------------|-----------------|------|
| **Verifier** | Verifier | create2 | `<create2_salt_verifier>` | None | deterministic | none | N/A | both |
| **AdminFacet** | AdminFacet | create2 | `<create2_salt_admin_facet>` | `<l1_chain_id>` | deterministic | none (facet) | N/A | both |
| **MailboxFacet** | MailboxFacet | create2 | `<create2_salt_mailbox_facet>` | `<l1_chain_id>`, `<era_chain_id>` | deterministic | none (facet) | N/A | both |
| **ExecutorFacet** | ExecutorFacet | create2 | `<create2_salt_executor_facet>` | `<l1_chain_id>` | deterministic | none (facet) | N/A | both |
| **GettersFacet** | GettersFacet | create2 | `<create2_salt_getters_facet>` | None | deterministic | none (facet) | N/A | both |
| **DiamondInit** | DiamondInit | create2 | `<create2_salt_diamond_init>` | None | deterministic | none | N/A | both |
| **GenesisUpgrade** | GenesisUpgrade | create2 | `<create2_salt_genesis_upgrade>` | None | deterministic | none | N/A | both |
| **DefaultUpgrade** | DefaultUpgrade | create2 | `<create2_salt_default_upgrade>` | None | deterministic | none | N/A | both |
| **DiamondProxy** | DiamondProxy | create2 | `<create2_salt_diamond_proxy>` | `<l1_chain_id>`, `<diamond_cut_data>` | deterministic | none (template) | N/A | both |
| **BytecodesSupplier** | L1BytecodesSupplier | create2 | `<create2_salt_bytecodes_supplier>` | None | deterministic | none | N/A | both |

## Bridge Contracts

| Name | Artifact | Deployment | Create2 Salt | Constructor Args | Address Source | Admin/Owner | Events to Watch | Mode |
|------|----------|------------|--------------|------------------|----------------|-------------|-----------------|------|
| **L1ERC20Bridge Implementation** | L1ERC20Bridge | create2 | `<create2_salt_erc20_bridge>` | `<l1_nullifier_proxy>`, `<l1_asset_router_proxy>`, `<native_token_vault_proxy>`, `<era_chain_id>` | deterministic | none (logic contract) | N/A | both |
| **L1ERC20Bridge Proxy** | TransparentUpgradeableProxy | create | N/A | `<erc20_bridge_impl>`, `<proxy_admin>`, init_data | from_event | proxy_admin | N/A | both |
| **L1AssetRouter Implementation** | L1AssetRouter | create2 | `<create2_salt_shared_bridge>` | `<l1_chain_id>`, `<era_chain_id>`, `<l1_nullifier_proxy>`, `<bridgehub_proxy>`, `<l1_native_token_vault_proxy>`, `<l1_wrapped_base_token_store>` | deterministic | none (logic contract) | N/A | both |
| **L1AssetRouter Proxy** | TransparentUpgradeableProxy | create | N/A | `<shared_bridge_impl>`, `<proxy_admin>`, init_data | from_event | proxy_admin | N/A | both |
| **L1Nullifier Implementation** | L1Nullifier | create2 | `<create2_salt_l1_nullifier>` | `<bridgehub_proxy>`, `<era_chain_id>`, `<l1_asset_router_proxy>` | deterministic | none (logic contract) | N/A | both |
| **L1Nullifier Proxy** | TransparentUpgradeableProxy | create | N/A | `<l1_nullifier_impl>`, `<proxy_admin>`, init_data | from_event | proxy_admin | N/A | both |
| **NativeTokenVault Implementation** | L1NativeTokenVault | create2 | `<create2_salt_native_token_vault>` | `<token_weth_address>`, `<l1_asset_router_proxy>`, `<l1_nullifier_proxy>` | deterministic | none (logic contract) | N/A | both |
| **NativeTokenVault Proxy** | TransparentUpgradeableProxy | create | N/A | `<native_token_vault_impl>`, `<proxy_admin>`, init_data | from_event | proxy_admin | N/A | both |
| **L1WrappedBaseTokenStore** | L1WrappedBaseTokenStore | create2 | `<create2_salt_wrapped_base_token_store>` | `<l1_asset_router_proxy>` | deterministic | none | N/A | both |

## Validator & Admin Contracts

| Name | Artifact | Deployment | Create2 Salt | Constructor Args | Address Source | Admin/Owner | Events to Watch | Mode |
|------|----------|------------|--------------|------------------|----------------|-------------|-----------------|------|
| **ValidatorTimelock** | ValidatorTimelock | create2 | `<create2_salt_validator_timelock>` | `<owner_address>`, `<validator_timelock_execution_delay>`, `<era_chain_id>` | deterministic | owner (governor) | N/A | both |
| **ChainAdmin** | ChainAdmin | create | N/A | `<restrictions>` | from_event | owner (governor) | N/A | both |
| **AccessControlRestriction** | AccessControlRestriction | create | N/A | `<governance_min_delay>`, `<owner_address>` | from_event | owner (governor) | N/A | both |

## DA Validators

| Name | Artifact | Deployment | Create2 Salt | Constructor Args | Address Source | Admin/Owner | Events to Watch | Mode |
|------|----------|------------|--------------|------------------|----------------|-------------|-----------------|------|
| **RollupL1DAValidator** | RollupL1DAValidator | create2 | `<create2_salt_rollup_da_validator>` | None | deterministic | none | N/A | rollup |
| **ValidiumL1DAValidator** | ValidiumL1DAValidator | create2 | `<create2_salt_validium_da_validator>` | None | deterministic | none | N/A | validium |
| **RollupL1DAManager** | RollupL1DAManager | create2 | `<create2_salt_rollup_da_manager>` | None | deterministic | none | N/A | rollup |
| **L1BytecodesSupplier** | L1BytecodesSupplier | create2 | `<create2_salt_bytecodes_supplier>` | None | deterministic | none | N/A | both |

## Notification & Utility Contracts

| Name | Artifact | Deployment | Create2 Salt | Constructor Args | Address Source | Admin/Owner | Events to Watch | Mode |
|------|----------|------------|--------------|------------------|----------------|-------------|-----------------|------|
| **ServerNotifier Implementation** | ServerNotifier | create2 | `<create2_salt_server_notifier>` | None | deterministic | none (logic contract) | N/A | both |
| **ServerNotifier Proxy** | TransparentUpgradeableProxy | create | N/A | `<server_notifier_impl>`, `<proxy_admin>`, `0x` | from_event | proxy_admin | N/A | both |
| **Multicall3** | Multicall3 | create | N/A | None | from_event | none | N/A | both |

## ZK Chain Instance Contracts (Registered per Chain)

| Name | Artifact | Deployment | Create2 Salt | Constructor Args | Address Source | Admin/Owner | Events to Watch | Mode |
|------|----------|------------|--------------|------------------|----------------|-------------|-----------------|------|
| **ZKChain Diamond Proxy** | DiamondProxy (instance) | create2 (via Bridgehub) | `<bridgehub_create_new_chain_salt>` | Chain-specific diamond cut | deterministic | chain_admin | `Bridgehub.ChainRegistered`, `ChainTypeManager.NewZKChain` | both |
| **ChainProxyAdmin** | ProxyAdmin | create (during registration) | N/A | `<chain_admin_addr>` | from_event | chain_admin | N/A | both |

## L2 Predeployed Contracts (Genesis)

| Name | Artifact | Deployment | Create2 Salt | Constructor Args | Address Source | Admin/Owner | Events to Watch | Mode |
|------|----------|------------|--------------|------------------|----------------|-------------|-----------------|------|
| **L2LegacySharedBridge** | L2SharedBridge | predeployed | N/A | Genesis params | known_constant (0x...) | governor | N/A | both |
| **L2AssetRouter** | L2AssetRouter | predeployed | N/A | Genesis params | known_constant (`L2_ASSET_ROUTER_ADDRESS`) | governor | N/A | both |
| **L2NativeTokenVault** | L2NativeTokenVault | predeployed | N/A | Genesis params | known_constant (`L2_NATIVE_TOKEN_VAULT_ADDRESS`) | governor | N/A | both |
| **L2DAValidator** | L2DAValidator (Rollup/Validium) | predeployed | N/A | Genesis params | from_deployment | governor | N/A | both |
| **Multicall3** | Multicall3 | predeployed | N/A | None | from_deployment | none | N/A | both |
| **TimestampAsserter** | TimestampAsserter | predeployed | N/A | None | from_deployment | none | N/A | both |
| **ConsensusRegistry** | ConsensusRegistry | predeployed | N/A | `<owner>`, `<node_owners>[]`, `<validator_timelock>` | from_deployment | owner (governor) | N/A | both |
| **Paymaster** | TestnetPaymaster (optional) | predeployed | N/A | None | from_deployment | none | N/A | both |

## Notes

- **Deployment Type**:
  - `create`: Standard CREATE deployment (nonce-based addressing)
  - `create2`: CREATE2 deployment (deterministic addressing via salt)
  - `proxy(impl)`: Proxy pattern (implementation + proxy)
  - `predeployed`: Included in L2 genesis state

- **Address Source**:
  - `deterministic`: Address can be pre-calculated from CREATE2 salt and bytecode
  - `from_event`: Address obtained from deployment transaction event/receipt
  - `known_constant`: Fixed address defined in system constants
  - `from_deployment`: Address obtained from deployment output

- **Admin/Owner Roles**:
  - `governor`: L1 Governance contract (controls upgrades and critical operations)
  - `deployer`: Deploys contracts (no ongoing control)
  - `proxy_admin`: Controls proxy upgrades (TransparentProxyAdmin)
  - `chain_admin`: Per-chain admin contract
  - `none`: No admin/owner (immutable or facet)

- **Mode**:
  - `rollup`: Only for rollup mode
  - `validium`: Only for validium mode
  - `both`: Used in both modes
