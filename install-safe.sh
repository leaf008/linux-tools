#!/usr/bin/env bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAFE_IP_BAN="$SCRIPT_DIR/ip-ban-safe.sh"

run_remote() {
    local name="$1"
    local url="$2"

    echo -e "${YELLOW}准备运行：$name${NC}"
    echo "来源：$url"
    echo ""
    read -r -p "确认运行？输入 yes 继续: " confirm

    if [ "$confirm" != "yes" ]; then
        echo "已取消"
        return 0
    fi

    bash <(curl -fsSL "$url")
}

while true
do
    clear

    echo -e "${GREEN}"
    echo "================================================"
    echo " Linux Tools 安全菜单（本地改良版）"
    echo "================================================"
    echo -e "${NC}"

    echo " 1. PbootCMS安全检测"
    echo " 2. WordPress安全检测"
    echo " 3. 宝塔安全修复"
    echo " 4. Nginx修复"
    echo " 5. PHP安全加固"
    echo " 6. 网站巡检"
    echo " 7. 网站备份"
    echo " 8. 网站恢复"
    echo " 9. 网站故障修复"
    echo "10. 安全版 IP 审查/封禁（已改良）"
    echo "11. 网站实时监控告警"
    echo " 0. 退出"
    echo ""

    read -r -p "请输入数字: " num

    case "$num" in
        1)
            run_remote "PbootCMS安全检测" "https://raw.githubusercontent.com/leaf008/linux-tools/main/pboot-safe.sh"
            read -r -p "按回车返回菜单..."
            ;;
        2)
            run_remote "WordPress安全检测" "https://raw.githubusercontent.com/leaf008/linux-tools/main/wp-safe.sh"
            read -r -p "按回车返回菜单..."
            ;;
        3)
            run_remote "宝塔安全修复" "https://raw.githubusercontent.com/leaf008/linux-tools/main/bt-safe.sh"
            read -r -p "按回车返回菜单..."
            ;;
        4)
            run_remote "Nginx修复" "https://raw.githubusercontent.com/leaf008/linux-tools/main/nginx-fix.sh"
            read -r -p "按回车返回菜单..."
            ;;
        5)
            run_remote "PHP安全加固" "https://raw.githubusercontent.com/leaf008/linux-tools/main/php-safe.sh"
            read -r -p "按回车返回菜单..."
            ;;
        6)
            run_remote "网站巡检" "https://raw.githubusercontent.com/leaf008/linux-tools/main/site-check.sh"
            read -r -p "按回车返回菜单..."
            ;;
        7)
            run_remote "网站备份" "https://raw.githubusercontent.com/leaf008/linux-tools/main/backup-site.sh"
            read -r -p "按回车返回菜单..."
            ;;
        8)
            run_remote "网站恢复" "https://raw.githubusercontent.com/leaf008/linux-tools/main/restore-backup.sh"
            read -r -p "按回车返回菜单..."
            ;;
        9)
            run_remote "网站故障修复" "https://raw.githubusercontent.com/leaf008/linux-tools/main/site-fix.sh"
            read -r -p "按回车返回菜单..."
            ;;
        10)
            if [ ! -f "$SAFE_IP_BAN" ]; then
                echo -e "${RED}找不到安全版脚本：$SAFE_IP_BAN${NC}"
            else
                bash "$SAFE_IP_BAN"
            fi
            read -r -p "按回车返回菜单..."
            ;;
        11)
            run_remote "网站实时监控告警" "https://raw.githubusercontent.com/leaf008/linux-tools/main/site-monitor.sh"
            read -r -p "按回车返回菜单..."
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
