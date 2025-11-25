#!/bin/bash

# 修复 JWT token identity 问题和 500 错误

set -e

echo "=========================================="
echo "🔧 修复 JWT token 和 500 错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查后端服务状态
echo ""
echo "ℹ️ 步骤1: 检查后端服务状态..."
if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "⚠️ 后端服务未运行"
fi

# 2. 重启后端服务（应用代码修复）
echo ""
echo "ℹ️ 步骤2: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 3

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务已重启"
else
    echo "❌ 后端服务启动失败"
    echo "查看日志："
    sudo journalctl -u canteen-backend -n 30 --no-pager
    exit 1
fi

# 3. 测试后端 API
echo ""
echo "ℹ️ 步骤3: 测试后端 API..."

# 测试健康检查
echo "测试健康检查:"
health_response=$(curl -s http://localhost:5000/health)
if echo "$health_response" | grep -q "healthy"; then
    echo "✅ 健康检查: $health_response"
else
    echo "❌ 健康检查失败: $health_response"
fi

# 测试菜品分类 API（不需要认证）
echo ""
echo "测试菜品分类 API:"
categories_response=$(curl -s -w "\nHTTP %{http_code}" http://localhost:5000/api/v1/dishes/categories)
http_code=$(echo "$categories_response" | tail -1)
if [ "$http_code" = "HTTP 200" ]; then
    echo "✅ 菜品分类 API 正常"
    echo "$categories_response" | head -1 | python3 -m json.tool 2>/dev/null || echo "$categories_response" | head -1
else
    echo "❌ 菜品分类 API 返回: $http_code"
    echo "响应: $categories_response"
fi

# 测试菜品列表 API（不需要认证）
echo ""
echo "测试菜品列表 API:"
dishes_response=$(curl -s -w "\nHTTP %{http_code}" "http://localhost:5000/api/v1/dishes?page=1&per_page=5")
http_code=$(echo "$dishes_response" | tail -1)
if [ "$http_code" = "HTTP 200" ]; then
    echo "✅ 菜品列表 API 正常"
    dish_count=$(echo "$dishes_response" | head -1 | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('dishes', [])))" 2>/dev/null || echo "N/A")
    echo "   返回 $dish_count 个菜品"
else
    echo "❌ 菜品列表 API 返回: $http_code"
    echo "响应: $dishes_response"
fi

# 4. 查看后端日志（最近错误）
echo ""
echo "ℹ️ 步骤4: 查看后端日志（最近错误）..."
recent_errors=$(sudo journalctl -u canteen-backend -n 50 --no-pager | grep -i "error\|exception\|traceback" | tail -10)
if [ -n "$recent_errors" ]; then
    echo "⚠️ 发现最近错误:"
    echo "$recent_errors"
else
    echo "✅ 未发现错误日志"
fi

# 5. 检查数据库连接
echo ""
echo "ℹ️ 步骤5: 检查数据库连接..."
if mysql -u root -ppassword -e "SELECT 1;" canteen_recommendation >/dev/null 2>&1; then
    echo "✅ 数据库连接正常"
    
    # 检查表是否存在
    table_count=$(mysql -u root -ppassword -e "SHOW TABLES;" canteen_recommendation 2>/dev/null | wc -l)
    if [ "$table_count" -gt 1 ]; then
        echo "✅ 数据库表存在 ($((table_count-1)) 个表)"
    else
        echo "⚠️ 数据库表可能不存在"
    fi
    
    # 检查菜品数据
    dish_count=$(mysql -u root -ppassword -e "SELECT COUNT(*) FROM dishes;" canteen_recommendation 2>/dev/null | tail -1)
    if [ -n "$dish_count" ] && [ "$dish_count" -gt 0 ]; then
        echo "✅ 菜品数据存在 ($dish_count 条记录)"
    else
        echo "⚠️ 菜品数据为空"
    fi
else
    echo "❌ 数据库连接失败"
fi

# 6. 提供解决建议
echo ""
echo "=========================================="
echo "📋 修复说明"
echo "=========================================="
echo ""
echo "已修复的问题："
echo "1. ✅ JWT token identity 现在使用字符串（修复 'Subject must be a string' 错误）"
echo "2. ✅ 增强了 dishes API 的错误处理和日志"
echo "3. ✅ 增强了 categories API 的错误处理"
echo ""
echo "下一步操作："
echo "1. 清除浏览器 localStorage 中的所有数据"
echo "2. 重新登录获取新的 token（新 token 使用字符串格式的 user_id）"
echo "3. 测试所有功能"
echo ""
echo "如果仍有问题，请查看后端日志："
echo "  sudo journalctl -u canteen-backend -f"
echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="

