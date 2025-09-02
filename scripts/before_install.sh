#!/bin/bash
set -xe

# Ensure the application directory exists
APP_DIR="/srv/nextjs"
mkdir -p "$APP_DIR"
chown -R ubuntu:ubuntu "$APP_DIR" || true

# Check if Node.js is installed; install if missing
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js not found. Installing Node.js 18.x..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get install -y nodejs
fi

# Clean old application files to prepare for fresh deployment
if [ -d "$APP_DIR" ]; then
  echo "Cleaning existing files in $APP_DIR..."
  rm -rf "$APP_DIR"/* || true
fi

# Ensure proper ownership after cleanup
chown -R ubuntu:ubuntu "$APP_DIR"
