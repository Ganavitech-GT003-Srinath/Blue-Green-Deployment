#!/usr/bin/env bash
set -euo pipefail

# Only run if both variables are provided
if [ -n "${SSM_PREFIX:-}" ] && [ -n "${REGION:-}" ]; then
  # Best-effort: don’t fail the build if command fails
  PARAMS="$(aws ssm get-parameters-by-path --path "$SSM_PREFIX" --with-decryption --region "$REGION" 2>/dev/null || true)"
  if [ -n "$PARAMS" ]; then
    # Convert SSM parameters to KEY=VALUE lines and write .env.production
    echo "$PARAMS" | jq -r '.Parameters[] | "\(.Name)=\(.Value)"' \
      | sed -E "s|$SSM_PREFIX/([^=]+)=|\1=|" > .env.production
    echo "Wrote .env.production"
  fi
fi