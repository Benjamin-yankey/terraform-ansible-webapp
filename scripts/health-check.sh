#!/bin/bash
# Health check script for Task Manager application

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get IP from terraform or evidence
if [ -f "terraform/terraform.tfstate" ]; then
    IP=$(cd terraform && terraform output -raw public_ip 2>/dev/null)
else
    IP=$(cat evidence/public_ip.txt 2>/dev/null || echo "")
fi

if [ -z "$IP" ]; then
    echo -e "${RED}✗ No IP address found${NC}"
    exit 1
fi

echo "Checking health of: $IP"
echo "================================"

# Check backend API
echo -n "Backend API: "
if curl -sf "http://$IP:5000/api/health" > /dev/null; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${RED}✗ Down${NC}"
fi

# Check frontend
echo -n "Frontend: "
if curl -sf "http://$IP" > /dev/null; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${RED}✗ Down${NC}"
fi

# Check Nginx proxy
echo -n "API Proxy: "
if curl -sf "http://$IP/api/health" > /dev/null; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${RED}✗ Down${NC}"
fi

# Get stats
echo ""
echo "Statistics:"
curl -s "http://$IP/api/stats" | jq '.' 2>/dev/null || echo "Unable to fetch stats"
