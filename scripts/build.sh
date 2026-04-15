#!/bin/bash
set -euo pipefail

echo "=== Building application ==="
echo "Timestamp: $(date)"
echo "Node: $(node --version)"
echo "NPM: $(npm --version)"

echo "[1/4] Cleaning previous build..."
rm -rf dist/ build-output/

echo "[2/4] Installing dependencies..."
npm ci --production=false

echo "[3/4] Running lint..."
npm run lint:ci

echo "[4/4] Running tests..."
npm run test

echo "[5/5] Building..."
npm run build

echo ""
echo "=== Build Complete ==="
echo "Output: dist/"
ls -la dist/ 2>/dev/null || echo "No dist/ directory (server-side app)"
