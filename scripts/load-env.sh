#!/bin/bash
set -euo pipefail

echo "=== Loading environment from SSM Parameter Store ==="

SSM_PATH="${1:-/my-app/production/}"
ENV_FILE="${2:-/opt/app/.env}"

PARAMETERS=$(aws ssm get-parameters-by-path \
  --path "$SSM_PATH" \
  --with-decryption \
  --query 'Parameters[].{Name:Name,Value:Value}' \
  --output json 2>/dev/null)

if [ -z "$PARAMETERS" ] || [ "$PARAMETERS" = "[]" ]; then
  echo "WARNING: No parameters found at path: $SSM_PATH"
  exit 1
fi

echo "$PARAMETERS" | jq -r '.[] | "\(.Name | split("/") | last)=\"\(.Value)\""' > "$ENV_FILE"

PARAM_COUNT=$(echo "$PARAMETERS" | jq length)
echo "Loaded $PARAM_COUNT parameters to $ENV_FILE"

echo "--- Loaded variables ---"
cat "$ENV_FILE" | sed 's/\(PASSWORD\|SECRET\|TOKEN\|KEY\)=.*/\1=****/' | sort
