#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Basic tools
apt-get update -y
apt-get install -y curl ca-certificates gnupg

# Install Node.js 20 (NodeSource APT)
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v)" != v20* ]]; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  NODE_MAJOR=20
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
  apt-get update -y
  apt-get install -y nodejs
fi

# Application directory
mkdir -p /srv/nextjs
chown -R ubuntu:ubuntu /srv/nextjs

# Ensure scripts will be executable after copy
chmod +x /srv/nextjs/scripts/*.sh 2>/dev/null || true
