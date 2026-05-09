#!/bin/bash

clear

echo "================================"
echo " WordPress 安全检测工具"
echo "================================"

read -p "请输入WordPress目录: " SITE

if [ ! -d "$SITE" ]; then
    echo "目录不存在"
    exit
fi

echo ""
echo "[1] 检测 uploads PHP文件"
find "$SITE/wp-content/uploads" -name "*.php" 2>/dev/null

echo ""
echo "[2] 检测危险函数"
find "$SITE" -name "*.php" | xargs grep -lE 'eval\(|base64_decode|shell_exec|assert\('

echo ""
echo "[3] 检测管理员账号"
grep "DB_USER" "$SITE/wp-config.php"

echo ""
echo "[4] 检测777权限"
find "$SITE" -type f -perm 777

echo ""
echo "检测完成"
