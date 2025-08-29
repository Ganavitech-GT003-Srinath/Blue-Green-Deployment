#!/bin/bash
set -euo pipefail

cd /srv/nextjs

# Install deps and build as 'ubuntu'
sudo -u ubuntu npm ci
sudo -u ubuntu npm run build

# Ensure scripts are executable (after files are copied)
chmod +x /srv/nextjs/scripts/*.sh || true

# Install/refresh systemd unit
cp /srv/nextjs/systemd/nextjs.service /etc/systemd/system/nextjs.service
systemctl daemon-reload
