#!/bin/bash
set -euo pipefail

APP_DIR="/opt/app"
RELEASE_DIR="$APP_DIR/releases"
CURRENT_LINK="$APP_DIR/current"
LOG_DIR="$APP_DIR/logs"
BUILD_ARTIFACT="/tmp/build-artifact.zip"
S3_BUCKET="my-app-build-artifacts"
VERSION="$1"

if [ -z "$VERSION" ]; then
  echo "ERROR: Usage: $0 <build-version>"
  echo "Example: $0 abc1234-20260415120000"
  exit 1
fi

echo "=== Deploying version: $VERSION ==="
echo "Timestamp: $(date)"

OLD_RELEASE=""
if [ -L "$CURRENT_LINK" ]; then
  OLD_RELEASE=$(readlink -f "$CURRENT_LINK")
  echo "Current release: $OLD_RELEASE"
fi

echo "[1/8] Downloading artifact from S3..."
aws s3 cp "s3://$S3_BUCKET/builds/$VERSION/artifact.zip" "$BUILD_ARTIFACT"

if [ ! -f "$BUILD_ARTIFACT" ]; then
  echo "ERROR: Failed to download artifact"
  exit 1
fi

echo "[2/8] Creating release directory..."
RELEASE_PATH="$RELEASE_DIR/$VERSION-$(date +%Y%m%d%H%M%S)"
mkdir -p "$RELEASE_PATH"

echo "[3/8] Extracting artifact..."
unzip -q "$BUILD_ARTIFACT" -d "$RELEASE_PATH"

echo "[4/8] Installing production dependencies..."
cd "$RELEASE_PATH"
export NVM_DIR="/home/ec2-user/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
npm ci --only=production --silent

echo "[5/8] Loading environment from SSM..."
if command -v aws &> /dev/null; then
  PARAMETERS=$(aws ssm get-parameters-by-path \
    --path /my-app/production/ \
    --with-decryption \
    --query 'Parameters[].{Name:Name,Value:Value}' \
    --output json 2>/dev/null || echo "[]")

  if [ "$PARAMETERS" != "[]" ]; then
    echo "$PARAMETERS" | jq -r '.[] | "\(.Name | split("/") | last)=\"\(.Value)\""' > "$RELEASE_PATH/.env"
    echo "Environment loaded from SSM Parameter Store"
  fi
fi

echo "[6/8] Switching to new release (atomic symlink)..."
ln -sfn "$RELEASE_PATH" "$CURRENT_LINK"
echo "Symlink: $CURRENT_LINK -> $RELEASE_PATH"

echo "[7/8] Reloading PM2 process..."
cd "$CURRENT_LINK"
if pm2 describe my-app > /dev/null 2>&1; then
  pm2 reload ecosystem.config.js --env production
  echo "PM2 process reloaded (zero-downtime)"
else
  pm2 start ecosystem.config.js --env production
  echo "PM2 process started"
fi
pm2 save

echo "[8/8] Running post-deploy health check..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -sf http://localhost:3000/health > /dev/null 2>&1; then
    echo "Health check PASSED (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Health check attempt $RETRY_COUNT/$MAX_RETRIES failed, retrying in 2s..."
  sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: Health check failed after $MAX_RETRIES attempts!"
  echo "Rolling back to previous release..."
  if [ -n "$OLD_RELEASE" ] && [ -d "$OLD_RELEASE" ]; then
    ln -sfn "$OLD_RELEASE" "$CURRENT_LINK"
    pm2 reload ecosystem.config.js --env production
    echo "Rollback to $OLD_RELEASE complete"
  else
    echo "WARNING: No previous release available for rollback"
  fi
  exit 1
fi

echo "[Cleanup] Removing old releases (keeping last 5)..."
cd "$RELEASE_DIR"
ls -1dt */ 2>/dev/null | tail -n +6 | xargs rm -rf 2>/dev/null || true

rm -f "$BUILD_ARTIFACT"

echo ""
echo "=== Deployment of version $VERSION COMPLETE ==="
echo "Release path: $RELEASE_PATH"
echo "Active symlink: $(readlink -f $CURRENT_LINK)"
