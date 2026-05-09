#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

select_site() {

SITES=($(find /www/wwwroot -maxdepth 1 -type d | grep -v "^/www/wwwroot$"))

echo ""
echo -e "${YELLOW}检测到以下网站:${NC}"
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

echo -e "${RED}网站不存在${NC}"

exit

fi

DOMAIN=$(basename $SITE)

}

clear

echo -e "${GREEN}"
echo "================================"
echo " 宝塔安全修复工具 v2.0"
echo "================================"
echo -e "${NC}"

echo ""
echo -e "${YELLOW}[1] 检查Fail2ban${NC}"
systemctl status fail2ban --no-pager

echo ""
echo -e "${YELLOW}[2] 检查SSH爆破${NC}"
lastb | head

echo ""
echo -e "${YELLOW}[3] 检查计划任务${NC}"
crontab -l

echo ""
echo -e "${YELLOW}[4] 检查异常进程${NC}"
ps aux --sort=-%cpu | head

echo ""
echo -e "${YELLOW}[5] 检查恶意端口${NC}"
ss -lntp

echo ""
echo -e "${YELLOW}[6] 检查木马文件${NC}"
find /www/wwwroot -name "*.php" | xargs grep -lE 'eval\(|assert\('

echo ""
echo -e "${YELLOW}[7] 修复网站权限${NC}"

select_site

chown -R www:www "$SITE"

echo ""
echo -e "${GREEN}权限修复完成:${NC}"
echo "$DOMAIN"

echo ""
echo -e "${GREEN}安全巡检完成${NC}"
