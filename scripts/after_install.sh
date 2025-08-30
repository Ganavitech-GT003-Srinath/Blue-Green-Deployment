#!/bin/bash
set -euo pipefail

APP_DIR=/srv/nextjs
cd $APP_DIR

# If using SSM for runtime env, fetch and write .env.production
SSM_PREFIX="/prod/nextjs"
REGION="ap-south-1"
if aws ssm get-parameters-by-path --path "$SSM_PREFIX" --with-decryption --region "$REGION" >/dev/null 2>&1; then
  echo "Rendering SSM parameters to .env.production"
  aws ssm get-parameters-by-path --path "$SSM_PREFIX" --with-decryption --region "$REGION" \
    | jq -r '.Parameters[] | "\(.Name)=\(.Value)"' | while IFS= read -r line; do
      KEY=$(echo "$line" | sed -E "s|$SSM_PREFIX/([^=]+)=.*|\1|")
      VAL=$(echo "$line" | sed -E "s|$SSM_PREFIX/[^=]+=||")
      echo "$KEY=$VAL" >> .env.production
    done
  chown ubuntu:ubuntu .env.production || true
fi

# Install production dependencies
npm ci --omit=dev

# Ensure systemd unit file is in place
cp -r systemd/nextjs.service /etc/systemd/system/nextjs.service || true
systemctl daemon-reload
