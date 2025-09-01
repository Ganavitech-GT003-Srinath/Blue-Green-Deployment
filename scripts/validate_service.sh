#!/bin/bash
set -xe

# Wait up to 60s for the app to respond
for i in {1..12}; do
  if curl -sf http://localhost:3000/api/health >/dev/null; then
    echo "Health check passed"
    exit 0
  else
    echo "Health check try $i failed, sleeping..."
    sleep 5
  fi
done

# one last try to capture body
curl -v http://localhost:3000/api/health || true

echo "Health check failed after retries."
exit 1
