# ZK Stack Infrastructure Scripts

This directory contains scripts for managing ZK Stack infrastructure and interoperability testing.

## interop.sh - 4-Chain Interop Setup

The `interop.sh` script provides a simple command-line interface for setting up and managing a 4-chain interoperability testing environment.

### Quick Start

```bash
# Install foundry-zksync first (required)
curl -L https://raw.githubusercontent.com/matter-labs/foundry-zksync/main/install-foundry-zksync | bash

# Start all chains and configure interop
./infrastructure/scripts/interop.sh up

# Check status
./infrastructure/scripts/interop.sh status

# Stop all chains
./infrastructure/scripts/interop.sh down
```

### Commands

- `up` - Start all four chains (L1, Gateway, Era, Era2), migrate Era/Era2 to Gateway, prefund accounts, and verify setup
- `down` - Stop and clean up all chains
- `status` - Show current status and running ports

### What it does

When you run `./interop.sh up`, the script will:

1. **Start L1 node** on port 8545
2. **Start Era chain** on port 3150
3. **Start Gateway chain** on port 3050 and convert it to a settlement layer
4. **Start Era2 chain** on port 3250 (using validium mode)
5. **Migrate Era and Era2** to use Gateway as their settlement layer
6. **Prefund a developer account** with 1 ETH on all chains
7. **Verify** each chain responds to `eth_chainId`
8. **Verify** there is contract code at `0x000000000000000000000000000000000001000b` on Era
9. **Print the final status** with all running ports

### Environment Variables

You can customize the script behavior using these environment variables:

```bash
export L1_RPC_PORT=8545                    # L1 RPC port
export GATEWAY_RPC_PORT=3050               # Gateway RPC port  
export ERA_RPC_PORT=3150                   # Era RPC port
export ERA2_RPC_PORT=3250                  # Era2 RPC port
export DEV_PK="0x..."                     # Private key for prefunding
export DEV_ADDR="0x..."                   # Address to prefund
export PREFUND_AMOUNT_ETH=1                # Amount to prefund in ETH
export QUIET=false                         # Reduce logging
export ZKSTACK_BIN=zkstack                 # Path to zkstack binary
```

### Prerequisites

- **zkstack CLI** - Install with: `cargo install --path zkstack_cli/crates/zkstack --force --locked`  
- **foundry-zksync** - Install with: `curl -L https://raw.githubusercontent.com/matter-labs/foundry-zksync/main/install-foundry-zksync | bash`
- **PostgreSQL** - Running on localhost:5432 (automatically started by zkstack)
- **Docker** - For container management

### Troubleshooting

If chains fail to start:

```bash
# Clean everything and try again
zkstack dev clean containers
./infrastructure/scripts/interop.sh up
```

If the script gets stuck:

```bash
# Kill any hanging processes
pkill -9 zksync_server
./infrastructure/scripts/interop.sh down
./infrastructure/scripts/interop.sh up
```

### Example Output

```
L1 running on http://127.0.0.1:8545
Gateway running on http://127.0.0.1:3050  
Era running on http://127.0.0.1:3150
  ✓ Code verified at 0x000000000000000000000000000000000001000b
Era2 running on http://127.0.0.1:3250
Dev account: 0x36615Cf349d7F6344891B1e7CA7C72883F5dc049 funded on all chains. The PK for dev account is 0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110
```

### Features

- **Idempotent** - Safe to run multiple times
- **POSIX compliant** - Works on macOS and Linux
- **Comprehensive error handling** - Clear error messages and prerequisite checking
- **Configurable** - All ports and settings can be customized via environment variables
- **Status monitoring** - Real-time chain health checking
- **Contract verification** - Verifies deployment of key system contracts