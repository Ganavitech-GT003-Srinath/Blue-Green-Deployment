#!/bin/bash
set -euo pipefail

# update and install required packages
apt-get update -y
apt-get install -y curl gnupg jq build-essential

# Install Node 18 LTS (NodeSource)
if ! node -v | grep -q '^v18' 2>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get install -y nodejs
fi

# Install aws cli v2 (if you'll use aws in scripts)
if ! command -v aws >/dev/null 2>&1; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  apt-get install -y unzip
  unzip /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
fi
