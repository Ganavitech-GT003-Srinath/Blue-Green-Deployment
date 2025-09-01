#!/bin/bash
set -xe

# Install Node.js if missing
if ! command -v node >/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
  sudo apt-get install -y nodejs
fi

# Ensure CodeDeploy agent is running
sudo systemctl status codedeploy-agent || sudo systemctl start codedeploy-agent
