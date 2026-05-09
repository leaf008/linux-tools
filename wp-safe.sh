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
echo " WordPress 安全检测工具"
echo "================================================"

select_site

echo ""
echo "[1] 检测管理员"

find "$SITE/wp-content" -name "*.php"

echo ""
echo "[2] 检测木马"

find "$SITE" -name "*.php" | xargs grep -lE 'eval\(|assert\('

echo ""
echo "[3] 检测上传目录"

find "$SITE/wp-content/uploads" -name "*.php"

echo ""
echo "检测完成"
