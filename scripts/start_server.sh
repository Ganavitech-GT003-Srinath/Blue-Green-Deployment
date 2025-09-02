#!/bin/bash
set -xe

# Start systemd service
sudo systemctl start nextjs

# Wait a few seconds for service to initialize
sleep 5
