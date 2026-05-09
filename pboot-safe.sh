#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "======================================="
echo " PbootCMS 一键安全检测/查杀工具"
echo "======================================="
echo -e "${NC}"

read -p "请输入网站目录: " SITE

if [ ! -d "$SITE" ]; then
    echo -e "${RED}目录不存在${NC}"
    exit
fi

BACKUP="/root/webshell_backup_$(date +%F_%H%M%S)"

mkdir -p $BACKUP

echo ""
echo -e "${YELLOW}[1/8] 扫描危险函数...${NC}"

find $SITE -name "*.php" | xargs grep -lE "eval\(|base64_decode|shell_exec|assert\(|system\(|passthru|exec\(" > /tmp/webshell.txt

COUNT=$(cat /tmp/webshell.txt | wc -l)

echo -e "${GREEN}发现可疑文件数量:${NC} $COUNT"

echo ""
echo -e "${YELLOW}[2/8] 扫描上传目录PHP...${NC}"

find $SITE/static/upload -name "*.php"

echo ""
echo -e "${YELLOW}[3/8] 扫描伪装图片木马...${NC}"

find $SITE -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.gif" \) | xargs grep -l "<?php"

echo ""
echo -e "${YELLOW}[4/8] 扫描最近7天新增PHP...${NC}"

find $SITE -name "*.php" -mtime -7

echo ""
echo -e "${YELLOW}[5/8] 备份可疑文件...${NC}"

while read file
do
    if [ -f "$file" ]; then
        cp -a $file $BACKUP/
    fi
done < /tmp/webshell.txt

echo -e "${GREEN}备份完成:${NC} $BACKUP"

echo ""
echo -e "${YELLOW}[6/8] 是否自动删除危险文件？(y/n)${NC}"

read CHOOSE

if [ "$CHOOSE" = "y" ]; then

while read file
do
    rm -f "$file"
    echo -e "${RED}已删除:${NC} $file"
done < /tmp/webshell.txt

fi

echo ""
echo -e "${YELLOW}[7/8] 修复权限...${NC}"

find $SITE -type d -exec chmod 755 {} \;
find $SITE -type f -exec chmod 644 {} \;

echo ""
echo -e "${YELLOW}[8/8] 检查完成${NC}"

echo ""
echo -e "${GREEN}======================================="
echo " 安全检测结束"
echo "======================================="
echo -e "${NC}"
