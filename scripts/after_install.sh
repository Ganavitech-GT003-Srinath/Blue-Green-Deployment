#!/bin/bash
set -xe

cd /srv/nextjs || exit 1

# Install production dependencies
npm ci --only=production

# Copy systemd service and reload
if [ -f /srv/nextjs/systemd/nextjs.service ]; then
  sudo cp /srv/nextjs/systemd/nextjs.service /etc/systemd/system/nextjs.service
  sudo chmod 644 /etc/systemd/system/nextjs.service
  sudo systemctl daemon-reload
  sudo systemctl enable nextjs
fi

# Fix ownership
chown -R ubuntu:ubuntu /srv/nextjs
