#!/bin/bash
set -euo pipefail

echo "=== Rolling back to previous release ==="

APP_DIR="/opt/app"
RELEASE_DIR="$APP_DIR/releases"
CURRENT_LINK="$APP_DIR/current"

if [ ! -L "$CURRENT_LINK" ]; then
  echo "ERROR: No current deployment found"
  exit 1
fi

CURRENT_RELEASE=$(readlink -f "$CURRENT_LINK")
echo "Current release: $CURRENT_RELEASE"

PREVIOUS_RELEASE=$(ls -1dt "$RELEASE_DIR"/*/ 2>/dev/null | head -2 | tail -1 | sed 's:/$::')

if [ -z "$PREVIOUS_RELEASE" ] || [ "$PREVIOUS_RELEASE" = "$CURRENT_RELEASE" ]; then
  echo "ERROR: No previous release available for rollback"
  exit 1
fi

echo "Rolling back to: $PREVIOUS_RELEASE"

ln -sfn "$PREVIOUS_RELEASE" "$CURRENT_LINK"

cd "$CURRENT_LINK"
pm2 reload ecosystem.config.js --env production

sleep 5

if curl -sf http://localhost:3000/health > /dev/null 2>&1; then
  echo "Rollback SUCCESSFUL"
  echo "Health check passed"
  pm2 save
else
  echo "ERROR: Rollback health check failed!"
  exit 1
fi
