#!/bin/bash

clear

echo "================================"
echo " PHP 安全加固工具"
echo "================================"

echo ""
echo "[1] 检测PHP版本"
php -v

echo ""
echo "[2] 检测危险函数"
php -i | grep disable_functions

echo ""
echo "[3] 检测open_basedir"
php -i | grep open_basedir

echo ""
echo "[4] PHP-FPM状态"
ps -ef | grep php-fpm

echo ""
echo "[5] 修复session目录权限"
chmod -R 733 /tmp

echo ""
echo "完成"
