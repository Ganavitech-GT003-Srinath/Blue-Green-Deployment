#!/bin/bash
set -euo pipefail

# Wait for app to respond on health endpoint
RETRIES=30
SLEEP=2

for i in $(seq 1 $RETRIES); do
  if curl -fsS http://localhost:3000/api/health >/dev/null; then
    echo "Service healthy"
    exit 0
  fi
  echo "Waiting service for... ($i/$RETRIES)"
  sleep $SLEEP
done

echo "Service failed health check"
exit 1