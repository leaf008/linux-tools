#!/usr/bin/env bash

set -o pipefail

BASE_DIR="${BASE_DIR:-/opt/linux-tools/guardian}"
CONFIG_FILE="$BASE_DIR/config.conf"
SITES_FILE="$BASE_DIR/sites.conf"
STATE_DIR="$BASE_DIR/state"
BACKUP_DIR="$BASE_DIR/backups"
QUARANTINE_DIR="$BASE_DIR/quarantine"
LOG_FILE="$BASE_DIR/guardian.log"
LOCAL_BIN="/usr/local/bin/site-guardian"
CRON_FILE="/etc/cron.d/linux-tools-site-guardian"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$BASE_DIR" "$STATE_DIR" "$BACKUP_DIR" "$QUARANTINE_DIR"
touch "$SITES_FILE" "$LOG_FILE"

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi

    CHECK_INTERVAL="${CHECK_INTERVAL:-5}"
    REQUEST_TIMEOUT="${REQUEST_TIMEOUT:-15}"
    AUTO_RESTORE="${AUTO_RESTORE:-0}"
    AUTO_QUARANTINE="${AUTO_QUARANTINE:-0}"
    MAX_SCAN_FILE_SIZE_KB="${MAX_SCAN_FILE_SIZE_KB:-1024}"
}

save_default_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" <<EOF
CHECK_INTERVAL=5
REQUEST_TIMEOUT=15
AUTO_RESTORE=0
AUTO_QUARANTINE=0
MAX_SCAN_FILE_SIZE_KB=1024

# 可选通知配置：
# NOTICE_WEBHOOK=""
# TG_BOT_TOKEN=""
# TG_CHAT_ID=""
# BARK_KEY=""
# BARK_SERVER="https://api.day.app"
EOF
    fi
}

log_msg() {
    echo "$(date '+%F %T') $*" | tee -a "$LOG_FILE"
}

send_notify() {
    local title="$1"
    local body="$2"

    load_config

    log_msg "$title | $body"

    if [ -n "${NOTICE_WEBHOOK:-}" ]; then
        curl -fsS -m 10 -X POST "$NOTICE_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"$title\",\"text\":\"$body\"}" >/dev/null 2>&1 || true
    fi

    if [ -n "${TG_BOT_TOKEN:-}" ] && [ -n "${TG_CHAT_ID:-}" ]; then
        curl -fsS -m 10 -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
            -d chat_id="$TG_CHAT_ID" \
            --data-urlencode text="$title

$body" >/dev/null 2>&1 || true
    fi

    if [ -n "${BARK_KEY:-}" ]; then
        local bark_server="${BARK_SERVER:-https://api.day.app}"
        curl -fsS -m 10 -G "${bark_server}/${BARK_KEY}/${title}/${body}" \
            --data-urlencode "group=SiteGuardian" >/dev/null 2>&1 || true
    fi
}

site_id() {
    echo "$1" | tr -cs 'A-Za-z0-9._-' '_' | sed 's/^_//;s/_$//'
}

usage() {
    cat <<'EOF'
用法：
  site-guardian install              安装本地命令和定时任务
  site-guardian add URL ROOT         添加网站，例如 https://example.com /www/wwwroot/example.com
  site-guardian list                 查看监控网站
  site-guardian backup [URL]         建立干净备份
  site-guardian run                  立即巡检全部网站
  site-guardian restore URL          从最近备份回滚网站文件
  site-guardian config               查看配置
  site-guardian uninstall            删除定时任务

环境变量：
  AUTO_RESTORE=1                     检测到异常时自动回滚到最近备份，默认关闭
  AUTO_QUARANTINE=1                  扫到可疑文件时自动隔离，默认关闭
EOF
}

menu() {
    local num url root

    while true
    do
        clear
        echo -e "${GREEN}"
        echo "================================================"
        echo " 网站可用性 / 防挂马守护"
        echo "================================================"
        echo -e "${NC}"
        echo " 1. 安装/更新定时任务"
        echo " 2. 添加监控网站"
        echo " 3. 查看监控网站"
        echo " 4. 立即巡检"
        echo " 5. 建立干净备份"
        echo " 6. 从最近备份回滚"
        echo " 7. 查看配置"
        echo " 8. 删除定时任务"
        echo " 0. 返回"
        echo ""

        read -r -p "请输入数字: " num

        case "$num" in
            1)
                install_self
                read -r -p "按回车继续..."
                ;;
            2)
                read -r -p "网站 URL，例如 https://example.com: " url
                read -r -p "网站目录，例如 /www/wwwroot/example.com: " root
                add_site "$url" "$root"
                read -r -p "按回车继续..."
                ;;
            3)
                list_sites
                read -r -p "按回车继续..."
                ;;
            4)
                run_all
                read -r -p "按回车继续..."
                ;;
            5)
                backup_command
                read -r -p "按回车继续..."
                ;;
            6)
                read -r -p "请输入要回滚的网站 URL: " url
                restore_site "$url"
                read -r -p "按回车继续..."
                ;;
            7)
                show_config
                read -r -p "按回车继续..."
                ;;
            8)
                uninstall_self
                read -r -p "按回车继续..."
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}输入错误${NC}"
                sleep 1
                ;;
        esac
    done
}

add_site() {
    local url="$1"
    local root="$2"

    if [ -z "$url" ] || [ -z "$root" ]; then
        echo "用法：site-guardian add URL ROOT"
        return 1
    fi

    if [ ! -d "$root" ]; then
        echo -e "${RED}网站目录不存在：$root${NC}"
        return 1
    fi

    grep -v "^$url|" "$SITES_FILE" > "$SITES_FILE.tmp"
    echo "$url|$root" >> "$SITES_FILE.tmp"
    mv "$SITES_FILE.tmp" "$SITES_FILE"

    echo -e "${GREEN}已添加：$url -> $root${NC}"
}

list_sites() {
    if [ ! -s "$SITES_FILE" ]; then
        echo "暂无监控网站"
        return
    fi

    nl -w2 -s'. ' "$SITES_FILE"
}

http_check() {
    local url="$1"
    local code total

    load_config

    code=$(curl -k -L -m "$REQUEST_TIMEOUT" -o /tmp/site_guardian_body.$$ -s -w "%{http_code}" "$url" || echo "000")
    total=$(wc -c < /tmp/site_guardian_body.$$ 2>/dev/null || echo 0)
    rm -f /tmp/site_guardian_body.$$

    case "$code" in
        200|201|202|204|301|302|304)
            echo "OK HTTP:$code SIZE:$total"
            return 0
            ;;
        *)
            echo "DOWN HTTP:$code SIZE:$total"
            return 1
            ;;
    esac
}

web_injection_check() {
    local url="$1"
    local body="/tmp/site_guardian_page.$$"
    local hit

    load_config

    curl -k -L -m "$REQUEST_TIMEOUT" -s "$url" -o "$body" || {
        rm -f "$body"
        return 1
    }

    hit=$(LC_ALL=C grep -Eio '(<iframe[^>]+src=|eval\(|document\.write\(|unescape\(|atob\(|fromCharCode|window\.location|viagra|casino|博彩|棋牌|色情|贷款)' "$body" | head -1)
    rm -f "$body"

    if [ -n "$hit" ]; then
        echo "$hit"
        return 1
    fi

    return 0
}

scan_files() {
    local root="$1"
    local report="$2"

    load_config

    : > "$report"

    find "$root" -type f \( -name '*.php' -o -name '*.phtml' -o -name '*.inc' -o -name '*.js' -o -name '*.html' -o -name '*.htm' \) \
        -size -"${MAX_SCAN_FILE_SIZE_KB}"k 2>/dev/null | while read -r file
    do
        if LC_ALL=C grep -Eq '(eval[[:space:]]*\(|assert[[:space:]]*\(|system[[:space:]]*\(|shell_exec[[:space:]]*\(|passthru[[:space:]]*\(|base64_decode[[:space:]]*\(|gzinflate[[:space:]]*\(|str_rot13[[:space:]]*\(|preg_replace[[:space:]]*\(.*/e|fromCharCode|atob[[:space:]]*\(|document\.write[[:space:]]*\(|<iframe[^>]+src=)' "$file"; then
            echo "$file" >> "$report"
        fi
    done

    [ ! -s "$report" ]
}

backup_site() {
    local url="$1"
    local root="$2"
    local id archive

    id=$(site_id "$url")
    archive="$BACKUP_DIR/${id}-$(date '+%Y%m%d-%H%M%S').tar.gz"

    tar --exclude='runtime' --exclude='cache' --exclude='*.log' -czf "$archive" -C "$(dirname "$root")" "$(basename "$root")"
    echo "$archive" > "$STATE_DIR/${id}.last_backup"
    echo -e "${GREEN}备份完成：$archive${NC}"
}

backup_command() {
    local target="${1:-}"
    local url root

    if [ ! -s "$SITES_FILE" ]; then
        echo "暂无监控网站"
        return 1
    fi

    while IFS='|' read -r url root
    do
        [ -z "$url" ] && continue
        if [ -z "$target" ] || [ "$target" = "$url" ]; then
            backup_site "$url" "$root"
        fi
    done < "$SITES_FILE"
}

restore_site() {
    local url="$1"
    local root id archive now_backup

    if [ -z "$url" ]; then
        echo "用法：site-guardian restore URL"
        return 1
    fi

    root=$(grep "^$url|" "$SITES_FILE" | tail -1 | awk -F'|' '{print $2}')
    if [ -z "$root" ]; then
        echo -e "${RED}未找到站点：$url${NC}"
        return 1
    fi

    id=$(site_id "$url")
    archive=$(cat "$STATE_DIR/${id}.last_backup" 2>/dev/null)

    if [ -z "$archive" ] || [ ! -f "$archive" ]; then
        echo -e "${RED}没有可用备份：$url${NC}"
        return 1
    fi

    now_backup="$BACKUP_DIR/${id}-before-restore-$(date '+%Y%m%d-%H%M%S').tar.gz"
    tar -czf "$now_backup" -C "$(dirname "$root")" "$(basename "$root")"

    rm -rf "$root"
    mkdir -p "$(dirname "$root")"
    tar -xzf "$archive" -C "$(dirname "$root")"

    send_notify "网站已回滚" "网站：$url
使用备份：$archive
回滚前备份：$now_backup"
}

quarantine_files() {
    local url="$1"
    local report="$2"
    local id dest

    id=$(site_id "$url")
    dest="$QUARANTINE_DIR/${id}-$(date '+%Y%m%d-%H%M%S')"
    mkdir -p "$dest"

    while read -r file
    do
        [ -f "$file" ] || continue
        mkdir -p "$dest$(dirname "$file")"
        mv "$file" "$dest$file"
    done < "$report"

    echo "$dest"
}

run_one_site() {
    local url="$1"
    local root="$2"
    local id http_result report injection quarantine_path
    local failed=0

    id=$(site_id "$url")
    report="$STATE_DIR/${id}.suspicious-files.txt"

    echo -e "${BLUE}检查：$url${NC}"

    http_result=$(http_check "$url")
    echo "  访问状态：$http_result"
    echo "$http_result" > "$STATE_DIR/${id}.http"

    if echo "$http_result" | grep -q '^DOWN'; then
        failed=1
        send_notify "网站访问异常" "网站：$url
状态：$http_result"
    fi

    if ! injection=$(web_injection_check "$url"); then
        failed=1
        send_notify "网页疑似挂马" "网站：$url
命中：$injection"
    fi

    if ! scan_files "$root" "$report"; then
        failed=1
        send_notify "发现可疑文件" "网站：$url
目录：$root
清单：$report"

        load_config
        if [ "$AUTO_QUARANTINE" = "1" ]; then
            quarantine_path=$(quarantine_files "$url" "$report")
            send_notify "可疑文件已隔离" "网站：$url
隔离目录：$quarantine_path"
        fi
    fi

    load_config
    if [ "$failed" -eq 1 ] && [ "$AUTO_RESTORE" = "1" ]; then
        restore_site "$url"
    fi

    if [ "$failed" -eq 0 ]; then
        echo -e "  ${GREEN}正常${NC}"
    fi
}

run_all() {
    local url root

    if [ ! -s "$SITES_FILE" ]; then
        echo "暂无监控网站，请先执行：site-guardian add URL ROOT"
        return 1
    fi

    while IFS='|' read -r url root
    do
        [ -z "$url" ] && continue
        [ -d "$root" ] || {
            send_notify "网站目录不存在" "网站：$url
目录：$root"
            continue
        }
        run_one_site "$url" "$root"
    done < "$SITES_FILE"
}

install_self() {
    save_default_config

    cp "$0" "$LOCAL_BIN"
    chmod +x "$LOCAL_BIN"

    load_config

    cat > "$CRON_FILE" <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/$CHECK_INTERVAL * * * * root $LOCAL_BIN run >/dev/null 2>&1
EOF

    echo -e "${GREEN}安装完成${NC}"
    echo "命令：site-guardian"
    echo "定时任务：$CRON_FILE"
    echo "配置文件：$CONFIG_FILE"
}

uninstall_self() {
    rm -f "$CRON_FILE"
    echo -e "${GREEN}已删除定时任务：$CRON_FILE${NC}"
}

show_config() {
    load_config
    echo "配置文件：$CONFIG_FILE"
    echo "站点文件：$SITES_FILE"
    echo "检查间隔：$CHECK_INTERVAL 分钟"
    echo "自动回滚：$AUTO_RESTORE"
    echo "自动隔离：$AUTO_QUARANTINE"
    echo "日志：$LOG_FILE"
}

cmd="${1:-help}"
shift || true

case "$cmd" in
    install)
        install_self
        ;;
    add)
        add_site "$@"
        ;;
    list)
        list_sites
        ;;
    backup)
        backup_command "$@"
        ;;
    run)
        run_all
        ;;
    restore)
        restore_site "$@"
        ;;
    config)
        show_config
        ;;
    menu)
        menu
        ;;
    uninstall)
        uninstall_self
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
