#!/bin/bash

# Script për deployment në VPS
# Përdorim: ./deploy.sh

echo "🚀 Duke filluar deployment..."

# Variablat - Ndrysho këto
VPS_IP="your_vps_ip"
VPS_USER="root"
DEPLOY_PATH="/var/www/signals_backend"

# Ngjyrat për output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}📦 Duke upload-uar file-at në VPS...${NC}"
scp -r ./* ${VPS_USER}@${VPS_IP}:${DEPLOY_PATH}/

echo -e "${YELLOW}🔧 Duke instaluar dependencat...${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOF'
cd /var/www/signals_backend
source venv/bin/activate
pip install -r requirements.txt
EOF

echo -e "${YELLOW}🔄 Duke restartuar service...${NC}"
ssh ${VPS_USER}@${VPS_IP} "systemctl restart signals-api"

echo -e "${YELLOW}📊 Duke kontrolluar statusin...${NC}"
ssh ${VPS_USER}@${VPS_IP} "systemctl status signals-api --no-pager"

echo -e "${GREEN}✅ Deployment u kompletua!${NC}"
echo -e "${GREEN}API është duke punuar në: http://${VPS_IP}:8000${NC}"
