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
echo "================================================"
echo " Linux Tools 网站恢复工具 v2.0"
echo "================================================"
echo -e "${NC}"

select_site

echo ""
echo -e "${YELLOW}[1] 当前网站:${NC}"
echo "$DOMAIN"

echo ""

read -p "请输入备份文件路径(.tar.gz): " BACKUP

if [ ! -f "$BACKUP" ]; then

echo -e "${RED}备份文件不存在${NC}"

exit

fi

echo ""
echo -e "${YELLOW}[2] 自动备份当前网站${NC}"

NOW_BACKUP="/root/website_backup_$(date +%F_%H%M%S).tar.gz"

tar -czf "$NOW_BACKUP" "$SITE"

echo ""
echo "当前网站已备份:"
echo "$NOW_BACKUP"

echo ""
echo -e "${YELLOW}[3] 开始恢复网站${NC}"

rm -rf ${SITE:?}/*

tar -xzf "$BACKUP" -C "$SITE" --strip-components=1

echo ""
echo -e "${GREEN}网站文件恢复完成${NC}"

echo ""
echo -e "${YELLOW}[4] 修复权限${NC}"

chown -R www:www "$SITE"

find "$SITE" -type d -exec chmod 755 {} \;
find "$SITE" -type f -exec chmod 644 {} \;

echo ""
echo -e "${YELLOW}[5] 重载Nginx${NC}"

systemctl reload nginx

echo ""
echo -e "${YELLOW}[6] 重启PHP${NC}"

for version in $(ls /www/server/php/ | grep -E '^[0-9]+$')
do

if [ -f "/etc/init.d/php-fpm-$version" ]; then

/etc/init.d/php-fpm-$version restart

echo "PHP $version 已重启"

fi

done

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN} 网站恢复完成${NC}"
echo -e "${GREEN}================================================${NC}"
