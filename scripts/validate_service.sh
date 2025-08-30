#!/bin/bash
set -euo pipefail
# try 10 times waiting for service to respond
for i in {1..10}; do
  if curl -sS -f http://localhost:3000/api/health >/dev/null 2>&1; then
    echo "Service healthy"
    exit 0
  else
    echo "Waiting for service... ($i)"
    sleep 6
  fi
done
echo "Service failed to respond on /api/health"
exit 1
