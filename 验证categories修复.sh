#!/bin/bash

# 验证 categories API 修复

set -e

echo "=========================================="
echo "✅ 验证 categories API 修复"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 测试 API
echo ""
echo "ℹ️ 步骤1: 测试 categories API..."
echo "----------------------------------------"

categories_response=$(curl -s http://localhost:5000/api/v1/dishes/categories)
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/v1/dishes/categories)

echo "HTTP 状态码: $http_code"
echo ""

if [ "$http_code" = "200" ]; then
    echo "✅ API 返回成功 (HTTP 200)"
    echo ""
    echo "响应内容:"
    echo "$categories_response" | python3 -m json.tool 2>/dev/null || echo "$categories_response"
    echo ""
    
    # 解析响应
    category_count=$(echo "$categories_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('categories', [])))" 2>/dev/null || echo "0")
    categories_list=$(echo "$categories_response" | python3 -c "import sys, json; data=json.load(sys.stdin); print(', '.join(data.get('categories', [])[:10]))" 2>/dev/null || echo "N/A")
    
    echo "分类数量: $category_count"
    if [ "$category_count" -gt 0 ]; then
        echo "分类列表（前10个）: $categories_list"
    else
        echo "⚠️ 未找到分类数据，但 API 正常工作"
        echo "   这可能是正常的，如果数据库中没有分类数据"
    fi
else
    echo "❌ API 返回错误 (HTTP $http_code)"
    echo "响应内容:"
    echo "$categories_response"
    exit 1
fi

# 2. 测试通过 Nginx 代理
echo ""
echo "ℹ️ 步骤2: 测试通过 Nginx 代理..."
echo "----------------------------------------"

nginx_response=$(curl -s http://localhost/api/v1/dishes/categories)
nginx_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/v1/dishes/categories)

echo "HTTP 状态码: $nginx_code"
echo ""

if [ "$nginx_code" = "200" ]; then
    echo "✅ Nginx 代理正常 (HTTP 200)"
    echo ""
    echo "响应内容:"
    echo "$nginx_response" | python3 -m json.tool 2>/dev/null || echo "$nginx_response"
else
    echo "❌ Nginx 代理返回错误 (HTTP $nginx_code)"
    echo "响应内容:"
    echo "$nginx_response"
    echo ""
    echo "检查 Nginx 配置:"
    sudo cat /etc/nginx/sites-available/canteen | grep -A 10 "location /api"
fi

# 3. 检查后端日志
echo ""
echo "ℹ️ 步骤3: 检查后端日志（最近 10 条 categories 相关日志）..."
echo "----------------------------------------"
sudo journalctl -u canteen-backend -n 100 --no-pager | grep -i "categories\|category" | tail -10 || echo "未找到相关日志"

# 4. 总结
echo ""
echo "=========================================="
echo "📋 验证结果"
echo "=========================================="
if [ "$http_code" = "200" ] && [ "$nginx_code" = "200" ]; then
    echo "✅ categories API 完全正常！"
    echo ""
    echo "📱 访问地址:"
    echo "   直接访问后端: http://119.3.232.65:5000/api/v1/dishes/categories"
    echo "   通过 Nginx: http://119.3.232.65/api/v1/dishes/categories"
    echo ""
    echo "💡 如果前端仍然显示错误，请："
    echo "   1. 清除浏览器缓存 (Ctrl+Shift+R 或 Cmd+Shift+R)"
    echo "   2. 清除浏览器 localStorage (F12 → Application → Local Storage)"
    echo "   3. 检查浏览器控制台 (F12 → Console)"
else
    echo "❌ 仍有问题需要解决"
    echo ""
    echo "请查看详细日志:"
    echo "   sudo journalctl -u canteen-backend -f"
fi
echo ""

