#!/usr/bin/env bash

set -o pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_DIR="${LOG_DIR:-/www/wwwlogs}"
BASE_DIR="${BASE_DIR:-/root/linux-tools-ip-ban}"
BAN_LIST="${BAN_LIST:-/root/linux-tools-banned-ips.txt}"
WHITELIST_FILE="${WHITELIST_FILE:-$BASE_DIR/whitelist.txt}"
CIDR_WHITELIST_FILE="${CIDR_WHITELIST_FILE:-$BASE_DIR/cidr-whitelist.txt}"
TMP_ALL="/tmp/linux_tools_all_ips.txt"
TMP_BAD="/tmp/linux_tools_bad_ips.txt"
TMP_CANDIDATES="/tmp/linux_tools_ban_candidates.txt"
AUDIT_LOG="$BASE_DIR/audit.log"

mkdir -p "$BASE_DIR"
touch "$BAN_LIST" "$WHITELIST_FILE" "$CIDR_WHITELIST_FILE" "$AUDIT_LOG"

print_title() {
    clear
    echo -e "${GREEN}"
    echo "================================================"
    echo " Linux Tools 安全版 IP 审查/封禁工具 v2.0"
    echo "================================================"
    echo -e "${NC}"
}

log_action() {
    echo "$(date '+%F %T') $*" >> "$AUDIT_LOG"
}

get_my_ssh_ip() {
    echo "$SSH_CLIENT" | awk '{print $1}'
}

is_ipv4() {
    echo "$1" | awk -F. '
        NF != 4 { exit 1 }
        {
            for (i = 1; i <= 4; i++) {
                if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) exit 1
            }
        }
    '
}

ip_to_int() {
    local ip="$1"
    local a b c d
    IFS=. read -r a b c d <<EOF
$ip
EOF
    echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

cidr_contains() {
    local ip="$1"
    local cidr="$2"
    local network bits ip_int net_int mask

    network="${cidr%/*}"
    bits="${cidr#*/}"

    is_ipv4 "$ip" || return 1
    is_ipv4 "$network" || return 1
    [[ "$bits" =~ ^[0-9]+$ ]] || return 1
    [ "$bits" -ge 0 ] && [ "$bits" -le 32 ] || return 1

    ip_int=$(ip_to_int "$ip")
    net_int=$(ip_to_int "$network")

    if [ "$bits" -eq 0 ]; then
        mask=0
    else
        mask=$(( (0xffffffff << (32 - bits)) & 0xffffffff ))
    fi

    [ $((ip_int & mask)) -eq $((net_int & mask)) ]
}

is_private_or_reserved_ip() {
    local ip="$1"
    local a b

    is_ipv4 "$ip" || return 0

    IFS=. read -r a b _ _ <<EOF
$ip
EOF

    [ "$a" -eq 0 ] && return 0
    [ "$a" -eq 10 ] && return 0
    [ "$a" -eq 100 ] && [ "$b" -ge 64 ] && [ "$b" -le 127 ] && return 0
    [ "$a" -eq 127 ] && return 0
    [ "$a" -eq 169 ] && [ "$b" -eq 254 ] && return 0
    [ "$a" -eq 172 ] && [ "$b" -ge 16 ] && [ "$b" -le 31 ] && return 0
    [ "$a" -eq 192 ] && [ "$b" -eq 168 ] && return 0
    [ "$a" -ge 224 ] && return 0

    return 1
}

is_whitelisted() {
    local ip="$1"
    local my_ip cidr

    my_ip=$(get_my_ssh_ip)
    [ -n "$my_ip" ] && [ "$ip" = "$my_ip" ] && return 0

    grep -qxF "$ip" "$WHITELIST_FILE" 2>/dev/null && return 0

    while read -r cidr
    do
        cidr="${cidr%%#*}"
        cidr="$(echo "$cidr" | awk '{$1=$1; print}')"
        [ -z "$cidr" ] && continue

        cidr_contains "$ip" "$cidr" && return 0
    done < "$CIDR_WHITELIST_FILE"

    return 1
}

should_skip_ip() {
    local ip="$1"

    if ! is_ipv4 "$ip"; then
        echo "不是有效 IPv4"
        return 0
    fi

    if is_private_or_reserved_ip "$ip"; then
        echo "内网/保留地址"
        return 0
    fi

    if is_whitelisted "$ip"; then
        echo "白名单/当前 SSH 来源"
        return 0
    fi

    return 1
}

extract_public_ips_from_line() {
    grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | while read -r ip
    do
        is_ipv4 "$ip" || continue
        is_private_or_reserved_ip "$ip" && continue
        echo "$ip"
        break
    done
}

filter_public_ipv4() {
    awk -F. '
        NF == 4 &&
        $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ &&
        $1 >= 0 && $1 <= 255 && $2 >= 0 && $2 <= 255 && $3 >= 0 && $3 <= 255 && $4 >= 0 && $4 <= 255 &&
        $1 != 0 &&
        $1 != 10 &&
        $1 != 127 &&
        !($1 == 100 && $2 >= 64 && $2 <= 127) &&
        !($1 == 169 && $2 == 254) &&
        !($1 == 172 && $2 >= 16 && $2 <= 31) &&
        !($1 == 192 && $2 == 168) &&
        $1 < 224 {
            print
        }
    '
}

scan_all_high_freq() {
    echo ""
    echo -e "${YELLOW}正在统计访问 IP，优先提取日志行里的第一个公网 IP...${NC}"
    echo ""

    > "$TMP_ALL"

    if [ ! -d "$LOG_DIR" ]; then
        echo -e "${RED}日志目录不存在：$LOG_DIR${NC}"
        return 1
    fi

    LC_ALL=C grep -hEo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$LOG_DIR"/*.log "$LOG_DIR"/*.error.log 2>/dev/null | \
        filter_public_ipv4 >> "$TMP_ALL"

    echo ""
    echo -e "${BLUE}访问次数最多的前 30 个公网 IP：${NC}"
    echo ""

    sort "$TMP_ALL" | uniq -c | sort -rn | head -30
}

scan_bad_paths() {
    echo ""
    echo -e "${YELLOW}正在扫描明显攻击/探测路径 IP...${NC}"
    echo ""

    > "$TMP_BAD"

    if [ ! -d "$LOG_DIR" ]; then
        echo -e "${RED}日志目录不存在：$LOG_DIR${NC}"
        return 1
    fi

    PATTERN="(^|[[:space:]\"])(/\.env|/\.git|/wp-login\.php|/xmlrpc\.php|/phpinfo|/server-status|/vendor/phpunit|/config/parameters|/actuator|/boaform|/shell|/cmd|/eval|/login\.action)"

    LC_ALL=C grep -hEi "$PATTERN" "$LOG_DIR"/*.log "$LOG_DIR"/*.error.log 2>/dev/null | \
        grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | \
        filter_public_ipv4 >> "$TMP_BAD"

    echo ""
    echo -e "${BLUE}可疑扫描 IP 排行：${NC}"
    echo ""

    sort "$TMP_BAD" | uniq -c | sort -rn | head -30
}

build_bad_path_candidates() {
    local limit="${1:-20}"

    scan_bad_paths >/dev/null || return 1

    > "$TMP_CANDIDATES"

    sort "$TMP_BAD" | uniq -c | sort -rn | while read -r count ip
    do
        [ -z "$ip" ] && continue

        if [ "$count" -ge "$limit" ]; then
            if reason=$(should_skip_ip "$ip"); then
                echo -e "${YELLOW}跳过 $ip：$reason${NC}" >&2
                continue
            fi

            echo "$count $ip" >> "$TMP_CANDIDATES"
        fi
    done

    if [ ! -s "$TMP_CANDIDATES" ]; then
        echo -e "${GREEN}没有达到阈值且可封禁的可疑 IP。${NC}"
        return 1
    fi

    echo ""
    echo -e "${BLUE}候选封禁 IP：${NC}"
    echo ""
    cat "$TMP_CANDIDATES"
}

backup_firewall_rules() {
    local backup_dir="$BASE_DIR/backups/$(date '+%Y%m%d-%H%M%S')"

    mkdir -p "$backup_dir"

    if command -v ufw >/dev/null 2>&1; then
        ufw status numbered > "$backup_dir/ufw-status.txt" 2>&1
    fi

    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --list-rich-rules > "$backup_dir/firewalld-rich-rules.txt" 2>&1
    fi

    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save > "$backup_dir/iptables-save.txt" 2>&1
    fi

    echo "$backup_dir"
}

ban_ip() {
    local ip="$1"
    local reason backup_dir

    if reason=$(should_skip_ip "$ip"); then
        echo -e "${YELLOW}跳过 $ip：$reason${NC}"
        return 0
    fi

    if grep -qxF "$ip" "$BAN_LIST"; then
        echo -e "${YELLOW}已封禁过：$ip${NC}"
        return 0
    fi

    backup_dir=$(backup_firewall_rules)

    if command -v ufw >/dev/null 2>&1; then
        ufw deny from "$ip"
        echo "$ip" >> "$BAN_LIST"
        log_action "BAN ufw $ip backup=$backup_dir"
        echo -e "${GREEN}已通过 ufw 封禁：$ip${NC}"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ip' reject"
        firewall-cmd --reload
        echo "$ip" >> "$BAN_LIST"
        log_action "BAN firewalld $ip backup=$backup_dir"
        echo -e "${GREEN}已通过 firewalld 封禁：$ip${NC}"
    elif command -v iptables >/dev/null 2>&1; then
        iptables -C INPUT -s "$ip" -j DROP 2>/dev/null || iptables -I INPUT -s "$ip" -j DROP
        echo "$ip" >> "$BAN_LIST"
        log_action "BAN iptables $ip backup=$backup_dir"
        echo -e "${GREEN}已通过 iptables 封禁：$ip${NC}"
    else
        echo -e "${RED}未检测到 ufw/firewalld/iptables，无法自动封禁：$ip${NC}"
        return 1
    fi
}

unban_ip() {
    local ip="$1"

    is_ipv4 "$ip" || {
        echo -e "${RED}IP 格式错误：$ip${NC}"
        return 1
    }

    if command -v ufw >/dev/null 2>&1; then
        ufw delete deny from "$ip" 2>/dev/null
    fi

    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' source address='$ip' reject" 2>/dev/null
        firewall-cmd --reload 2>/dev/null
    fi

    if command -v iptables >/dev/null 2>&1; then
        while iptables -C INPUT -s "$ip" -j DROP 2>/dev/null
        do
            iptables -D INPUT -s "$ip" -j DROP
        done
    fi

    sed -i.bak "/^$ip$/d" "$BAN_LIST"
    log_action "UNBAN $ip"
    echo -e "${GREEN}已解除封禁：$ip${NC}"
}

unban_all_from_list() {
    local backup

    if [ ! -s "$BAN_LIST" ]; then
        echo -e "${YELLOW}封禁记录为空：$BAN_LIST${NC}"
        return 0
    fi

    backup="$BAN_LIST.backup-$(date '+%Y%m%d-%H%M%S')"
    cp "$BAN_LIST" "$backup"

    while read -r ip
    do
        [ -z "$ip" ] && continue
        unban_ip "$ip"
    done < "$backup"

    : > "$BAN_LIST"
    echo -e "${GREEN}已尝试解除 $backup 中记录的所有 IP。备份保留在：$backup${NC}"
}

add_whitelist_ip() {
    local ip="$1"

    is_ipv4 "$ip" || {
        echo -e "${RED}IP 格式错误：$ip${NC}"
        return 1
    }

    grep -qxF "$ip" "$WHITELIST_FILE" || echo "$ip" >> "$WHITELIST_FILE"
    echo -e "${GREEN}已加入 IP 白名单：$ip${NC}"
}

add_whitelist_cidr() {
    local cidr="$1"
    local network bits

    network="${cidr%/*}"
    bits="${cidr#*/}"

    is_ipv4 "$network" || {
        echo -e "${RED}CIDR 格式错误：$cidr${NC}"
        return 1
    }

    [[ "$bits" =~ ^[0-9]+$ ]] && [ "$bits" -ge 0 ] && [ "$bits" -le 32 ] || {
        echo -e "${RED}CIDR 格式错误：$cidr${NC}"
        return 1
    }

    grep -qxF "$cidr" "$CIDR_WHITELIST_FILE" || echo "$cidr" >> "$CIDR_WHITELIST_FILE"
    echo -e "${GREEN}已加入 CIDR 白名单：$cidr${NC}"
}

confirm_and_ban_candidates() {
    local limit confirm

    read -r -p "可疑路径封禁阈值，默认 20: " limit
    [ -z "$limit" ] && limit=20

    if ! [[ "$limit" =~ ^[0-9]+$ ]] || [ "$limit" -lt 1 ]; then
        echo -e "${RED}阈值必须是正整数${NC}"
        return 1
    fi

    build_bad_path_candidates "$limit" || return 0

    echo ""
    echo -e "${YELLOW}安全版只建议封禁明显攻击路径 IP，不建议按普通访问量封禁。${NC}"
    read -r -p "确认封禁上面的候选 IP？输入 yes 继续: " confirm

    [ "$confirm" = "yes" ] || {
        echo "已取消"
        return 0
    }

    while read -r _ ip
    do
        [ -n "$ip" ] && ban_ip "$ip"
    done < "$TMP_CANDIDATES"
}

show_config() {
    echo ""
    echo -e "${YELLOW}当前配置：${NC}"
    echo "日志目录：$LOG_DIR"
    echo "封禁记录：$BAN_LIST"
    echo "IP 白名单：$WHITELIST_FILE"
    echo "CIDR 白名单：$CIDR_WHITELIST_FILE"
    echo "审计日志：$AUDIT_LOG"
    echo "当前 SSH 来源：$(get_my_ssh_ip)"
}

while true
do
    print_title
    echo " 1. 查看高频访问 IP（只统计，不封禁）"
    echo " 2. 查看可疑扫描 IP（只统计，不封禁）"
    echo " 3. 生成可疑 IP 候选并确认封禁"
    echo " 4. 查看本工具封禁记录"
    echo " 5. 手动封禁单个 IP"
    echo " 6. 解除封禁单个 IP"
    echo " 7. 一键解除本工具封过的所有 IP"
    echo " 8. 添加 IP 白名单"
    echo " 9. 添加 CIDR 白名单"
    echo "10. 查看配置/白名单"
    echo " 0. 退出"
    echo ""

    read -r -p "请输入数字: " num

    case "$num" in
        1)
            scan_all_high_freq
            read -r -p "按回车继续..."
            ;;
        2)
            scan_bad_paths
            read -r -p "按回车继续..."
            ;;
        3)
            confirm_and_ban_candidates
            read -r -p "按回车继续..."
            ;;
        4)
            echo ""
            echo -e "${YELLOW}已封禁 IP 列表：${NC}"
            cat "$BAN_LIST"
            read -r -p "按回车继续..."
            ;;
        5)
            read -r -p "请输入要封禁的 IP: " ip
            [ -n "$ip" ] && ban_ip "$ip"
            read -r -p "按回车继续..."
            ;;
        6)
            read -r -p "请输入要解除封禁的 IP: " ip
            [ -n "$ip" ] && unban_ip "$ip"
            read -r -p "按回车继续..."
            ;;
        7)
            echo -e "${YELLOW}这会按 $BAN_LIST 逐个解除封禁。${NC}"
            read -r -p "确认继续？输入 yes: " confirm
            [ "$confirm" = "yes" ] && unban_all_from_list
            read -r -p "按回车继续..."
            ;;
        8)
            read -r -p "请输入要加入白名单的 IP: " ip
            [ -n "$ip" ] && add_whitelist_ip "$ip"
            read -r -p "按回车继续..."
            ;;
        9)
            read -r -p "请输入要加入白名单的 CIDR，例如 203.0.113.0/24: " cidr
            [ -n "$cidr" ] && add_whitelist_cidr "$cidr"
            read -r -p "按回车继续..."
            ;;
        10)
            show_config
            echo ""
            echo -e "${YELLOW}IP 白名单：${NC}"
            cat "$WHITELIST_FILE"
            echo ""
            echo -e "${YELLOW}CIDR 白名单：${NC}"
            cat "$CIDR_WHITELIST_FILE"
            read -r -p "按回车继续..."
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
