#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "================================================"
echo " PHP 企业级安全加固工具"
echo "================================================"
echo -e "${NC}"

PHP_DIR="/www/server/php"

echo ""
echo -e "${YELLOW}[1] 扫描PHP版本${NC}"

ls $PHP_DIR

echo ""
echo -e "${YELLOW}[2] 开始自动加固${NC}"

for version in $(ls $PHP_DIR | grep -E '^[0-9]+$')

do

INI="$PHP_DIR/$version/etc/php.ini"

if [ -f "$INI" ]; then

echo ""
echo "正在加固 PHP $version"

cp -a $INI ${INI}.bak_$(date +%F_%H%M%S)

sed -i '/disable_functions/d' $INI

echo 'disable_functions = exec,passthru,shell_exec,system,proc_open,popen' >> $INI

sed -i '/display_errors/d' $INI

echo 'display_errors = Off' >> $INI

sed -i '/expose_php/d' $INI

echo 'expose_php = Off' >> $INI

sed -i '/open_basedir/d' $INI

echo 'open_basedir = /www/wwwroot/:/tmp/' >> $INI

fi

done

echo ""
echo -e "${YELLOW}[3] 重启PHP${NC}"

for version in $(ls $PHP_DIR | grep -E '^[0-9]+$')

do

if [ -f "/etc/init.d/php-fpm-$version" ]; then

/etc/init.d/php-fpm-$version restart

fi

done

echo ""
echo -e "${GREEN}PHP加固完成${NC}"
