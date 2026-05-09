#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "================================================"
echo " Linux Tools 网站恢复工具 v2.0"
echo "================================================"
echo -e "${NC}"

BACKUP_DIR="/www/backup/site"

FILES=($(find $BACKUP_DIR -name "*.tar.gz"))

if [ ${#FILES[@]} -eq 0 ]; then

    echo -e "${RED}没有检测到备份文件${NC}"

    exit

fi

echo ""
echo "检测到以下备份："
echo ""

INDEX=1

for file in "${FILES[@]}"
do

    NAME=$(basename $file)

    SIZE=$(du -sh $file | awk '{print $1}')

    echo "$INDEX. $NAME [$SIZE]"

    INDEX=$((INDEX+1))

done

echo ""

read -p "请选择备份编号: " NUM

BACKUP_FILE=${FILES[$((NUM-1))]}

if [ ! -f "$BACKUP_FILE" ]; then

    echo -e "${RED}备份不存在${NC}"

    exit

fi

echo ""
echo "检测网站目录..."
echo ""

SITES=($(find /www/wwwroot -maxdepth 1 -type d | grep -v "^/www/wwwroot$"))

INDEX=1

for site in "${SITES[@]}"
do

    DOMAIN=$(basename $site)

    echo "$INDEX. $DOMAIN"

    INDEX=$((INDEX+1))

done

echo ""

read -p "请选择恢复网站编号: " NUM

SITE=${SITES[$((NUM-1))]}

if [ ! -d "$SITE" ]; then

    echo -e "${RED}网站不存在${NC}"

    exit

fi

DOMAIN=$(basename $SITE)

echo ""
echo -e "${YELLOW}开始恢复网站:${NC}"
echo "$DOMAIN"

echo ""

mkdir -p /www/backup/restore_before

tar -czf /www/backup/restore_before/${DOMAIN}_before_restore_$(date +%F_%H%M%S).tar.gz $SITE

rm -rf ${SITE:?}/*

tar -xzf $BACKUP_FILE -C /

chown -R www:www $SITE

echo ""

echo -e "${GREEN}恢复成功${NC}"

echo ""
```
