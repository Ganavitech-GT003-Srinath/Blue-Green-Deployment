#!/bin/bash
set -xe

# stop service if running
systemctl stop nextjs || true

# Start the service (systemd-managed)
systemctl start nextjs

# Give the app a few seconds to start
sleep 3
