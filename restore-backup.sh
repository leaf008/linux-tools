#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "================================================"
echo " Linux Tools 网站智能恢复工具 v2.3"
echo "================================================"
echo -e "${NC}"

BACKUP_DIR="/www/backup/site"

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}备份目录不存在：$BACKUP_DIR${NC}"
    read -p "按回车返回主菜单..."
    exit 0
fi

FILES=($(find "$BACKUP_DIR" -name "*.tar.gz" | sort -r))

if [ ${#FILES[@]} -eq 0 ]; then
    echo -e "${RED}没有检测到备份文件${NC}"
    read -p "按回车返回主菜单..."
    exit 0
fi

echo ""
echo -e "${YELLOW}检测到以下备份：${NC}"
echo ""

INDEX=1
for file in "${FILES[@]}"
do
    NAME=$(basename "$file")
    SIZE=$(du -sh "$file" | awk '{print $1}')
    echo "$INDEX. $NAME [$SIZE]"
    INDEX=$((INDEX+1))
done

echo "0. 返回主菜单"
echo ""

read -p "请选择备份编号: " BACKUP_NUM

if [ "$BACKUP_NUM" = "0" ]; then
    exit 0
fi

BACKUP_FILE=${FILES[$((BACKUP_NUM-1))]}

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}备份文件不存在或编号错误${NC}"
    read -p "按回车返回主菜单..."
    exit 0
fi

clear

echo -e "${GREEN}"
echo "================================================"
echo " Linux Tools 网站智能恢复工具 v2.3"
echo "================================================"
echo -e "${NC}"

echo ""
echo -e "${YELLOW}当前选择的备份：${NC}"
echo "$BACKUP_FILE"

echo ""
echo -e "${YELLOW}检测到以下网站：${NC}"
echo ""

SITES=($(find /www/wwwroot -maxdepth 1 -type d | grep -v "^/www/wwwroot$"))

INDEX=1
for site in "${SITES[@]}"
do
    DOMAIN=$(basename "$site")
    echo "$INDEX. $DOMAIN"
    INDEX=$((INDEX+1))
done

echo "0. 返回主菜单"
echo ""

read -p "请选择恢复网站编号: " SITE_NUM

if [ "$SITE_NUM" = "0" ]; then
    exit 0
fi

SITE=${SITES[$((SITE_NUM-1))]}

if [ ! -d "$SITE" ]; then
    echo -e "${RED}网站不存在或编号错误${NC}"
    read -p "按回车返回主菜单..."
    exit 0
fi

DOMAIN=$(basename "$SITE")

echo ""
echo -e "${RED}警告：即将恢复网站：$DOMAIN${NC}"
echo -e "${YELLOW}备份文件：$BACKUP_FILE${NC}"
echo -e "${RED}这个操作会覆盖当前网站文件。${NC}"
echo ""

read -p "确认恢复？输入 yes 继续: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "已取消"
    exit 0
fi

echo ""
echo -e "${YELLOW}[1] 恢复前备份当前网站${NC}"

mkdir -p /www/backup/restore_before

BEFORE_BACKUP="/www/backup/restore_before/${DOMAIN}_before_restore_$(date +%F_%H%M%S).tar.gz"

tar -C "$SITE" -czf "$BEFORE_BACKUP" .

echo "恢复前备份完成："
echo "$BEFORE_BACKUP"

echo ""
echo -e "${YELLOW}[2] 解压备份到临时目录${NC}"

TMP_DIR="/tmp/restore_${DOMAIN}_$(date +%s)"

mkdir -p "$TMP_DIR"

tar -xzf "$BACKUP_FILE" -C "$TMP_DIR"

if [ $? -ne 0 ]; then
    echo -e "${RED}备份包解压失败${NC}"
    rm -rf "$TMP_DIR"
    read -p "按回车返回主菜单..."
    exit 0
fi

echo ""
echo -e "${YELLOW}[3] 自动识别备份目录结构${NC}"

SOURCE_DIR=""

if [ -f "$TMP_DIR/index.php" ]; then
    SOURCE_DIR="$TMP_DIR"
elif [ -f "$TMP_DIR/www/wwwroot/$DOMAIN/index.php" ]; then
    SOURCE_DIR="$TMP_DIR/www/wwwroot/$DOMAIN"
elif [ -f "$TMP_DIR/www/wwwroot/$(basename "$SITE")/index.php" ]; then
    SOURCE_DIR="$TMP_DIR/www/wwwroot/$(basename "$SITE")"
else
    FOUND_INDEX=$(find "$TMP_DIR" -maxdepth 5 -name index.php | head -n 1)
    if [ -n "$FOUND_INDEX" ]; then
        SOURCE_DIR=$(dirname "$FOUND_INDEX")
    fi
fi

if [ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}没有找到可恢复的网站根目录 index.php${NC}"
    echo "临时目录：$TMP_DIR"
    read -p "按回车返回主菜单..."
    exit 0
fi

echo "识别到网站文件目录："
echo "$SOURCE_DIR"

echo ""
echo -e "${YELLOW}[4] 解除 .user.ini 保护${NC}"

chattr -i "$SITE/.user.ini" 2>/dev/null

echo ""
echo -e "${YELLOW}[5] 清空当前网站目录${NC}"

find "$SITE" -mindepth 1 -maxdepth 1 -exec rm -rf {} \;

echo ""
echo -e "${YELLOW}[6] 恢复网站文件${NC}"

cp -a "$SOURCE_DIR"/. "$SITE"/

if [ $? -ne 0 ]; then
    echo -e "${RED}文件复制失败${NC}"
    read -p "按回车返回主菜单..."
    exit 0
fi

echo ""
echo -e "${YELLOW}[7] 修复权限${NC}"

chattr -i "$SITE/.user.ini" 2>/dev/null

chown -R www:www "$SITE" 2>/dev/null

find "$SITE" -type d -exec chmod 755 {} \;
find "$SITE" -type f -exec chmod 644 {} \;

echo ""
echo -e "${YELLOW}[8] 重载 Nginx${NC}"

nginx -t && systemctl reload nginx

echo ""
echo -e "${YELLOW}[9] 重启 PHP${NC}"

for version in $(ls /www/server/php/ 2>/dev/null | grep -E '^[0-9]+$')
do
    if [ -f "/etc/init.d/php-fpm-$version" ]; then
        /etc/init.d/php-fpm-$version restart
        echo "PHP $version 已重启"
    fi
done

echo ""
echo -e "${YELLOW}[10] 清理临时目录${NC}"

rm -rf "$TMP_DIR"

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN} 网站恢复完成${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

read -p "按回车返回主菜单..."
exit 0
