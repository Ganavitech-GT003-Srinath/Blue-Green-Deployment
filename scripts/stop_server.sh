#!/bin/bash
set -euo pipefail

echo "🛑 Stopping Next.js service..."
systemctl stop nextjs.service || true
