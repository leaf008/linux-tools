#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear

echo -e "${GREEN}"
echo "================================================"
echo " Linux Tools 网站故障修复工具 v1.0"
echo "================================================"
echo -e "${NC}"

select_site() {
    SITES=($(find /www/wwwroot -maxdepth 1 -type d | grep -v "^/www/wwwroot$"))

    if [ ${#SITES[@]} -eq 0 ]; then
        echo -e "${RED}没有检测到网站目录${NC}"
        exit 1
    fi

    echo ""
    echo -e "${YELLOW}检测到以下网站：${NC}"
    echo ""

    INDEX=1

    for site in "${SITES[@]}"
    do
        DOMAIN=$(basename "$site")
        echo "$INDEX. $DOMAIN"
        INDEX=$((INDEX+1))
    done

    echo "0. 返回主菜单"
    echo ""

    read -p "请选择网站编号: " NUM

    if [ "$NUM" = "0" ]; then
        exit 0
    fi

    SITE=${SITES[$((NUM-1))]}

    if [ ! -d "$SITE" ]; then
        echo -e "${RED}网站不存在或编号错误${NC}"
        exit 1
    fi

    DOMAIN=$(basename "$SITE")
}

select_site

echo ""
echo -e "${BLUE}当前检测网站：${NC}$DOMAIN"
echo -e "${BLUE}网站目录：${NC}$SITE"
echo ""

echo -e "${YELLOW}[1] 检查网站目录${NC}"

if [ -d "$SITE" ]; then
    echo -e "${GREEN}网站目录存在：$SITE${NC}"
else
    echo -e "${RED}网站目录不存在${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}[2] 检查首页文件${NC}"

if [ -f "$SITE/index.php" ]; then
    echo -e "${GREEN}index.php 存在${NC}"
else
    echo -e "${RED}index.php 不存在，可能导致 403/404${NC}"
fi

if [ -f "$SITE/index.html" ]; then
    echo -e "${GREEN}index.html 存在${NC}"
else
    echo -e "${YELLOW}index.html 不存在${NC}"
fi

echo ""
echo -e "${YELLOW}[3] 检查网站权限${NC}"

ls -ld "$SITE"

echo ""
read -p "是否修复网站权限为 www:www + 755/644？(y/n): " FIX_PERM

if [ "$FIX_PERM" = "y" ]; then
    echo ""
    echo -e "${YELLOW}解除 .user.ini 保护${NC}"
    chattr -i "$SITE/.user.ini" 2>/dev/null

    echo -e "${YELLOW}修复权限中...${NC}"
    chown -R www:www "$SITE" 2>/dev/null
    find "$SITE" -type d -exec chmod 755 {} \;
    find "$SITE" -type f -exec chmod 644 {} \;

    echo -e "${GREEN}权限修复完成${NC}"
fi

echo ""
echo -e "${YELLOW}[4] 检查 Nginx 站点配置${NC}"

NGINX_CONF="/www/server/panel/vhost/nginx/${DOMAIN}.conf"

if [ -f "$NGINX_CONF" ]; then
    echo -e "${GREEN}Nginx配置存在：$NGINX_CONF${NC}"
else
    echo -e "${RED}Nginx配置不存在：$NGINX_CONF${NC}"
fi

echo ""
echo -e "${YELLOW}[5] 检查 rewrite 伪静态配置${NC}"

REWRITE_CONF="/www/server/panel/vhost/rewrite/${DOMAIN}.conf"

if [ -f "$REWRITE_CONF" ]; then
    echo -e "${GREEN}rewrite配置存在：$REWRITE_CONF${NC}"
    echo ""
    echo "当前 rewrite 内容："
    echo "--------------------------------"
    cat "$REWRITE_CONF"
    echo "--------------------------------"
else
    echo -e "${RED}rewrite配置不存在：$REWRITE_CONF${NC}"
fi

echo ""
read -p "是否写入 PbootCMS 推荐伪静态？(y/n): " FIX_REWRITE

if [ "$FIX_REWRITE" = "y" ]; then
    mkdir -p /www/server/panel/vhost/rewrite

    if [ -f "$REWRITE_CONF" ]; then
        cp -a "$REWRITE_CONF" "${REWRITE_CONF}.bak_$(date +%F_%H%M%S)"
    fi

    cat > "$REWRITE_CONF" << 'EOF'
location / {
    if (!-e $request_filename){
        rewrite ^/(.*)$ /index.php?p=$1 last;
    }
}
EOF

    echo -e "${GREEN}PbootCMS rewrite 已写入${NC}"
fi

echo ""
echo -e "${YELLOW}[6] 检查 PHP 引用配置${NC}"

if [ -f "$NGINX_CONF" ]; then
    PHP_INCLUDE=$(grep -E "enable-php-[0-9]+\.conf" "$NGINX_CONF" | head -n 1 | awk '{print $2}' | sed 's/;//')

    if [ -n "$PHP_INCLUDE" ]; then
        echo "检测到 PHP 引用：$PHP_INCLUDE"

        PHP_VERSION=$(echo "$PHP_INCLUDE" | grep -oE '[0-9]+')

        echo "PHP版本：$PHP_VERSION"

        PHP_CONF="/www/server/nginx/conf/enable-php-${PHP_VERSION}.conf"

        if [ -f "$PHP_CONF" ]; then
            echo -e "${GREEN}PHP配置存在：$PHP_CONF${NC}"
        else
            echo -e "${RED}PHP配置缺失：$PHP_CONF${NC}"

            read -p "是否自动创建 enable-php-${PHP_VERSION}.conf？(y/n): " CREATE_PHP_CONF

            if [ "$CREATE_PHP_CONF" = "y" ]; then
                cat > "$PHP_CONF" << EOF
location ~ [^/]\\.php(/|$)
{
    fastcgi_pass unix:/tmp/php-cgi-${PHP_VERSION}.sock;
    fastcgi_index index.php;
    include fastcgi.conf;
}
EOF
                echo -e "${GREEN}已创建：$PHP_CONF${NC}"
            fi
        fi

        SOCK="/tmp/php-cgi-${PHP_VERSION}.sock"

        echo ""
        echo -e "${YELLOW}检查 PHP sock：$SOCK${NC}"

        if [ -S "$SOCK" ]; then
            echo -e "${GREEN}PHP sock 存在${NC}"
        else
            echo -e "${RED}PHP sock 不存在，PHP-FPM可能没启动${NC}"

            if [ -f "/etc/init.d/php-fpm-${PHP_VERSION}" ]; then
                read -p "是否重启 PHP ${PHP_VERSION}？(y/n): " RESTART_PHP

                if [ "$RESTART_PHP" = "y" ]; then
                    /etc/init.d/php-fpm-${PHP_VERSION} restart
                fi
            fi
        fi
    else
        echo -e "${RED}没有检测到 enable-php 引用${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}[7] 检查 Nginx 语法${NC}"

nginx -t

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Nginx配置正常${NC}"
else
    echo -e "${RED}Nginx配置存在错误，请根据上方提示修复${NC}"
fi

echo ""
read -p "是否重载 Nginx？(y/n): " RELOAD_NGINX

if [ "$RELOAD_NGINX" = "y" ]; then
    nginx -t && systemctl reload nginx
fi

echo ""
echo -e "${YELLOW}[8] 查看网站错误日志${NC}"

LOG_FILE="/www/wwwlogs/${DOMAIN}.error.log"

if [ -f "$LOG_FILE" ]; then
    echo ""
    echo "最近 50 行错误日志："
    echo "--------------------------------"
    tail -50 "$LOG_FILE"
    echo "--------------------------------"
else
    echo -e "${RED}未找到错误日志：$LOG_FILE${NC}"
fi

echo ""
echo -e "${YELLOW}[9] 本地测试网站状态${NC}"

echo ""
echo "HTTP状态："
curl -I -m 10 "http://${DOMAIN}" 2>/dev/null | head -n 5

echo ""
echo "HTTPS状态："
curl -I -k -m 10 "https://${DOMAIN}" 2>/dev/null | head -n 5

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN} 网站故障检测/修复完成${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

read -p "按回车返回主菜单..."
exit 0
