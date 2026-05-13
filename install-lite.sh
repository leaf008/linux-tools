#!/usr/bin/env bash

set -e

DEFAULT_BASE_URL="https://raw.githubusercontent.com/leaf008/linux-tools/main"
BASE_URL="${BASE_URL:-}"
LINUX_TOOLS_BASE_URLS="${LINUX_TOOLS_BASE_URLS:-${BASE_URL:-$DEFAULT_BASE_URL}}"
LT_BIN="/usr/local/bin/lt"
IP_BAN_BIN="/usr/local/bin/linux-tools-ip-ban"
GUARDIAN_BIN="/usr/local/bin/site-guardian"

download_from_sources() {
    local file="$1"
    local output="$2"
    local base url

    for base in $LINUX_TOOLS_BASE_URLS
    do
        base="${base%/}"
        url="$base/$file?t=$(date +%s)"
        echo "尝试来源：$url"

        if curl -fsSL --connect-timeout 8 --max-time 45 "$url" -o "$output"; then
            return 0
        fi
    done

    echo "下载失败：$file"
    echo "可通过 LINUX_TOOLS_BASE_URLS 配置多个源，例如："
    echo "LINUX_TOOLS_BASE_URLS=\"https://raw.githubusercontent.com/leaf008/linux-tools/main https://你的国内镜像/linux-tools/main\" bash <(curl -fsSL ...)"
    return 1
}

echo ""
echo "================================"
echo " Linux Tools 本地快捷命令安装"
echo "================================"
echo ""

echo "正在安装 lt 菜单..."
download_from_sources "install.sh" "$LT_BIN"
chmod +x "$LT_BIN"

echo "正在安装安全版 IP 工具到本地缓存..."
download_from_sources "ip-ban.sh" "$IP_BAN_BIN"
chmod +x "$IP_BAN_BIN"

echo "正在安装网站监控/防挂马工具到本地缓存..."
if download_from_sources "site-guardian.sh" "$GUARDIAN_BIN"; then
    chmod +x "$GUARDIAN_BIN"
else
    echo "site-guardian.sh 未安装，可稍后上传该文件后重新运行 install-lite.sh"
fi

echo ""
echo "安装完成"
echo ""
echo "快捷命令："
echo ""
echo "lt"
echo ""
echo "IP 安全工具本地路径：$IP_BAN_BIN"
echo "网站监控工具本地路径：$GUARDIAN_BIN"
echo ""
