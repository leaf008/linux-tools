#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "================================================="
echo " PbootCMS 企业级安全巡检工具 v3.2"
echo "================================================="
echo -e "${NC}"

read -p "请输入网站目录: " SITE

if [ ! -d "$SITE" ]; then
    echo -e "${RED}目录不存在！${NC}"
    exit
fi

QUARANTINE="/root/quarantine_$(date +%F_%H%M%S)"

mkdir -p "$QUARANTINE"

echo ""
echo -e "${BLUE}[1/10] 扫描高危木马...${NC}"

find "$SITE" -name "*.php" \
-not -path "*/runtime/*" \
-not -path "*/cache/*" \
-not -path "*/node_modules/*" \
| xargs grep -lE 'assert\(\$_POST|eval\(\$_POST|system\(\$_GET|shell_exec\(\$_GET|passthru\(\$_POST' \
> /tmp/high_risk.txt

HIGH_COUNT=$(wc -l < /tmp/high_risk.txt)

echo -e "${RED}高危文件数量:${NC} $HIGH_COUNT"

cat /tmp/high_risk.txt

echo ""
echo -e "${BLUE}[2/10] 扫描中危可疑函数...${NC}"

find "$SITE" -name "*.php" \
-not -path "*/runtime/*" \
-not -path "*/cache/*" \
-not -path "*/node_modules/*" \
| xargs grep -lE 'base64_decode|eval\(|shell_exec|system\(|exec\(' \
> /tmp/mid_risk.txt

MID_COUNT=$(wc -l < /tmp/mid_risk.txt)

echo -e "${YELLOW}中危文件数量:${NC} $MID_COUNT"

cat /tmp/mid_risk.txt

echo ""
echo -e "${BLUE}[3/10] 检测上传目录PHP...${NC}"

find "$SITE/static/upload" -name "*.php" 2>/dev/null

echo ""
echo -e "${BLUE}[4/10] 检测伪装图片木马...${NC}"

find "$SITE" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.gif" \) \
| xargs grep -l "<?php" 2>/dev/null

echo ""
echo -e "${BLUE}[5/10] 检测最近7天新增PHP...${NC}"

find "$SITE" -name "*.php" \
-not -path "*/runtime/*" \
-not -path "*/cache/*" \
-mtime -7

echo ""
echo -e "${BLUE}[6/10] 检测 index.php 挂马...${NC}"

grep -nE 'eval\(|assert\(|shell_exec|system\(' \
"$SITE/index.php" 2>/dev/null

echo ""
echo -e "${BLUE}[7/10] 检测777权限文件...${NC}"

find "$SITE" -type f -perm 777

echo ""
echo -e "${BLUE}[8/10] 是否隔离高危文件？(y/n)${NC}"

read CHOOSE

if [ "$CHOOSE" = "y" ]; then

while read -r file
do
    if [ -f "$file" ]; then

        mkdir -p "$QUARANTINE$(dirname "$file")"

        mv "$file" "$QUARANTINE$file"

        echo -e "${RED}已隔离:${NC} $file"

    fi

done < /tmp/high_risk.txt

fi

echo ""
echo -e "${BLUE}[9/10] 修复网站权限...${NC}"

find "$SITE" -type d -exec chmod 755 {} \;
find "$SITE" -type f -exec chmod 644 {} \;

echo ""
echo -e "${BLUE}[10/10] 输出检测结果...${NC}"

echo ""
echo -e "${GREEN}=================================================${NC}"

echo -e "${RED}高危文件:${NC}"
cat /tmp/high_risk.txt

echo ""
echo -e "${YELLOW}中危文件:${NC}"
cat /tmp/mid_risk.txt

echo ""
echo -e "${GREEN}隔离目录:${NC} $QUARANTINE"

echo ""
echo -e "${GREEN}检测完成${NC}"

echo ""
echo "说明："
echo "1. 高危文件建议人工确认"
echo "2. 本工具默认不删除文件"
echo "3. 中危文件可能存在误报"
echo "4. runtime/cache 已自动排除"
echo ""
