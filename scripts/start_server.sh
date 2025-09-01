#!/bin/bash
set -xe

cd /srv/nextjs

# Install dependencies (in case they aren't there)
npm ci --only=production

# Start service
sudo systemctl daemon-reload
sudo systemctl enable nextjs
sudo systemctl restart nextjs
