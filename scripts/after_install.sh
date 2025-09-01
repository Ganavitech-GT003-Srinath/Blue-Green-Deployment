#!/bin/bash
set -xe

cd /srv/nextjs

# Install Node dependencies
npm ci --only=production

# Install and enable systemd service
sudo cp systemd/nextjs.service /etc/systemd/system/nextjs.service
sudo systemctl daemon-reload
sudo systemctl enable nextjs
