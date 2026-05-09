#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "================================================"
echo " PHP 企业级安全加固工具 v2.0"
echo "================================================"
echo -e "${NC}"

PHP_DIR="/www/server/php"

if [ ! -d "$PHP_DIR" ]; then
    echo -e "${RED}未找到宝塔PHP目录${NC}"
    exit
fi

echo ""
echo -e "${YELLOW}[1] 扫描PHP版本...${NC}"
echo ""

ls $PHP_DIR

echo ""
echo -e "${YELLOW}[2] 开始自动加固...${NC}"
echo ""

for version in $(ls $PHP_DIR | grep -E '^[0-9]+$')

do

INI="$PHP_DIR/$version/etc/php.ini"

if [ -f "$INI" ]; then

echo ""
echo -e "${GREEN}正在加固 PHP $version${NC}"

cp -a $INI ${INI}.bak_$(date +%F_%H%M%S)

echo "已备份 php.ini"

sed -i '/disable_functions/d' $INI

echo 'disable_functions = exec,passthru,shell_exec,system,proc_open,popen,pcntl_exec' >> $INI

sed -i '/expose_php/d' $INI

echo 'expose_php = Off' >> $INI

sed -i '/display_errors/d' $INI

echo 'display_errors = Off' >> $INI

sed -i '/open_basedir/d' $INI

echo 'open_basedir = /www/wwwroot/:/tmp/' >> $INI

echo -e "${GREEN}PHP $version 加固完成${NC}"

fi

done

echo ""
echo -e "${YELLOW}[3] 重启PHP服务...${NC}"
echo ""

for version in $(ls $PHP_DIR | grep -E '^[0-9]+$')

do

if [ -f "/etc/init.d/php-fpm-$version" ]; then

/etc/init.d/php-fpm-$version restart

echo "PHP $version 已重启"

fi

done

echo ""
echo -e "${GREEN}================================================"
echo " PHP 安全加固完成"
echo "================================================"
echo -e "${NC}"

echo ""
echo "已完成："
echo ""
echo "1. 关闭危险函数"
echo "2. 隐藏PHP版本"
echo "3. 关闭错误显示"
echo "4. 开启 open_basedir"
echo "5. 自动备份 php.ini"
echo "6. 自动重启 PHP"
echo ""
