#!/bin/bash

# 立即修复 categories API 500 错误

set -e

echo "=========================================="
echo "🔧 立即修复 categories API 500 错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查后端服务
echo ""
echo "ℹ️ 步骤1: 检查后端服务..."
if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "⚠️ 后端服务未运行，启动服务..."
    sudo systemctl start canteen-backend
    sleep 3
fi

# 2. 查看最近的错误日志
echo ""
echo "ℹ️ 步骤2: 查看最近的错误日志（最近 50 行）..."
echo "----------------------------------------"
sudo journalctl -u canteen-backend -n 50 --no-pager | tail -30
echo "----------------------------------------"

# 3. 测试数据库连接和查询
echo ""
echo "ℹ️ 步骤3: 测试数据库连接和查询..."
if mysql -u root -ppassword -e "SELECT 1;" canteen_recommendation >/dev/null 2>&1; then
    echo "✅ 数据库连接正常"
    
    echo ""
    echo "测试分类查询:"
    mysql -u root -ppassword -e "SELECT DISTINCT category FROM dishes WHERE category IS NOT NULL;" canteen_recommendation 2>&1 | head -20
    
    echo ""
    echo "检查分类数量:"
    mysql -u root -ppassword -e "SELECT COUNT(DISTINCT category) as category_count FROM dishes WHERE category IS NOT NULL;" canteen_recommendation 2>&1 | tail -1
else
    echo "❌ 数据库连接失败"
    echo "请检查 MySQL 服务状态: sudo systemctl status mysql"
    exit 1
fi

# 4. 重启后端服务（应用代码修复）
echo ""
echo "ℹ️ 步骤4: 重启后端服务（应用代码修复）..."
sudo systemctl restart canteen-backend
sleep 3

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务已重启"
else
    echo "❌ 后端服务启动失败"
    echo "查看错误日志:"
    sudo journalctl -u canteen-backend -n 50 --no-pager | grep -i "error\|exception\|traceback" | tail -10
    exit 1
fi

# 5. 测试 API
echo ""
echo "ℹ️ 步骤5: 测试 API..."

# 测试分类 API
echo "测试 /api/v1/dishes/categories:"
categories_response=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:5000/api/v1/dishes/categories 2>&1)
http_code=$(echo "$categories_response" | grep "HTTP_CODE" | cut -d: -f2)
response_body=$(echo "$categories_response" | grep -v "HTTP_CODE")

echo "HTTP 状态码: $http_code"
if [ "$http_code" = "200" ]; then
    echo "✅ 分类 API 正常"
    echo "响应内容:"
    echo "$response_body" | python3 -m json.tool 2>/dev/null || echo "$response_body"
    
    # 检查分类数量
    category_count=$(echo "$response_body" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('categories', [])))" 2>/dev/null || echo "N/A")
    echo ""
    echo "分类数量: $category_count"
else
    echo "❌ 分类 API 返回 HTTP $http_code"
    echo "完整响应:"
    echo "$response_body"
    echo ""
    echo "查看后端日志:"
    sudo journalctl -u canteen-backend -n 20 --no-pager | tail -10
fi

# 6. 查看实时日志（如果有错误）
echo ""
echo "ℹ️ 步骤6: 检查是否有新错误..."
# 只查找真正的错误，排除 HTTP 200 等成功状态码
recent_errors=$(sudo journalctl -u canteen-backend --since "1 minute ago" --no-pager | grep -iE "error|exception|traceback|failed|500|502|503|504" | grep -v "HTTP/1.1\" 200" | tail -10)
if [ -n "$recent_errors" ]; then
    echo "⚠️ 发现新错误:"
    echo "$recent_errors"
else
    echo "✅ 未发现新错误"
    echo ""
    echo "最近的成功请求:"
    sudo journalctl -u canteen-backend --since "1 minute ago" --no-pager | grep "HTTP/1.1\" 200" | tail -5
fi

# 7. 如果仍有问题，提供诊断建议
echo ""
echo "=========================================="
echo "📋 诊断结果"
echo "=========================================="
if [ "$http_code" = "200" ]; then
    echo "✅ categories API 测试通过"
    echo ""
    echo "如果前端仍然显示 500 错误，请："
    echo "1. 清除浏览器缓存"
    echo "2. 硬刷新页面 (Ctrl+Shift+R 或 Cmd+Shift+R)"
    echo "3. 检查 Nginx 日志: sudo tail -f /var/log/nginx/error.log"
    echo "4. 检查 Nginx 代理配置: sudo cat /etc/nginx/sites-available/canteen | grep -A 10 'location /api'"
else
    echo "❌ categories API 仍然返回错误"
    echo ""
    echo "请执行以下命令查看详细日志:"
    echo "  sudo journalctl -u canteen-backend -f"
    echo ""
    echo "或运行诊断脚本:"
    echo "  ./诊断categories500错误.sh"
    echo ""
    echo "检查数据库:"
    echo "  mysql -u root -ppassword canteen_recommendation -e 'SELECT DISTINCT category FROM dishes WHERE category IS NOT NULL;'"
fi
echo ""

