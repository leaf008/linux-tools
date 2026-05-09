#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

while true
do

clear

echo -e "${GREEN}"
echo "================================================"
echo " Linux Tools 企业级安全工具箱 v1.0"
echo "================================================"
echo -e "${NC}"

echo " 1. PbootCMS安全检测"
echo " 2. WordPress安全检测"
echo " 3. 宝塔安全修复"
echo " 4. Nginx修复"
echo " 5. PHP安全加固"
echo " 6. 网站巡检"
echo " 0. 退出"
echo ""

read -p "请输入数字: " num

case "$num" in

1)

echo ""
echo -e "${YELLOW}启动 PbootCMS 安全检测...${NC}"
echo ""

bash <(curl -fsSL https://raw.githubusercontent.com/leaf008/linux-tools/main/pboot-safe.sh)

read -p "按回车返回菜单..."

;;

2)

echo ""
echo -e "${YELLOW}启动 WordPress 安全检测...${NC}"
echo ""

bash <(curl -fsSL https://raw.githubusercontent.com/leaf008/linux-tools/main/wp-safe.sh)

read -p "按回车返回菜单..."

;;

3)

echo ""
echo -e "${YELLOW}启动 宝塔安全修复...${NC}"
echo ""

bash <(curl -fsSL https://raw.githubusercontent.com/leaf008/linux-tools/main/bt-safe.sh)

read -p "按回车返回菜单..."

;;

4)

echo ""
echo -e "${YELLOW}启动 Nginx 修复...${NC}"
echo ""

bash <(curl -fsSL https://raw.githubusercontent.com/leaf008/linux-tools/main/nginx-fix.sh)

read -p "按回车返回菜单..."

;;

5)

echo ""
echo -e "${YELLOW}启动 PHP 安全加固...${NC}"
echo ""

bash <(curl -fsSL https://raw.githubusercontent.com/leaf008/linux-tools/main/php-safe.sh)

read -p "按回车返回菜单..."

;;

6)

echo ""
echo -e "${YELLOW}启动 网站巡检...${NC}"
echo ""

bash <(curl -fsSL https://raw.githubusercontent.com/leaf008/linux-tools/main/site-check.sh)

read -p "按回车返回菜单..."

;;

0)

echo ""
echo -e "${RED}退出工具箱${NC}"
echo ""

exit 0

;;

*)

echo ""
echo -e "${RED}输入错误${NC}"
echo ""

sleep 1

;;

esac

done
