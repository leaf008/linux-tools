#!/bin/bash

clear

echo "================================"
echo " 网站巡检工具"
echo "================================"

read -p "请输入域名: " DOMAIN

echo ""
echo "[1] DNS解析"
ping -c 1 $DOMAIN

echo ""
echo "[2] HTTP状态"
curl -I -m 10 http://$DOMAIN

echo ""
echo "[3] HTTPS状态"
curl -I -k -m 10 https://$DOMAIN

echo ""
echo "[4] 网站状态码"
curl -o /dev/null -s -w "%{http_code}\n" https://$DOMAIN

echo ""
echo "[5] SSL证书"
echo | openssl s_client -servername $DOMAIN -connect ${DOMAIN}:443 2>/dev/null | openssl x509 -noout -dates

echo ""
echo "[6] 服务器负载"
uptime

echo ""
echo "[7] 内存使用"
free -m

echo ""
echo "[8] 磁盘使用"
df -h

echo ""
echo "完成"
