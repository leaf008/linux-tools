#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN} Linux Tools 网站恢复工具 v1.0${NC}"
echo -e "${GREEN}================================================${NC}"

echo ""

read -p "请输入网站目录: " SITE

if [ ! -d "$SITE" ]; then
    echo -e "${RED}网站目录不存在${NC}"
    exit
fi

echo ""
echo -e "${YELLOW}[1] 当前网站目录:${NC}"
echo "$SITE"

echo ""

read -p "请输入备份文件路径(.tar.gz): " BACKUP

if [ ! -f "$BACKUP" ]; then
    echo -e "${RED}备份文件不存在${NC}"
    exit
fi

echo ""
echo -e "${YELLOW}[2] 自动备份当前网站...${NC}"

NOW_BACKUP="/root/website_backup_$(date +%F_%H%M%S).tar.gz"

tar -czf "$NOW_BACKUP" "$SITE"

echo -e "${GREEN}当前网站已备份:${NC}"
echo "$NOW_BACKUP"

echo ""
echo -e "${YELLOW}[3] 开始恢复网站...${NC}"

rm -rf ${SITE:?}/*

tar -xzf "$BACKUP" -C "$SITE" --strip-components=1

echo -e "${GREEN}网站文件恢复完成${NC}"

echo ""
echo -e "${YELLOW}[4] 修复网站权限...${NC}"

chown -R www:www "$SITE"

find "$SITE" -type d -exec chmod 755 {} \;
find "$SITE" -type f -exec chmod 644 {} \;

echo -e "${GREEN}权限修复完成${NC}"

echo ""
echo -e "${YELLOW}[5] 重载Nginx...${NC}"

systemctl reload nginx

echo ""
echo -e "${YELLOW}[6] 重启PHP...${NC}"

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

echo ""
echo "已完成："
echo ""
echo "1. 自动备份当前网站"
echo "2. 自动恢复网站文件"
echo "3. 自动修复权限"
echo "4. 自动重载Nginx"
echo "5. 自动重启PHP"
echo ""
