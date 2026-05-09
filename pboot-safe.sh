#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "================================================="
echo " PbootCMS 企业级安全检测/查杀工具 v2.0"
echo "================================================="
echo -e "${NC}"

read -p "请输入网站目录: " SITE

if [ ! -d "$SITE" ]; then
    echo -e "${RED}目录不存在！${NC}"
    exit
fi

BACKUP="/root/webshell_backup_$(date +%F_%H%M%S)"

mkdir -p $BACKUP

echo ""
echo -e "${BLUE}[1/10] 检测危险函数...${NC}"

find $SITE -name "*.php" \
-not -path "*/runtime/*" \
-not -path "*/cache/*" \
-not -path "*/node_modules/*" \
| xargs grep -lE "eval\(|base64_decode|shell_exec|assert\(|system\(|passthru|exec\(|phpinfo\(" \
> /tmp/webshell.txt

COUNT=$(cat /tmp/webshell.txt | wc -l)

echo -e "${GREEN}发现可疑文件数量:${NC} $COUNT"

cat /tmp/webshell.txt

echo ""
echo -e "${BLUE}[2/10] 检测上传目录PHP木马...${NC}"

find $SITE/static/upload -name "*.php" 2>/dev/null

echo ""
echo -e "${BLUE}[3/10] 检测伪装图片木马...${NC}"

find $SITE -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.gif" \) \
| xargs grep -l "<?php" 2>/dev/null

echo ""
echo -e "${BLUE}[4/10] 检测最近7天新增PHP（已排除runtime缓存）...${NC}"

find $SITE -name "*.php" \
-not -path "*/runtime/*" \
-not -path "*/cache/*" \
-mtime -7

echo ""
echo -e "${BLUE}[5/10] 检测隐藏webshell...${NC}"

find $SITE -name "*.php" \
-not -path "*/runtime/*" \
| xargs grep -l "error_reporting(0)" 2>/dev/null

echo ""
echo -e "${BLUE}[6/10] 检测 index.php 挂马...${NC}"

grep -nE "eval\(|base64_decode|assert\(|shell_exec|system\(" \
$SITE/index.php 2>/dev/null

echo ""
echo -e "${BLUE}[7/10] 检测可疑权限777文件...${NC}"

find $SITE -type f -perm 777

echo ""
echo -e "${BLUE}[8/10] 备份可疑文件...${NC}"

while read file
do
    if [ -f "$file" ]; then
        cp -a "$file" $BACKUP/
    fi
done < /tmp/webshell.txt

echo -e "${GREEN}备份完成:${NC} $BACKUP"

echo ""
echo -e "${BLUE}[9/10] 是否自动删除危险文件？(y/n)${NC}"

read CHOOSE

if [ "$CHOOSE" = "y" ]; then

while read file
do
    rm -f "$file"
    echo -e "${RED}已删除:${NC} $file"
done < /tmp/webshell.txt

fi

echo ""
echo -e "${BLUE}[10/10] 修复网站权限...${NC}"

find $SITE -type d -exec chmod 755 {} \;
find $SITE -type f -exec chmod 644 {} \;

echo ""
echo -e "${GREEN}"
echo "================================================="
echo " 安全检测完成"
echo "================================================="
echo -e "${NC}"

echo ""
echo -e "${YELLOW}建议后续操作:${NC}"
echo "1. 禁止 upload 目录执行 PHP"
echo "2. 定期备
