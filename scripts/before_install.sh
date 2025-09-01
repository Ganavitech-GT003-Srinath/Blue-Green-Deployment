#!/bin/bash
set -xe

# Ensure directory exists and ownership
mkdir -p /srv/nextjs
chown -R ubuntu:ubuntu /srv/nextjs || true

# Ensure Node available before any npm operations (but assume user-data installs Node)
# If Node missing, try installing quickly (best-effort)
if ! command -v node >/dev/null 2>&1; then
  echo "Node not found; attempting quick install"
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get install -y nodejs
fi

# Clean old app files (CodeDeploy will copy new files into /srv/nextjs)
rm -rf /srv/nextjs/* || true
