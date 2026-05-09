#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "================================================="
echo " PbootCMS 企业级安全巡检工具 v3.1"
echo "================================================="
echo -e "${NC}"

read -p "请输入网站目录: " SITE

if [ ! -d "$SITE" ]; then
    echo -e "${RED}目录不存在！${NC}"
    exit
fi

QUARANTINE="/root/quarantine_$(date +%F_%H%M%S)"

mkdir -p $QUARANTINE

echo ""
echo -e "${BLUE}[1/10] 扫描高危木马...${NC}"

find $SITE -name "*.php" \
-not -path "*/runtime/*" \
-not -path "*/cache/*" \
-not -path "*/node_modules/*" \
| xargs grep -lE "assert\(\$_POST|eval\(\$_POST|system\(\$_GET|shell_exec\(\$_GET|passthru\(\$_POST" \
> /tmp/high_risk.txt

HIGH_COUNT=$(cat /tmp/high_risk.txt | wc -l)

echo -e "${RED}高危文件数量:${NC} $HIGH_COUNT"

cat /tmp/high_risk.txt

echo ""
echo -e "${BLUE}[2/10] 扫描中危可疑函数...${NC}"

find $SITE -name "*.php" \
-not -path "*/runtime
