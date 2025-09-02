#!/bin/bash
set -xe

# Wait up to 60 seconds for health endpoint
for i in {1..12}; do
  if curl -sf http://127.0.0.1:3000/api/health >/dev/null; then
    echo "Health check passed"
    exit 0
  else
    echo "Health check attempt $i failed. Retrying..."
    sleep 5
  fi
done

# Last attempt to debug
curl -v http://127.0.0.1:3000/api/health || true
echo "Health check failed after retries."
exit 1
