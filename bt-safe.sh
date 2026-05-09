#!/bin/bash

clear

echo "================================"
echo " 宝塔安全修复工具"
echo "================================"

echo ""
echo "[1] 检查Fail2ban"
systemctl status fail2ban --no-pager

echo ""
echo "[2] 检查SSH爆破"
lastb | head

echo ""
echo "[3] 检查计划任务"
crontab -l

echo ""
echo "[4] 检查异常进程"
ps aux --sort=-%cpu | head

echo ""
echo "[5] 检查恶意端口"
ss -lntp

echo ""
echo "[6] 检查木马文件"
find /www/wwwroot -name "*.php" | xargs grep -lE 'eval\(|assert\('

echo ""
echo "修复权限"
chown -R www:www /www/wwwroot

echo ""
echo "完成"
