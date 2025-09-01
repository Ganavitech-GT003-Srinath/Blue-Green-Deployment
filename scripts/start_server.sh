# #!/bin/bash
# set -euo pipefail
# systemctl enable nextjs.service
# systemctl restart nextjs.service
# sleep 3

#!/bin/bash
cd /srv/nextjs
npm install --production
npm run build
pm2 start npm --name "nextjs" -- start
pm2 save
