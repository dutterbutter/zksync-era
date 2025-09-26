#!/bin/bash

# 4-Chain Interop Setup Script
# Starts L1, Gateway, Era, and Era2 chains for interop testing
# Usage: ./interop.sh [up|down|status]

set -euo pipefail

# Default configuration
L1_RPC_PORT="${L1_RPC_PORT:-8545}"
GATEWAY_RPC_PORT="${GATEWAY_RPC_PORT:-3050}"
ERA_RPC_PORT="${ERA_RPC_PORT:-3150}"
ERA2_RPC_PORT="${ERA2_RPC_PORT:-3250}"
DEV_PK="${DEV_PK:-0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110}"
DEV_ADDR="${DEV_ADDR:-0x36615Cf349d7F6344891B1e7CA7C72883F5dc049}"
PREFUND_AMOUNT_ETH="${PREFUND_AMOUNT_ETH:-1}"
USE_DEFAULT_DEV_PK="${USE_DEFAULT_DEV_PK:-true}"
QUIET="${QUIET:-false}"
ZKSTACK_BIN="${ZKSTACK_BIN:-zkstack}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    if [ "$QUIET" != "true" ]; then
        echo -e "${GREEN}[INFO]${NC} $*"
    fi
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check if required tools are available
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v "$ZKSTACK_BIN" >/dev/null 2>&1; then
        error "zkstack binary not found. Please install it first."
        error "Run: cargo install --path zkstack_cli/crates/zkstack --force --locked"
        return 1
    fi
    
    if ! command -v cast >/dev/null 2>&1; then
        error "cast (from foundry) not found. Please install foundry-zksync first."
        error "Run: curl -L https://raw.githubusercontent.com/matter-labs/foundry-zksync/main/install-foundry-zksync | bash"
        return 1
    fi
    
    log "Prerequisites check passed"
    return 0
}

# Start L1 node
start_l1() {
    log "Starting L1 node on port $L1_RPC_PORT..."
    
    # Check if L1 is already running
    if check_chainid "http://127.0.0.1:$L1_RPC_PORT" >/dev/null 2>&1; then
        log "L1 node already running, skipping startup"
        return 0
    fi
    
    # Clean containers and start L1
    $ZKSTACK_BIN dev clean containers
    $ZKSTACK_BIN up -o false
    
    # Wait for L1 to be ready
    wait_for_rpc "L1" "http://127.0.0.1:$L1_RPC_PORT"
    log "L1 node started successfully"
}

# Start Gateway chain
start_gateway() {
    log "Starting Gateway chain on port $GATEWAY_RPC_PORT..."
    
    # Check if Gateway is already running
    if check_chainid "http://127.0.0.1:$GATEWAY_RPC_PORT" >/dev/null 2>&1; then
        log "Gateway chain already running, skipping startup"
        return 0
    fi
    
    # Create Gateway chain if not exists
    if ! $ZKSTACK_BIN chain list 2>/dev/null | grep -q "gateway"; then
        log "Creating Gateway chain..."
        $ZKSTACK_BIN chain create \
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
        
        $ZKSTACK_BIN chain init \
            --deploy-paymaster \
            --l1-rpc-url=http://127.0.0.1:$L1_RPC_PORT \
            --server-db-url=postgres://postgres:notsecurepassword@127.0.0.1:5432 \
            --server-db-name=zksync_server_127.0.0.1_gateway \
            --chain gateway --update-submodules false
    else
        log "Gateway chain already exists, skipping creation"
    fi
    
    # Convert to gateway and start
    $ZKSTACK_BIN chain gateway create-tx-filterer --chain gateway --ignore-prerequisites || true
    $ZKSTACK_BIN chain gateway convert-to-gateway --chain gateway --ignore-prerequisites
    $ZKSTACK_BIN dev config-writer --path etc/env/file_based/overrides/tests/gateway.yaml --chain gateway
    
    mkdir -p ./zruns
    $ZKSTACK_BIN server --ignore-prerequisites --chain gateway &> ./zruns/gateway.log &
    $ZKSTACK_BIN server wait --ignore-prerequisites --verbose --chain gateway
    
    wait_for_rpc "Gateway" "http://127.0.0.1:$GATEWAY_RPC_PORT"
    log "Gateway chain started successfully"
}

# Start Era chain
start_era() {
    log "Starting Era chain on port $ERA_RPC_PORT..."
    
    # Check if Era is already running
    if check_chainid "http://127.0.0.1:$ERA_RPC_PORT" >/dev/null 2>&1; then
        log "Era chain already running, skipping startup"
        return 0
    fi
    
    # Create Era chain if not exists
    if ! $ZKSTACK_BIN chain list 2>/dev/null | grep -q "era"; then
        log "Creating Era chain..."
        $ZKSTACK_BIN dev generate-genesis
        
        $ZKSTACK_BIN ecosystem init --deploy-paymaster --deploy-erc20 \
            --deploy-ecosystem --l1-rpc-url=http://127.0.0.1:$L1_RPC_PORT \
            --server-db-url=postgres://postgres:notsecurepassword@127.0.0.1:5432 \
            --server-db-name=zksync_server_127.0.0.1_era \
            --ignore-prerequisites --observability=false \
            --chain era \
            --update-submodules false
    else
        log "Era chain already exists, skipping creation"
    fi
    
    mkdir -p ./zruns
    $ZKSTACK_BIN server --ignore-prerequisites --chain era &> ./zruns/era.log &
    $ZKSTACK_BIN server wait --ignore-prerequisites --verbose --chain era
    
    wait_for_rpc "Era" "http://127.0.0.1:$ERA_RPC_PORT"
    log "Era chain started successfully"
}

# Start Era2 chain
start_era2() {
    log "Starting Era2 chain on port $ERA2_RPC_PORT..."
    
    # Check if Era2 is already running
    if check_chainid "http://127.0.0.1:$ERA2_RPC_PORT" >/dev/null 2>&1; then
        log "Era2 chain already running, skipping startup"
        return 0
    fi
    
    # Create Era2 chain if not exists (using validium as Era2)
    if ! $ZKSTACK_BIN chain list 2>/dev/null | grep -q "validium"; then
        log "Creating Era2 chain (validium)..."
        $ZKSTACK_BIN chain create \
            --chain-name validium \
            --chain-id 260 \
            --prover-mode no-proofs \
            --wallet-creation localhost \
            --l1-batch-commit-data-generator-mode validium \
            --base-token-address 0x0000000000000000000000000000000000000001 \
            --base-token-price-nominator 1 \
            --base-token-price-denominator 1 \
            --set-as-default false \
            --evm-emulator false \
            --ignore-prerequisites --update-submodules false
        
        $ZKSTACK_BIN chain init \
            --deploy-paymaster \
            --l1-rpc-url=http://127.0.0.1:$L1_RPC_PORT \
            --server-db-url=postgres://postgres:notsecurepassword@127.0.0.1:5432 \
            --server-db-name=zksync_server_127.0.0.1_validium \
            --chain validium --update-submodules false \
            --validium-type no-da
    else
        log "Era2 chain already exists, skipping creation"
    fi
    
    mkdir -p ./zruns
    $ZKSTACK_BIN server --ignore-prerequisites --chain validium &> ./zruns/validium.log &
    $ZKSTACK_BIN server wait --ignore-prerequisites --verbose --chain validium
    
    wait_for_rpc "Era2" "http://127.0.0.1:$ERA2_RPC_PORT"
    log "Era2 chain started successfully"
}

# Migrate L2 chains to Gateway
migrate_l2_to_gateway() {
    log "Migrating Era and Era2 to Gateway..."
    
    # Wait a bit for Gateway to be fully ready
    sleep 10
    
    # Migrate Era to Gateway
    log "Migrating Era to Gateway..."
    $ZKSTACK_BIN chain gateway migrate-to-gateway --chain era --gateway-chain-name gateway
    
    # Migrate Era2 (validium) to Gateway
    log "Migrating Era2 to Gateway..."
    $ZKSTACK_BIN chain gateway migrate-to-gateway --chain validium --gateway-chain-name gateway
    
    log "Migration to Gateway completed"
}

# Prefund developer account on all chains
prefund() {
    log "Prefunding developer account on all chains..."
    
    local dev_addr="$DEV_ADDR"
    local amount="${PREFUND_AMOUNT_ETH}ether"
    
    # Prefund on L1
    log "Prefunding L1..."
    cast send --private-key "$DEV_PK" --rpc-url "http://127.0.0.1:$L1_RPC_PORT" \
        --value "$amount" "$dev_addr" || warn "L1 prefunding failed or already funded"
    
    # Prefund on Gateway
    log "Prefunding Gateway..."
    cast send --private-key "$DEV_PK" --rpc-url "http://127.0.0.1:$GATEWAY_RPC_PORT" \
        --value "$amount" "$dev_addr" || warn "Gateway prefunding failed or already funded"
    
    # Prefund on Era
    log "Prefunding Era..."
    cast send --private-key "$DEV_PK" --rpc-url "http://127.0.0.1:$ERA_RPC_PORT" \
        --value "$amount" "$dev_addr" || warn "Era prefunding failed or already funded"
    
    # Prefund on Era2
    log "Prefunding Era2..."
    cast send --private-key "$DEV_PK" --rpc-url "http://127.0.0.1:$ERA2_RPC_PORT" \
        --value "$amount" "$dev_addr" || warn "Era2 prefunding failed or already funded"
    
    log "Prefunding completed"
}

# Wait for RPC to be ready
wait_for_rpc() {
    local name="$1"
    local url="$2"
    local max_attempts=30
    local attempt=1
    
    log "Waiting for $name RPC at $url..."
    
    while [ $attempt -le $max_attempts ]; do
        if check_chainid "$url" >/dev/null 2>&1; then
            log "$name RPC is ready"
            return 0
        fi
        
        if [ $attempt -eq 1 ]; then
            log "Waiting for $name RPC to start..."
        elif [ $((attempt % 5)) -eq 0 ]; then
            log "Still waiting for $name RPC... (attempt $attempt/$max_attempts)"
        fi
        
        sleep 2
        attempt=$((attempt + 1))
    done
    
    error "$name RPC failed to start within timeout"
    return 1
}

# Check chain ID via RPC
check_chainid() {
    local url="$1"
    cast rpc --rpc-url "$url" eth_chainId 2>/dev/null
}

# Check if code exists at specific address
check_code() {
    local url="$1"
    local address="$2"
    local code
    code=$(cast code "$address" --rpc-url "$url" 2>/dev/null || echo "0x")
    
    if [ "$code" != "0x" ] && [ ${#code} -gt 2 ]; then
        return 0
    else
        return 1
    fi
}

# Print running ports and status
print_ports() {
    echo
    echo "=== 4-Chain Interop Setup Status ==="
    echo
    
    # Check L1
    if check_chainid "http://127.0.0.1:$L1_RPC_PORT" >/dev/null 2>&1; then
        echo "L1 running on http://127.0.0.1:$L1_RPC_PORT"
    else
        echo "L1 NOT RUNNING on http://127.0.0.1:$L1_RPC_PORT"
    fi
    
    # Check Gateway
    if check_chainid "http://127.0.0.1:$GATEWAY_RPC_PORT" >/dev/null 2>&1; then
        echo "Gateway running on http://127.0.0.1:$GATEWAY_RPC_PORT"
    else
        echo "Gateway NOT RUNNING on http://127.0.0.1:$GATEWAY_RPC_PORT"
    fi
    
    # Check Era
    if check_chainid "http://127.0.0.1:$ERA_RPC_PORT" >/dev/null 2>&1; then
        echo "Era running on http://127.0.0.1:$ERA_RPC_PORT"
        
        # Check code at specific address
        if check_code "http://127.0.0.1:$ERA_RPC_PORT" "0x000000000000000000000000000000000001000b"; then
            echo "  ✓ Code verified at 0x000000000000000000000000000000000001000b"
        else
            echo "  ✗ No code found at 0x000000000000000000000000000000000001000b"
        fi
    else
        echo "Era NOT RUNNING on http://127.0.0.1:$ERA_RPC_PORT"
    fi
    
    # Check Era2
    if check_chainid "http://127.0.0.1:$ERA2_RPC_PORT" >/dev/null 2>&1; then
        echo "Era2 running on http://127.0.0.1:$ERA2_RPC_PORT"
    else
        echo "Era2 NOT RUNNING on http://127.0.0.1:$ERA2_RPC_PORT"
    fi
    
    echo "Dev account: $DEV_ADDR funded on all chains. The PK for dev account is $DEV_PK"
    echo
}

# Start all chains
start_all() {
    log "Starting 4-chain interop setup..."
    
    if ! check_prerequisites; then
        return 1
    fi
    
    # Start chains in order
    start_l1
    
    # Build contracts
    $ZKSTACK_BIN dev contracts
    
    start_era
    start_gateway
    start_era2
    
    # Migrate Era and Era2 to Gateway
    migrate_l2_to_gateway
    
    # Prefund developer account
    prefund
    
    # Final status check
    print_ports
    
    log "4-chain interop setup completed successfully!"
}

# Stop all chains
stop_all() {
    log "Stopping all chains..."
    
    # Kill all zksync_server processes
    pkill -9 zksync_server 2>/dev/null || true
    
    # Clean containers
    if command -v "$ZKSTACK_BIN" >/dev/null 2>&1; then
        $ZKSTACK_BIN dev clean containers 2>/dev/null || true
    fi
    
    # Clean up log directories
    rm -rf ./zruns 2>/dev/null || true
    
    log "All chains stopped and cleaned up"
}

# Show usage
usage() {
    echo "Usage: $0 [up|down|status]"
    echo
    echo "Commands:"
    echo "  up      - Start all four chains (L1, Gateway, Era, Era2) and configure interop"
    echo "  down    - Stop and clean up all chains"
    echo "  status  - Show current status and running ports"
    echo
    echo "Environment Variables:"
    echo "  L1_RPC_PORT=$L1_RPC_PORT"
    echo "  GATEWAY_RPC_PORT=$GATEWAY_RPC_PORT"
    echo "  ERA_RPC_PORT=$ERA_RPC_PORT"
    echo "  ERA2_RPC_PORT=$ERA2_RPC_PORT"
    echo "  DEV_PK=$DEV_PK"
    echo "  DEV_ADDR=$DEV_ADDR"
    echo "  PREFUND_AMOUNT_ETH=$PREFUND_AMOUNT_ETH"
    echo "  QUIET=$QUIET"
    echo "  ZKSTACK_BIN=$ZKSTACK_BIN"
}

# Main script logic
main() {
    case "${1:-}" in
        "up")
            if start_all; then
                exit 0
            else
                error "Failed to start interop setup"
                exit 1
            fi
            ;;
        "down")
            stop_all
            ;;
        "status")
            print_ports
            ;;
        "")
            # Default to "up" for backward compatibility
            if start_all; then
                exit 0
            else
                error "Failed to start interop setup"
                exit 1
            fi
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
