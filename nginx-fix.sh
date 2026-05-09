#!/bin/bash

clear

echo "================================"
echo " Nginx 修复工具"
echo "================================"

echo ""
echo "[1] 检测配置"
nginx -t

echo ""
echo "[2] 检测80/443端口"
ss -lntp | grep -E '80|443'

echo ""
echo "[3] 重载Nginx"
systemctl reload nginx

echo ""
echo "[4] 检测状态"
systemctl status nginx --no-pager

echo ""
echo "[5] 最近错误日志"
tail -20 /www/wwwlogs/error.log

echo ""
echo "完成"
