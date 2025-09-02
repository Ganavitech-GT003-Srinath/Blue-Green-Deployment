#!/bin/bash
set -xe

APP_DIR="/srv/nextjs"

# Ensure directory exists
mkdir -p "$APP_DIR"
chown -R ubuntu:ubuntu "$APP_DIR"

# Install Node.js 18 if missing
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js not found. Installing Node.js 18.x..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get install -y nodejs
fi

# Clean old application files but preserve scripts/ and appspec.yml
rm -rf "$APP_DIR/.next" "$APP_DIR/app" "$APP_DIR/package.json" "$APP_DIR/package-lock.json" || true
chown -R ubuntu:ubuntu "$APP_DIR"
