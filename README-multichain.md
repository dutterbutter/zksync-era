# Multi-Chain Docker Compose Setup

This Docker Compose setup provides a repeatable build environment for spinning up multiple zkStack chains using zkstack-cli.

## Chains Included

1. **L1 Chain** (Reth) - Port 8545
2. **Era Chain** (Ecosystem) - Ports 3050 (HTTP), 3051 (WebSocket)
3. **Gateway Chain** - Ports 3070-3075
4. **Are Chain** - Ports 3080-3085
5. **Dutterbutter Chain** - Ports 3090-3095

## Prerequisites

- Docker and Docker Compose
- At least 8GB RAM
- At least 20GB free disk space

## Quick Start

1. Clone the repository and navigate to the project directory:
```bash
git clone git@github.com:dutterbutter/zksync-era.git
cd zksync-era
```

2. Start all chains:
```bash
docker compose -f docker-compose-multichain.yml up
```

This will:
- Start L1 (Reth) and PostgreSQL
- Install zkstack CLI
- Initialize the Era ecosystem
- Create and configure all chains (Dutterbutter, Are, Gateway)
- Convert Gateway to gateway mode
- Migrate Are and Dutterbutter chains to use the Gateway
- Start all chain servers

## Architecture

The setup follows this sequence:

1. **Base Infrastructure**: Reth (L1) and PostgreSQL are started first
2. **Orchestrator**: The main container installs zkstack-cli and runs the setup script
3. **Era Ecosystem**: Initialize the base Era ecosystem with smart contracts
4. **Chain Creation**: Create Dutterbutter, Are, and Gateway chains
5. **Gateway Configuration**: Convert Gateway chain to gateway mode
6. **Migration**: Migrate Are and Dutterbutter chains to use the Gateway
7. **Server Startup**: Start all chain servers

## Port Mapping

| Service | HTTP Port | WebSocket Port | Health Port | Metrics Port |
|---------|-----------|----------------|-------------|--------------|
| L1 (Reth) | 8545 | - | - | - |
| Era | 3050 | 3051 | 3071 | 3312 |
| Gateway | 3070 | 3071 | 3072 | 3074 |
| Are | 3080 | 3081 | 3082 | 3084 |
| Dutterbutter | 3090 | 3091 | 3092 | 3094 |

## Accessing the Chains

Once the setup is complete, you can interact with the chains:

### L1 (Reth)
```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:8545
```

### Era Chain
```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:3050
```

### Gateway Chain
```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:3070
```

### Are Chain
```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:3080
```

### Dutterbutter Chain
```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:3090
```

## Logs

Chain logs are stored in the zkstack-data volume and can be viewed using:

```bash
# View all logs
docker compose -f docker-compose-multichain.yml logs -f

# View specific service logs
docker compose -f docker-compose-multichain.yml logs -f zkstack-orchestrator
docker compose -f docker-compose-multichain.yml logs -f gateway-server
```

## Stopping the Setup

To stop all services:

```bash
docker compose -f docker-compose-multichain.yml down
```

To stop and remove volumes (clean reset):

```bash
docker compose -f docker-compose-multichain.yml down -v
```

## Troubleshooting

### Setup is taking too long
The initial setup can take 10-30 minutes depending on your system. The orchestrator needs to:
- Install zkstack CLI (compiling from source)
- Download and deploy smart contracts
- Initialize multiple chains
- Wait for each service to be ready

### Port conflicts
If you have conflicts with the default ports, you can modify the port mappings in `docker-compose-multichain.yml`.

### Out of memory
Ensure you have at least 8GB RAM available. You may need to increase Docker's memory limit.

### Checking if services are ready
You can check the health of individual services:

```bash
# Check if L1 is ready
curl -s http://localhost:8545

# Check if Era is ready  
curl -s http://localhost:3050

# Check orchestrator progress
docker compose -f docker-compose-multichain.yml logs zkstack-orchestrator
```

## Chain Configuration

Each chain is configured with:
- **Prover mode**: no-proofs (for faster local development)
- **Base token**: ETH (0x0000000000000000000000000000000000000001)
- **L1 batch commit mode**: rollup
- **EVM emulator**: disabled

## Development

To modify the setup:

1. Edit `scripts/multichain-setup.sh` to change the initialization sequence
2. Edit `docker-compose-multichain.yml` to change service configuration
3. Restart the services:
   ```bash
   docker compose -f docker-compose-multichain.yml restart
   ```