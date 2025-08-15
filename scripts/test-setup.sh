#!/bin/bash

set -e

echo "Testing multi-chain docker-compose setup..."

# Start base services first
echo "Starting base services (L1 and PostgreSQL)..."
docker compose -f docker-compose-multichain.yml up -d reth postgres

# Wait a bit for services to start
sleep 10

# Test L1 connectivity
echo "Testing L1 connectivity..."
if curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
    http://localhost:8545 | grep -q '"result"'; then
    echo "✓ L1 (Reth) is accessible"
else
    echo "✗ L1 (Reth) is not accessible"
    exit 1
fi

# Test PostgreSQL connectivity  
echo "Testing PostgreSQL connectivity..."
if docker compose -f docker-compose-multichain.yml exec -T postgres pg_isready -U postgres; then
    echo "✓ PostgreSQL is accessible"
else
    echo "✗ PostgreSQL is not accessible"
    exit 1
fi

echo "Base services test completed successfully!"
echo ""
echo "To start the full multi-chain setup, run:"
echo "docker compose -f docker-compose-multichain.yml up"