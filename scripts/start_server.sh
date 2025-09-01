#!/bin/bash
set -xe

# Move to app directory
cd /srv/nextjs

# Start or restart service
sudo systemctl daemon-reload
sudo systemctl enable nextjs
sudo systemctl restart nextjs
