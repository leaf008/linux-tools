#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "================================================"
echo " Linux Tools 网站备份工具 v2.0"
echo "================================================"
echo -e "${NC}"

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

BACKUP_DIR="/www/backup/site"

mkdir -p $BACKUP_DIR

DOMAIN=$(basename $SITE)

TIME=$(date +%F_%H%M%S)

FILE="$BACKUP_DIR/${DOMAIN}_${TIME}.tar.gz"

echo ""
echo -e "${YELLOW}开始备份网站:${NC}"
echo "$DOMAIN"

echo ""

tar -czf "$FILE" "$SITE"

if [ $? -eq 0 ]; then

echo -e "${GREEN}备份成功:${NC}"
echo "$FILE"

else

echo -e "${RED}备份失败${NC}"

fi

echo ""
echo -e "${YELLOW}当前备份目录:${NC}"
echo "$BACKUP_DIR"

echo ""
ls -lh $BACKUP_DIR
