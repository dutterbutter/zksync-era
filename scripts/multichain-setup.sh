#!/bin/bash

set -e

echo "Starting multi-chain setup..."

# Environment variables
export L1_RPC_URL="http://reth:8545"
export DB_URL="postgres://postgres:notsecurepassword@postgres:5432"
export ZKSYNC_HOME="/usr/src/zksync"
export PATH="/usr/src/zksync/bin:/usr/src/zksync/zkstack_cli/zkstackup:${PATH}"

# Create logs directory
mkdir -p /data/logs

echo "Installing zkstack CLI..."
cd /usr/src/zksync

# Check if zkstack is already available
if ! command -v zkstack &> /dev/null; then
    echo "Building zkstack CLI from source..."
    # Build in release mode for better performance but shorter compile time
    cargo build --release --bin zkstack --manifest-path zkstack_cli/Cargo.toml
    # Copy to a location in PATH
    cp target/release/zkstack /usr/local/bin/zkstack
    chmod +x /usr/local/bin/zkstack
else
    echo "zkstack CLI already available"
fi

echo "Waiting for base services to be ready..."
sleep 15

# Wait for L1 (reth) to be ready
echo "Waiting for L1 to be ready..."
retry_count=0
max_retries=30
until curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    $L1_RPC_URL > /dev/null; do
    echo "Waiting for L1... (attempt $((retry_count+1))/$max_retries)"
    sleep 5
    retry_count=$((retry_count+1))
    if [ $retry_count -ge $max_retries ]; then
        echo "ERROR: L1 failed to start after $max_retries attempts"
        exit 1
    fi
done
echo "L1 is ready!"

# Wait for postgres to be ready
echo "Waiting for PostgreSQL to be ready..."
retry_count=0
until pg_isready -h postgres -p 5432 -U postgres; do
    echo "Waiting for PostgreSQL... (attempt $((retry_count+1))/$max_retries)"
    sleep 2
    retry_count=$((retry_count+1))
    if [ $retry_count -ge $max_retries ]; then
        echo "ERROR: PostgreSQL failed to start after $max_retries attempts"
        exit 1
    fi
done
echo "PostgreSQL is ready!"

echo "Step 1: Setting up base environment..."
zkstack dev clean containers
zkstack up -o false

echo "Step 2: Deploying base contracts..."
zkstack dev contracts

echo "Step 3: Initializing Era ecosystem..."
zkstack ecosystem init \
    --deploy-paymaster --deploy-erc20 --deploy-ecosystem \
    --l1-rpc-url=$L1_RPC_URL \
    --server-db-url=$DB_URL \
    --server-db-name=zksync_server_localhost_era \
    --ignore-prerequisites --observability=false \
    --chain era \
    --update-submodules false

echo "Step 4: Generating genesis block..."
zkstack dev generate-genesis

echo "Step 5: Re-running ecosystem init to finalize..."
zkstack ecosystem init \
    --deploy-paymaster --deploy-erc20 --deploy-ecosystem \
    --l1-rpc-url=$L1_RPC_URL \
    --server-db-url=$DB_URL \
    --server-db-name=zksync_server_localhost_era \
    --ignore-prerequisites --observability=false \
    --chain era \
    --update-submodules false

echo "Step 6: Creating Dutterbutter chain..."
zkstack chain create \
    --chain-name dutterbutter \
    --chain-id 260 \
    --prover-mode no-proofs \
    --wallet-creation localhost \
    --l1-batch-commit-data-generator-mode rollup \
    --base-token-address 0x0000000000000000000000000000000000000001 \
    --base-token-price-nominator 1 \
    --base-token-price-denominator 1 \
    --set-as-default false \
    --evm-emulator false \
    --ignore-prerequisites --update-submodules false

echo "Step 7: Initializing Dutterbutter chain..."
zkstack chain init \
    --deploy-paymaster \
    --l1-rpc-url=$L1_RPC_URL \
    --server-db-url=$DB_URL \
    --server-db-name=zksync_server_localhost_dutterbutter \
    --chain dutterbutter \
    --update-submodules false

echo "Step 8: Creating Are chain..."
zkstack chain create \
    --chain-name are \
    --chain-id 261 \
    --prover-mode no-proofs \
    --wallet-creation localhost \
    --l1-batch-commit-data-generator-mode rollup \
    --base-token-address 0x0000000000000000000000000000000000000001 \
    --base-token-price-nominator 1 \
    --base-token-price-denominator 1 \
    --set-as-default false \
    --evm-emulator false \
    --ignore-prerequisites --update-submodules false

echo "Step 9: Initializing Are chain..."
zkstack chain init \
    --deploy-paymaster \
    --l1-rpc-url=$L1_RPC_URL \
    --server-db-url=$DB_URL \
    --server-db-name=zksync_server_localhost_are \
    --chain are \
    --update-submodules false

echo "Step 10: Creating Gateway chain..."
zkstack chain create \
    --chain-name gateway \
    --chain-id 506 \
    --prover-mode no-proofs \
    --wallet-creation localhost \
    --l1-batch-commit-data-generator-mode rollup \
    --base-token-address 0x0000000000000000000000000000000000000001 \
    --base-token-price-nominator 1 \
    --base-token-price-denominator 1 \
    --set-as-default false \
    --evm-emulator false \
    --ignore-prerequisites --update-submodules false

echo "Step 11: Initializing Gateway chain..."
zkstack chain init \
    --deploy-paymaster \
    --l1-rpc-url=$L1_RPC_URL \
    --server-db-url=$DB_URL \
    --server-db-name=zksync_server_localhost_gateway \
    --chain gateway \
    --update-submodules false

echo "Step 12: Converting Gateway to gateway mode..."
zkstack chain gateway convert-to-gateway --chain gateway --ignore-prerequisites

echo "Step 13: Writing gateway config..."
zkstack dev config-writer --path etc/env/file_based/overrides/tests/gateway.yaml --chain gateway

echo "Step 14: Starting Gateway server..."
zkstack server --ignore-prerequisites --chain gateway &> /data/logs/gateway.log &
zkstack server wait --ignore-prerequisites --verbose --chain gateway

echo "Step 15: Migrating Era to Gateway..."
zkstack chain gateway migrate-to-gateway --chain era --gateway-chain-name gateway

echo "Step 16: Migrating Are to Gateway..."
zkstack chain gateway migrate-to-gateway --chain are --gateway-chain-name gateway

echo "Step 17: Migrating Dutterbutter to Gateway..."
zkstack chain gateway migrate-to-gateway --chain dutterbutter --gateway-chain-name gateway

echo "Step 18: Starting Era server..."
zkstack server --ignore-prerequisites --chain era &> /data/logs/era.log &
zkstack server wait --ignore-prerequisites --verbose --chain era

echo "Step 19: Starting Are server..."
zkstack server --ignore-prerequisites --chain are &> /data/logs/are.log &
zkstack server wait --ignore-prerequisites --verbose --chain are

echo "Step 20: Starting Dutterbutter server..."
zkstack server --ignore-prerequisites --chain dutterbutter &> /data/logs/dutterbutter.log &
zkstack server wait --ignore-prerequisites --verbose --chain dutterbutter

echo "All chains started successfully!"
echo "Chain ports:"
echo "  - L1 (reth): 8545"
echo "  - Era chain: 3050 (http), 3051 (ws)"
echo "  - Gateway chain: 3070-3075"
echo "  - Are chain: 3080-3085"  
echo "  - Dutterbutter chain: 3090-3095"

# Keep the container running
tail -f /data/logs/*.log