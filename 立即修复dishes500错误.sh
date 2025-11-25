#!/bin/bash

# 立即修复 dishes API 500 错误

set -e

echo "=========================================="
echo "🔧 立即修复 dishes API 500 错误"
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
echo "ℹ️ 步骤2: 查看最近的错误日志..."
echo "最近 30 行日志:"
sudo journalctl -u canteen-backend -n 30 --no-pager | tail -20

# 3. 测试数据库连接
echo ""
echo "ℹ️ 步骤3: 测试数据库连接..."
if mysql -u root -ppassword -e "SELECT 1;" canteen_recommendation >/dev/null 2>&1; then
    echo "✅ 数据库连接正常"
    
    # 测试 dishes 表查询
    echo "测试 dishes 表查询:"
    mysql -u root -ppassword -e "SELECT COUNT(*) as count FROM dishes;" canteen_recommendation 2>&1 | tail -1
    
    # 测试分类查询
    echo "测试分类查询:"
    mysql -u root -ppassword -e "SELECT DISTINCT category FROM dishes WHERE category IS NOT NULL LIMIT 5;" canteen_recommendation 2>&1 | tail -5
else
    echo "❌ 数据库连接失败"
    echo "请检查 MySQL 服务状态: sudo systemctl status mysql"
fi

# 4. 重启后端服务
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
categories_test=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/v1/dishes/categories 2>&1)
if [ "$categories_test" = "200" ]; then
    echo "✅ 分类 API 正常 (HTTP $categories_test)"
    curl -s http://localhost:5000/api/v1/dishes/categories | python3 -m json.tool 2>/dev/null | head -10 || curl -s http://localhost:5000/api/v1/dishes/categories
else
    echo "❌ 分类 API 返回 HTTP $categories_test"
    echo "完整响应:"
    curl -s http://localhost:5000/api/v1/dishes/categories
    echo ""
fi

# 测试菜品列表 API
echo ""
echo "测试 /api/v1/dishes?page=1&per_page=5:"
dishes_test=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5000/api/v1/dishes?page=1&per_page=5" 2>&1)
if [ "$dishes_test" = "200" ]; then
    echo "✅ 菜品列表 API 正常 (HTTP $dishes_test)"
    dish_count=$(curl -s "http://localhost:5000/api/v1/dishes?page=1&per_page=5" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('dishes', [])))" 2>/dev/null || echo "N/A")
    echo "   返回 $dish_count 个菜品"
else
    echo "❌ 菜品列表 API 返回 HTTP $dishes_test"
    echo "完整响应:"
    curl -s "http://localhost:5000/api/v1/dishes?page=1&per_page=5"
    echo ""
fi

# 6. 查看实时日志（如果有错误）
echo ""
echo "ℹ️ 步骤6: 检查是否有新错误..."
recent_errors=$(sudo journalctl -u canteen-backend --since "1 minute ago" --no-pager | grep -i "error\|exception\|traceback" | tail -5)
if [ -n "$recent_errors" ]; then
    echo "⚠️ 发现新错误:"
    echo "$recent_errors"
else
    echo "✅ 未发现新错误"
fi

# 7. 如果仍有问题，提供诊断建议
echo ""
echo "=========================================="
echo "📋 诊断结果"
echo "=========================================="
if [ "$categories_test" = "200" ] && [ "$dishes_test" = "200" ]; then
    echo "✅ 所有 API 测试通过"
    echo ""
    echo "如果前端仍然显示 500 错误，请："
    echo "1. 清除浏览器缓存"
    echo "2. 硬刷新页面 (Ctrl+Shift+R 或 Cmd+Shift+R)"
    echo "3. 检查 Nginx 日志: sudo tail -f /var/log/nginx/error.log"
else
    echo "❌ 仍有 API 返回错误"
    echo ""
    echo "请执行以下命令查看详细日志:"
    echo "  sudo journalctl -u canteen-backend -f"
    echo ""
    echo "或运行诊断脚本:"
    echo "  ./诊断dishes500错误.sh"
fi
echo ""

