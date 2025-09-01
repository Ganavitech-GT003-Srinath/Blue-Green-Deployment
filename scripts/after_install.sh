#!/bin/bash
set -xe

# Move to application directory in case files are staged elsewhere (CodeDeploy uses destination /srv/nextjs)
cd /srv/nextjs || exit 1

# Install production dependencies (fresh)
npm ci --only=production

# Copy systemd unit to system and reload
if [ -f /srv/nextjs/systemd/nextjs.service ]; then
  cp /srv/nextjs/systemd/nextjs.service /etc/systemd/system/nextjs.service
  chmod 644 /etc/systemd/system/nextjs.service
  systemctl daemon-reload
  systemctl enable nextjs
fi

# ensure ownership so service (ubuntu) can read files
chown -R ubuntu:ubuntu /srv/nextjs || true
