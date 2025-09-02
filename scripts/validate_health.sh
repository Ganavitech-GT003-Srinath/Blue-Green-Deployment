#!/bin/bash
echo "Validating Next.js health..."
for i in {1..10}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/api/health)
  if [ "$STATUS" == "200" ]; then
    echo "Next.js is healthy!"
    exit 0
  else
    echo "Waiting for Next.js to be ready... ($i/10)"
    sleep 5
  fi
done
echo "Next.js did not become healthy in time."
exit 1
