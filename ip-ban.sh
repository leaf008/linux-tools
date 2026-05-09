#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_DIR="/www/wwwlogs"
BAN_LIST="/root/linux-tools-banned-ips.txt"
TMP_ALL="/tmp/linux_tools_all_ips.txt"
TMP_BAD="/tmp/linux_tools_bad_ips.txt"

clear

echo -e "${GREEN}"
echo "================================================"
echo " Linux Tools 高频扫描 IP 封禁工具 v1.0"
echo "================================================"
echo -e "${NC}"

touch "$BAN_LIST"

get_my_ip() {
    SSH_IP=$(echo "$SSH_CLIENT" | awk '{print $1}')
    if [ -n "$SSH_IP" ]; then
        echo "$SSH_IP"
    fi
}

ban_ip() {
    IP=$1

    if grep -q "^$IP$" "$BAN_LIST"; then
        echo -e "${YELLOW}已封禁过：$IP${NC}"
        return
    fi

    MY_IP=$(get_my_ip)

    if [ "$IP" = "$MY_IP" ]; then
        echo -e "${RED}跳过当前 SSH 登录 IP，避免把自己封掉：$IP${NC}"
        return
    fi

    if command -v ufw >/dev/null 2>&1; then
        ufw deny from "$IP"
        echo "$IP" >> "$BAN_LIST"
        echo -e "${GREEN}已通过 ufw 封禁：$IP${NC}"

    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$IP' reject"
        firewall-cmd --reload
        echo "$IP" >> "$BAN_LIST"
        echo -e "${GREEN}已通过 firewalld 封禁：$IP${NC}"

    elif command -v iptables >/dev/null 2>&1; then
        iptables -C INPUT -s "$IP" -j DROP 2>/dev/null || iptables -I INPUT -s "$IP" -j DROP
        echo "$IP" >> "$BAN_LIST"
        echo -e "${GREEN}已通过 iptables 封禁：$IP${NC}"

    else
        echo -e "${RED}未检测到 ufw/firewalld/iptables，无法自动封禁：$IP${NC}"
    fi
}

unban_ip() {
    IP=$1

    if command -v ufw >/dev/null 2>&1; then
        ufw delete deny from "$IP" 2>/dev/null
    fi

    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' source address='$IP' reject" 2>/dev/null
        firewall-cmd --reload 2>/dev/null
    fi

    if command -v iptables >/dev/null 2>&1; then
        while iptables -C INPUT -s "$IP" -j DROP 2>/dev/null
        do
            iptables -D INPUT -s "$IP" -j DROP
        done
    fi

    sed -i "/^$IP$/d" "$BAN_LIST"

    echo -e "${GREEN}已解除封禁：$IP${NC}"
}

scan_all_high_freq() {
    echo ""
    echo -e "${YELLOW}正在统计高频访问 IP...${NC}"
    echo ""

    > "$TMP_ALL"

    if [ ! -d "$LOG_DIR" ]; then
        echo -e "${RED}日志目录不存在：$LOG_DIR${NC}"
        return
    fi

    # access log：IP一般在第一列
    grep -hEo '^([0-9]{1,3}\.){3}[0-9]{1,3}' "$LOG_DIR"/*.log 2>/dev/null >> "$TMP_ALL"

    # error log：IP一般在 client: 后面
    grep -hEo 'client: ([0-9]{1,3}\.){3}[0-9]{1,3}' "$LOG_DIR"/*.error.log 2>/dev/null | awk '{print $2}' >> "$TMP_ALL"

    echo ""
    echo -e "${BLUE}访问次数最多的前 30 个 IP：${NC}"
    echo ""

    sort "$TMP_ALL" | uniq -c | sort -rn | head -30
}

scan_bad_paths() {
    echo ""
    echo -e "${YELLOW}正在扫描可疑攻击路径 IP...${NC}"
    echo ""

    > "$TMP_BAD"

    PATTERN="\.env|app_dev\.php|phpinfo|wp-login\.php|xmlrpc\.php|server-status|/console|/vendor/phpunit|/\.git|/config/parameters|/actuator|/boaform|/shell|/cmd|/eval|/login\.action"

    grep -hEi "$PATTERN" "$LOG_DIR"/*.log "$LOG_DIR"/*.error.log 2>/dev/null | \
    grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' >> "$TMP_BAD"

    echo ""
    echo -e "${BLUE}可疑扫描 IP 排行：${NC}"
    echo ""

    sort "$TMP_BAD" | uniq -c | sort -rn | head -30
}

auto_ban_high_freq() {
    read -p "请输入访问次数阈值，默认 100: " LIMIT

    if [ -z "$LIMIT" ]; then
        LIMIT=100
    fi

    scan_all_high_freq

    echo ""
    echo -e "${YELLOW}将封禁访问次数 >= $LIMIT 的 IP${NC}"
    echo ""

    read -p "确认封禁？输入 yes 继续: " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        echo "已取消"
        return
    fi

    sort "$TMP_ALL" | uniq -c | sort -rn | while read COUNT IP
    do
        if [ "$COUNT" -ge "$LIMIT" ]; then
            ban_ip "$IP"
        fi
    done
}

auto_ban_bad_paths() {
    read -p "请输入可疑路径扫描次数阈值，默认 5: " LIMIT

    if [ -z "$LIMIT" ]; then
        LIMIT=5
    fi

    scan_bad_paths

    echo ""
    echo -e "${YELLOW}将封禁可疑扫描次数 >= $LIMIT 的 IP${NC}"
    echo ""

    read -p "确认封禁？输入 yes 继续: " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        echo "已取消"
        return
    fi

    sort "$TMP_BAD" | uniq -c | sort -rn | while read COUNT IP
    do
        if [ "$COUNT" -ge "$LIMIT" ]; then
            ban_ip "$IP"
        fi
    done
}

while true
do
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN} 高频扫描 IP 封禁菜单${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo " 1. 查看高频访问 IP"
    echo " 2. 查看可疑扫描 IP"
    echo " 3. 自动封禁高频访问 IP"
    echo " 4. 自动封禁可疑扫描 IP"
    echo " 5. 查看已封禁 IP"
    echo " 6. 手动封禁 IP"
    echo " 7. 解除封禁 IP"
    echo " 0. 返回主菜单"
    echo ""

    read -p "请输入数字: " NUM

    case "$NUM" in

    1)
        scan_all_high_freq
        read -p "按回车继续..."
        ;;

    2)
        scan_bad_paths
        read -p "按回车继续..."
        ;;

    3)
        auto_ban_high_freq
        read -p "按回车继续..."
        ;;

    4)
        auto_ban_bad_paths
        read -p "按回车继续..."
        ;;

    5)
        echo ""
        echo -e "${YELLOW}已封禁 IP 列表：${NC}"
        echo ""
        cat "$BAN_LIST"
        read -p "按回车继续..."
        ;;

    6)
        read -p "请输入要封禁的 IP: " IP
        if [ -n "$IP" ]; then
            ban_ip "$IP"
        fi
        read -p "按回车继续..."
        ;;

    7)
        read -p "请输入要解除封禁的 IP: " IP
        if [ -n "$IP" ]; then
            unban_ip "$IP"
        fi
        read -p "按回车继续..."
        ;;

    0)
        exit 0
        ;;

    *)
        echo -e "${RED}输入错误${NC}"
        sleep 1
        ;;

    esac

    clear
done
