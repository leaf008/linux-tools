#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

QUARANTINE="/www/quarantine"

mkdir -p $QUARANTINE

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
echo " PbootCMS 企业级安全检测工具 v3.0"
echo "================================================"
echo -e "${NC}"

select_site

echo ""
echo -e "${YELLOW}[1] 扫描高危木马${NC}"

MALWARE=$(find "$SITE" -name "*.php" \
| grep -v "/runtime/" \
| grep -v "/template/" \
| xargs grep -lE 'eval\(|assert\(|base64_decode\(|shell_exec\(|system\(' 2>/dev/null)

COUNT=$(echo "$MALWARE" | grep -c ".php")

echo ""
echo "发现高危文件数量: $COUNT"

echo ""

echo "$MALWARE"

echo ""

if [ "$COUNT" -gt 0 ]; then

read -p "是否自动隔离? (y/n): " SAFE

if [ "$SAFE" = "y" ]; then

TIME=$(date +%F_%H%M%S)

mkdir -p "$QUARANTINE/$DOMAIN-$TIME"

echo ""

echo -e "${YELLOW}开始隔离...${NC}"

for file in $MALWARE
do

cp -a "$file" "$QUARANTINE/$DOMAIN-$TIME/"

rm -f "$file"

echo "已隔离: $file"

done

echo ""
echo -e "${GREEN}隔离完成${NC}"

echo ""
echo "隔离目录:"
echo "$QUARANTINE/$DOMAIN-$TIME"

fi

fi

echo ""
echo -e "${YELLOW}[2] 扫描上传目录PHP${NC}"

find "$SITE" -path "*/upload/*" -name "*.php"

echo ""
echo -e "${YELLOW}[3] 扫描伪装图片木马${NC}"

find "$SITE" -regex '.*\.\(jpg\|png\|gif\)\.php$'

echo ""
echo -e "${YELLOW}[4] 扫描最近7天新增PHP${NC}"

find "$SITE" -name "*.php" \
-mtime -7 \
| grep -v "/runtime/" \
| grep -v "/compile/" \
| grep -v "/cache/"

echo ""
echo -e "${GREEN}检测完成${NC}"
