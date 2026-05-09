#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BASE_DIR="/opt/linux-tools/monitor"
CONFIG_FILE="$BASE_DIR/telegram.conf"
SITE_FILE="$BASE_DIR/sites.txt"
STATE_FILE="$BASE_DIR/state.txt"
LOG_FILE="$BASE_DIR/monitor.log"
INTERVAL_FILE="$BASE_DIR/interval.conf"
LOCAL_SCRIPT="/opt/linux-tools/site-monitor.sh"
CRON_FILE="/etc/cron.d/linux-tools-site-monitor"

mkdir -p "$BASE_DIR"

send_tg() {
    MSG="$1"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Telegram 未配置"
        return
    fi

    source "$CONFIG_FILE"

    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        echo "Telegram Token 或 Chat ID 为空"
        return
    fi

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        --data-urlencode text="$MSG" >/dev/null 2>&1
}

get_status() {
    URL="$1"

    CODE=$(curl -k -L -m 15 -o /dev/null -s -w "%{http_code}" "$URL")

    if [ -z "$CODE" ]; then
        CODE="000"
    fi

    echo "$CODE"
}

is_ok_code() {
    CODE="$1"

    case "$CODE" in
        200|201|202|204|301|302|304)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

get_old_state() {
    URL="$1"

    if [ ! -f "$STATE_FILE" ]; then
        echo "UNKNOWN"
        return
    fi

    grep "^$URL|" "$STATE_FILE" | tail -n 1 | awk -F'|' '{print $2}'
}

set_state() {
    URL="$1"
    STATE="$2"

    TMP_FILE="/tmp/linux_tools_monitor_state.tmp"

    touch "$STATE_FILE"

    grep -v "^$URL|" "$STATE_FILE" > "$TMP_FILE"

    echo "$URL|$STATE" >> "$TMP_FILE"

    mv "$TMP_FILE" "$STATE_FILE"
}

get_interval() {
    if [ -f "$INTERVAL_FILE" ]; then
        source "$INTERVAL_FILE"
    fi

    if [ -z "$CHECK_INTERVAL" ]; then
        CHECK_INTERVAL=10
    fi

    echo "$CHECK_INTERVAL"
}

run_monitor() {
    if [ ! -f "$SITE_FILE" ]; then
        echo "$(date '+%F %T') 未配置监控网站" >> "$LOG_FILE"
        exit 0
    fi

    while read -r URL
    do
        if [ -z "$URL" ]; then
            continue
        fi

        CODE=$(get_status "$URL")
        OLD_STATE=$(get_old_state "$URL")

        NOW_TIME=$(date '+%F %T')

        if is_ok_code "$CODE"; then
            echo "$NOW_TIME OK $URL HTTP:$CODE" >> "$LOG_FILE"

            if [ "$OLD_STATE" = "DOWN" ]; then
                send_tg "✅ 网站已恢复正常

网站：$URL
状态码：$CODE
时间：$NOW_TIME"
            fi

            set_state "$URL" "OK"

        else
            echo "$NOW_TIME DOWN $URL HTTP:$CODE" >> "$LOG_FILE"

            if [ "$OLD_STATE" != "DOWN" ]; then
                send_tg "🚨 网站访问异常

网站：$URL
状态码：$CODE
时间：$NOW_TIME

请登录服务器检查 Nginx / PHP / 网站日志。"
            fi

            set_state "$URL" "DOWN"
        fi

    done < "$SITE_FILE"
}

select_site_url() {
    SITES=($(find /www/wwwroot -maxdepth 1 -type d | grep -v "^/www/wwwroot$"))

    if [ ${#SITES[@]} -eq 0 ]; then
        echo -e "${RED}没有检测到网站目录${NC}"
        return
    fi

    echo ""
    echo -e "${YELLOW}检测到以下网站：${NC}"
    echo ""

    INDEX=1

    for site in "${SITES[@]}"
    do
        DOMAIN=$(basename "$site")
        echo "$INDEX. https://$DOMAIN"
        INDEX=$((INDEX+1))
    done

    echo "0. 返回"
    echo ""

    read -p "请选择网站编号: " NUM

    if [ "$NUM" = "0" ]; then
        return
    fi

    SITE=${SITES[$((NUM-1))]}

    if [ ! -d "$SITE" ]; then
        echo -e "${RED}网站不存在或编号错误${NC}"
        return
    fi

    DOMAIN=$(basename "$SITE")
    URL="https://$DOMAIN"

    touch "$SITE_FILE"

    grep -qxF "$URL" "$SITE_FILE" 2>/dev/null || echo "$URL" >> "$SITE_FILE"

    echo -e "${GREEN}已添加监控：$URL${NC}"
}

config_telegram() {
    echo ""
    read -p "请输入 Telegram Bot Token: " BOT_TOKEN
    read -p "请输入 Telegram Chat ID: " CHAT_ID

    cat > "$CONFIG_FILE" << EOF
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
EOF

    echo ""
    echo -e "${GREEN}Telegram 配置已保存${NC}"
}

test_telegram() {
    send_tg "✅ Linux Tools 测试消息

Telegram 告警配置成功。"
    echo -e "${GREEN}测试消息已发送，请查看 Telegram${NC}"
}

show_sites() {
    echo ""
    echo -e "${YELLOW}当前监控网站：${NC}"
    echo ""

    if [ -f "$SITE_FILE" ]; then
        nl -w2 -s'. ' "$SITE_FILE"
    else
        echo "暂无监控网站"
    fi
}

delete_site() {
    show_sites

    echo ""
    read -p "请输入要删除的网站编号: " NUM

    if [ -z "$NUM" ]; then
        return
    fi

    if [ ! -f "$SITE_FILE" ]; then
        echo -e "${RED}暂无监控网站${NC}"
        return
    fi

    sed -i "${NUM}d" "$SITE_FILE"

    echo -e "${GREEN}已删除${NC}"
}

manual_test() {
    echo ""
    echo -e "${YELLOW}开始手动检测...${NC}"
    echo ""

    if [ ! -f "$SITE_FILE" ]; then
        echo -e "${RED}暂无监控网站${NC}"
        return
    fi

    while read -r URL
    do
        if [ -z "$URL" ]; then
            continue
        fi

        CODE=$(get_status "$URL")

        if is_ok_code "$CODE"; then
            echo -e "${GREEN}正常：$URL HTTP:$CODE${NC}"
        else
            echo -e "${RED}异常：$URL HTTP:$CODE${NC}"
        fi

    done < "$SITE_FILE"
}

set_interval() {
    clear

    echo -e "${GREEN}"
    echo "================================================"
    echo " 设置网站检测间隔"
    echo "================================================"
    echo -e "${NC}"

    CURRENT_INTERVAL=$(get_interval)

    echo ""
    echo -e "${YELLOW}当前检测间隔：${CURRENT_INTERVAL} 分钟${NC}"
    echo ""

    echo " 1. 每 5 分钟检测一次"
    echo " 2. 每 10 分钟检测一次（推荐）"
    echo " 3. 每 15 分钟检测一次"
    echo " 4. 每 30 分钟检测一次"
    echo " 5. 每 60 分钟检测一次"
    echo " 0. 返回"
    echo ""

    read -p "请选择检测间隔: " NUM

    case "$NUM" in
        1)
            CHECK_INTERVAL=5
            ;;
        2)
            CHECK_INTERVAL=10
            ;;
        3)
            CHECK_INTERVAL=15
            ;;
        4)
            CHECK_INTERVAL=30
            ;;
        5)
            CHECK_INTERVAL=60
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}输入错误${NC}"
            sleep 1
            return
            ;;
    esac

    cat > "$INTERVAL_FILE" << EOF
CHECK_INTERVAL=$CHECK_INTERVAL
EOF

    echo ""
    echo -e "${GREEN}检测间隔已设置为：${CHECK_INTERVAL} 分钟${NC}"
    echo ""

    read -p "是否立即更新定时任务？(y/n): " UPDATE_CRON

    if [ "$UPDATE_CRON" = "y" ]; then
        install_cron
    fi
}

install_cron() {
    mkdir -p /opt/linux-tools

    curl -fsSL "https://raw.githubusercontent.com/leaf008/linux-tools/main/site-monitor.sh?t=$(date +%s)" \
        -o "$LOCAL_SCRIPT"

    chmod +x "$LOCAL_SCRIPT"

    CHECK_INTERVAL=$(get_interval)

    cat > "$CRON_FILE" << EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/$CHECK_INTERVAL * * * * root /bin/bash $LOCAL_SCRIPT --run >/dev/null 2>&1
EOF

    echo ""
    echo -e "${GREEN}定时监控任务已安装/更新${NC}"
    echo "检测间隔：每 $CHECK_INTERVAL 分钟"
    echo "任务文件：$CRON_FILE"
}

remove_cron() {
    rm -f "$CRON_FILE"
    echo -e "${GREEN}定时监控任务已删除${NC}"
}

show_log() {
    echo ""
    echo -e "${YELLOW}最近 50 行监控日志：${NC}"
    echo ""

    if [ -f "$LOG_FILE" ]; then
        tail -50 "$LOG_FILE"
    else
        echo "暂无日志"
    fi
}

show_current_config() {
    echo ""
    echo -e "${YELLOW}当前监控配置：${NC}"
    echo ""

    echo "监控目录：$BASE_DIR"

    CHECK_INTERVAL=$(get_interval)

    echo "检测间隔：每 $CHECK_INTERVAL 分钟"

    if [ -f "$CRON_FILE" ]; then
        echo -e "${GREEN}定时任务：已安装${NC}"
        echo ""
        cat "$CRON_FILE"
    else
        echo -e "${RED}定时任务：未安装${NC}"
    fi

    echo ""

    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}Telegram：已配置${NC}"
    else
        echo -e "${RED}Telegram：未配置${NC}"
    fi

    echo ""

    show_sites
}

if [ "$1" = "--run" ]; then
    run_monitor
    exit 0
fi

while true
do
    clear

    echo -e "${GREEN}"
    echo "================================================"
    echo " Linux Tools 网站实时监控TG告警 v1.1"
    echo "================================================"
    echo -e "${NC}"

    CURRENT_INTERVAL=$(get_interval)

    echo "当前检测间隔：每 ${CURRENT_INTERVAL} 分钟"
    echo ""

    echo " 1. 添加监控网站"
    echo " 2. 查看监控网站"
    echo " 3. 删除监控网站"
    echo " 4. 配置 Telegram"
    echo " 5. 测试 Telegram 消息"
    echo " 6. 手动检测网站状态"
    echo " 7. 设置检测间隔时间"
    echo " 8. 安装/更新定时监控任务"
    echo " 9. 删除定时监控任务"
    echo "10. 查看监控日志"
    echo "11. 查看当前配置"
    echo " 0. 返回主菜单"
    echo ""

    read -p "请输入数字: " NUM

    case "$NUM" in

    1)
        select_site_url
        read -p "按回车继续..."
        ;;

    2)
        show_sites
        read -p "按回车继续..."
        ;;

    3)
        delete_site
        read -p "按回车继续..."
        ;;

    4)
        config_telegram
        read -p "按回车继续..."
        ;;

    5)
        test_telegram
        read -p "按回车继续..."
        ;;

    6)
        manual_test
        read -p "按回车继续..."
        ;;

    7)
        set_interval
        read -p "按回车继续..."
        ;;

    8)
        install_cron
        read -p "按回车继续..."
        ;;

    9)
        remove_cron
        read -p "按回车继续..."
        ;;

    10)
        show_log
        read -p "按回车继续..."
        ;;

    11)
        show_current_config
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

done
