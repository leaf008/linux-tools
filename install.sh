#!/bin/bash

clear

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

while true

do

clear

echo -e "${GREEN}"
echo "================================"
echo " Linux Tools 安全工具箱 v1.0"
echo "================================"
echo -e "${NC}"

echo "1. PbootCMS安全检测"
echo "2. WordPress安全检测"
echo "3. 宝塔安全修复"
echo "4. Nginx修复"
echo "5. PHP安全加固"
echo "6. 网站巡检"
echo "0. 退出"
echo ""

read -p "请输入数字: " num

case "$num" in

1)
bash <(curl -fsSL https://raw.githubusercontent.com/leaf008/linux-tools/main/pboot-safe.sh)
read -p "按回车继续..."
;;

2)
bash <(curl -fsSL https://raw.githubusercontent.com/leaf008/linux-tools/main/wp-safe.sh)
read -p "按回车继续..."
;;

3)
bash <(curl -fsSL https://raw.githubusercontent.com/leaf008/linux-tools/main/bt-safe.sh)
read -p "按回车继续..."
;;

4)
bash <(curl -fsSL https://raw.githubusercontent.com/leaf008/linux-tools/main/nginx-fix.sh)
read -p "按回车继续..."
;;

5)
bash <(curl -fsSL https://raw.githubusercontent.com/leaf008/linux-tools/main/php-safe.sh)
read -p "按回车继续..."
;;

6)
bash <(curl -fsSL https://raw.githubusercontent.com/leaf008/linux-tools/main/site-check.sh)
read -p "按回车继续..."
done
