#!/bin/bash
echo "Stopping existing Next.js service if running..."
sudo systemctl stop nextjs || true
sudo pkill -f "npm run start" || true
