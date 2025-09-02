#!/bin/bash
set -xe

# Stop the service if it exists
if systemctl is-active --quiet nextjs; then
  systemctl stop nextjs
fi
