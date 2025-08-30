#!/bin/bash
set -euo pipefail
systemctl enable nextjs.service
systemctl restart nextjs.service
sleep 3
