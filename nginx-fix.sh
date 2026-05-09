#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "================================"
echo " Nginx 修复工具"
echo "================================"
echo -e "${NC}"

echo ""
echo -e "${YELLOW}[1] 检测配置${NC}"

nginx -t

echo ""
echo -e "${YELLOW}[2] 检测80/443端口${NC}"

ss -lntp | grep -E '80|443'

echo ""
echo -e "${YELLOW}[3] 重载Nginx${NC}"

systemctl reload nginx

echo ""
echo -e "${YELLOW}[4] 检测状态${NC}"

systemctl status nginx --no-pager

echo ""
echo -e "${YELLOW}[5] 网站日志${NC}"

ls /www/wwwlogs

echo ""
echo -e "${GREEN}检测完成${NC}"
