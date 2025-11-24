#!/bin/bash
# 查看 Nginx 错误日志

if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

echo "=========================================="
echo "Nginx 错误日志"
echo "=========================================="
echo ""

# 查看所有错误日志文件
echo "1. 查看 canteen-error.log:"
if [ -f /var/log/nginx/canteen-error.log ]; then
    $SUDO tail -50 /var/log/nginx/canteen-error.log
else
    echo "文件不存在"
fi

echo ""
echo "2. 查看 error.log:"
if [ -f /var/log/nginx/error.log ]; then
    $SUDO tail -50 /var/log/nginx/error.log
else
    echo "文件不存在"
fi

echo ""
echo "=========================================="
echo "Nginx 配置检查"
echo "=========================================="
echo ""

echo "3. 查看 canteen 配置:"
$SUDO cat /etc/nginx/sites-available/canteen

echo ""
echo "4. 检查配置中的路径:"
CONFIG_ROOT=$(grep -E "^\s*root" /etc/nginx/sites-available/canteen | head -1 | awk '{print $2}' | tr -d ';')
echo "配置路径: $CONFIG_ROOT"

echo ""
echo "5. 检查路径是否存在:"
if [ -d "$CONFIG_ROOT" ]; then
    echo "✅ 路径存在"
    ls -la "$CONFIG_ROOT" | head -5
else
    echo "❌ 路径不存在"
fi

echo ""
echo "6. 实际前端路径:"
REAL_PATH=$(readlink -f ~/gksys/GkSystem/frontend/dist 2>/dev/null || echo "~/gksys/GkSystem/frontend/dist")
echo "$REAL_PATH"
if [ -d "$REAL_PATH" ]; then
    echo "✅ 实际路径存在"
    ls -la "$REAL_PATH" | head -5
else
    echo "❌ 实际路径不存在"
fi

