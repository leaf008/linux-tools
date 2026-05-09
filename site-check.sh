#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

select_site() {

SITES=($(find /www/wwwroot -maxdepth 1 -type d | grep -v "^/www/wwwroot$"))

echo ""
echo "检测到以下网站："
echo ""

INDEX=1

for site in "${SITES[@]}"
do

DOMAIN=$(basename $site)

echo "$INDEX. $DOMAIN"

INDEX=$((INDEX+1))

done

echo ""

read -p "请选择网站编号: " NUM

SITE=${SITES[$((NUM-1))]}

if [ ! -d "$SITE" ]; then

echo "网站不存在"

exit

fi

DOMAIN=$(basename $SITE)

}

clear

echo "================================================"
echo " 网站巡检工具"
echo "================================================"

select_site

echo ""
echo "[1] DNS解析"

ping -c 1 "$DOMAIN"

echo ""
echo "[2] HTTP状态"

curl -I -m 10 "http://$DOMAIN"

echo ""
echo "[3] HTTPS状态"

curl -I -k -m 10 "https://$DOMAIN"

echo ""
echo "[4] 网站状态码"

curl -o /dev/null -s -w "%{http_code}\n" "https://$DOMAIN"

echo ""
echo "[5] SSL证书"

echo | openssl s_client -servername "$DOMAIN" -connect "${DOMAIN}:443" 2>/dev/null | openssl x509 -noout -dates

echo ""
echo "[6] 系统负载"

uptime

echo ""
echo "[7] 内存使用"

free -m

echo ""
echo "[8] 磁盘使用"

df -h
