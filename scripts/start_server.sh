#!/bin/bash
cd /srv/nextjs
echo "Starting Next.js service..."

# Ensure systemd service file exists
SERVICE_FILE=/etc/systemd/system/nextjs.service

if [ ! -f "$SERVICE_FILE" ]; then
  echo "Creating systemd service file..."
  sudo tee $SERVICE_FILE > /dev/null <<EOL
[Unit]
Description=Next.js SSR App
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/srv/nextjs
ExecStart=/usr/bin/env PORT=3000 HOST=0.0.0.0 /usr/bin/npm run start
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOL
fi

# Reload systemd and start service
sudo systemctl daemon-reload
sudo systemctl enable nextjs
sudo systemctl restart nextjs
