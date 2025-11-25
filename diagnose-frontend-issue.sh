#!/bin/bash

# 诊断前端问题

set -e

echo "=========================================="
echo "🔍 诊断前端问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查 Nginx 状态
echo ""
echo "ℹ️ 步骤1: 检查 Nginx 状态..."
if sudo systemctl is-active --quiet nginx; then
    echo "✅ Nginx 运行中"
else
    echo "❌ Nginx 未运行"
    sudo systemctl status nginx --no-pager -l
fi

# 2. 检查前端文件
echo ""
echo "ℹ️ 步骤2: 检查前端文件..."
if [ -d "/var/www/canteen" ]; then
    echo "✅ /var/www/canteen 目录存在"
    file_count=$(sudo find /var/www/canteen -type f | wc -l)
    echo "   文件数量: $file_count"
    
    if [ -f "/var/www/canteen/index.html" ]; then
        echo "✅ index.html 存在"
        echo "   文件大小: $(sudo stat -c%s /var/www/canteen/index.html) 字节"
    else
        echo "❌ index.html 不存在"
    fi
else
    echo "❌ /var/www/canteen 目录不存在"
fi

# 3. 检查文件权限
echo ""
echo "ℹ️ 步骤3: 检查文件权限..."
if [ -d "/var/www/canteen" ]; then
    owner=$(sudo stat -c '%U:%G' /var/www/canteen)
    echo "   所有者: $owner"
    if [ "$owner" = "www-data:www-data" ]; then
        echo "✅ 权限正确"
    else
        echo "⚠️ 权限可能不正确，应该是 www-data:www-data"
    fi
fi

# 4. 检查 Nginx 配置
echo ""
echo "ℹ️ 步骤4: 检查 Nginx 配置..."
if [ -f "/etc/nginx/sites-available/canteen" ]; then
    echo "✅ Nginx 配置文件存在"
    if sudo nginx -t 2>&1 | grep -q "successful"; then
        echo "✅ Nginx 配置语法正确"
    else
        echo "❌ Nginx 配置语法错误"
        sudo nginx -t
    fi
else
    echo "❌ Nginx 配置文件不存在"
fi

# 5. 检查后端服务
echo ""
echo "ℹ️ 步骤5: 检查后端服务..."
if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "❌ 后端服务未运行"
    sudo systemctl status canteen-backend --no-pager -l
fi

# 6. 测试本地访问
echo ""
echo "ℹ️ 步骤6: 测试本地访问..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200"; then
    echo "✅ 本地访问正常 (HTTP 200)"
else
    http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
    echo "❌ 本地访问失败 (HTTP $http_code)"
fi

# 7. 测试 API
echo ""
echo "ℹ️ 步骤7: 测试 API..."
if curl -s http://localhost/api/v1/dishes/categories | grep -q "categories\|error"; then
    echo "✅ API 可访问"
    curl -s http://localhost/api/v1/dishes/categories | head -c 200
    echo ""
else
    echo "❌ API 不可访问"
fi

# 8. 检查 Nginx 错误日志
echo ""
echo "ℹ️ 步骤8: 检查 Nginx 错误日志（最近5行）..."
if [ -f "/var/log/nginx/error.log" ]; then
    echo "最近错误:"
    sudo tail -5 /var/log/nginx/error.log || echo "无错误日志"
else
    echo "⚠️ 错误日志文件不存在"
fi

# 9. 检查前端构建文件
echo ""
echo "ℹ️ 步骤9: 检查前端构建文件..."
if [ -d "frontend/dist" ]; then
    echo "✅ frontend/dist 目录存在"
    dist_files=$(find frontend/dist -type f | wc -l)
    echo "   文件数量: $dist_files"
    
    if [ -f "frontend/dist/index.html" ]; then
        echo "✅ dist/index.html 存在"
        echo "   文件大小: $(stat -c%s frontend/dist/index.html) 字节"
    else
        echo "❌ dist/index.html 不存在"
    fi
else
    echo "❌ frontend/dist 目录不存在，需要重新构建"
fi

# 10. 检查前端构建配置
echo ""
echo "ℹ️ 步骤10: 检查前端构建配置..."
if [ -f "frontend/vite.config.js" ]; then
    echo "✅ vite.config.js 存在"
    if grep -q "VITE_API_URL" frontend/vite.config.js; then
        echo "⚠️ 发现 VITE_API_URL 配置，可能影响 API 调用"
    fi
fi

echo ""
echo "=========================================="
echo "✅ 诊断完成"
echo "=========================================="
echo ""
echo "📋 建议操作："
echo "1. 如果前端文件不存在或损坏，重新构建并部署"
echo "2. 如果权限不正确，运行: sudo chown -R www-data:www-data /var/www/canteen"
echo "3. 如果 Nginx 配置错误，检查: sudo nginx -t"
echo "4. 查看详细日志: sudo tail -f /var/log/nginx/error.log"
echo ""

