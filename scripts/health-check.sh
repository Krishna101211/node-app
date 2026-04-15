#!/bin/bash
set -euo pipefail

HEALTH_URL="${1:-http://localhost:3000/health}"
MAX_RETRIES="${2:-5}"
RETRY_INTERVAL="${3:-3}"

echo "=== Health Check ==="
echo "URL: $HEALTH_URL"
echo "Max retries: $MAX_RETRIES"
echo "Interval: ${RETRY_INTERVAL}s"

RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  RESPONSE=$(curl -sf -w "\n%{http_code}" "$HEALTH_URL" 2>/dev/null || echo -e "\n000")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" = "200" ]; then
    STATUS=$(echo "$BODY" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
    echo "PASS - HTTP $HTTP_CODE | Status: $STATUS | Attempt: $((RETRY_COUNT + 1))/$MAX_RETRIES"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    exit 0
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "FAIL - HTTP $HTTP_CODE | Attempt: $RETRY_COUNT/$MAX_RETRIES"
  sleep "$RETRY_INTERVAL"
done

echo "FAILED - Health check did not pass after $MAX_RETRIES attempts"
exit 1
