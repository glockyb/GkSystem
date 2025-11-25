#!/bin/bash

# 诊断 dishes API 500 错误

set -e

echo "=========================================="
echo "🔍 诊断 dishes API 500 错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查后端服务状态
echo ""
echo "ℹ️ 步骤1: 检查后端服务状态..."
if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
    sudo systemctl status canteen-backend --no-pager -l | head -10
else
    echo "❌ 后端服务未运行"
    exit 1
fi

# 2. 查看后端日志（最近 100 行）
echo ""
echo "ℹ️ 步骤2: 查看后端日志（最近 100 行）..."
echo "----------------------------------------"
sudo journalctl -u canteen-backend -n 100 --no-pager | tail -50
echo "----------------------------------------"

# 3. 查看 dishes API 相关错误
echo ""
echo "ℹ️ 步骤3: 查看 dishes API 相关错误..."
dishes_errors=$(sudo journalctl -u canteen-backend -n 200 --no-pager | grep -i "dishes\|dish\|500\|error\|exception\|traceback" | tail -20)
if [ -n "$dishes_errors" ]; then
    echo "发现相关错误:"
    echo "$dishes_errors"
else
    echo "未发现明显的 dishes 相关错误"
fi

# 4. 测试后端 API（直接访问）
echo ""
echo "ℹ️ 步骤4: 测试后端 API（直接访问）..."
echo "测试 /api/v1/dishes/categories:"
categories_response=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:5000/api/v1/dishes/categories 2>&1)
http_code=$(echo "$categories_response" | grep "HTTP_CODE" | cut -d: -f2)
response_body=$(echo "$categories_response" | grep -v "HTTP_CODE")
echo "HTTP 状态码: $http_code"
if [ "$http_code" = "200" ]; then
    echo "✅ 分类 API 正常"
    echo "响应: $response_body" | head -5
else
    echo "❌ 分类 API 返回错误"
    echo "完整响应: $response_body"
fi

echo ""
echo "测试 /api/v1/dishes?page=1&per_page=5:"
dishes_response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost:5000/api/v1/dishes?page=1&per_page=5" 2>&1)
http_code=$(echo "$dishes_response" | grep "HTTP_CODE" | cut -d: -f2)
response_body=$(echo "$dishes_response" | grep -v "HTTP_CODE")
echo "HTTP 状态码: $http_code"
if [ "$http_code" = "200" ]; then
    echo "✅ 菜品列表 API 正常"
    echo "响应前 200 字符: ${response_body:0:200}..."
else
    echo "❌ 菜品列表 API 返回错误"
    echo "完整响应: $response_body"
fi

# 5. 检查数据库连接
echo ""
echo "ℹ️ 步骤5: 检查数据库连接..."
if mysql -u root -ppassword -e "SELECT 1;" canteen_recommendation >/dev/null 2>&1; then
    echo "✅ 数据库连接正常"
    
    # 检查 dishes 表
    if mysql -u root -ppassword -e "SHOW TABLES LIKE 'dishes';" canteen_recommendation | grep -q "dishes"; then
        echo "✅ dishes 表存在"
        
        # 检查表结构
        echo "表结构:"
        mysql -u root -ppassword -e "DESCRIBE dishes;" canteen_recommendation 2>/dev/null | head -10
        
        # 检查数据
        dish_count=$(mysql -u root -ppassword -e "SELECT COUNT(*) FROM dishes;" canteen_recommendation 2>/dev/null | tail -1)
        echo "菜品数量: $dish_count"
        
        # 检查是否有 NULL category
        null_category_count=$(mysql -u root -ppassword -e "SELECT COUNT(*) FROM dishes WHERE category IS NULL;" canteen_recommendation 2>/dev/null | tail -1)
        if [ "$null_category_count" -gt 0 ]; then
            echo "⚠️ 发现 $null_category_count 个菜品的 category 为 NULL"
        fi
    else
        echo "❌ dishes 表不存在"
    fi
else
    echo "❌ 数据库连接失败"
fi

# 6. 检查 Python 代码语法
echo ""
echo "ℹ️ 步骤6: 检查 Python 代码语法..."
if python3 -m py_compile backend/api/dishes.py 2>&1; then
    echo "✅ dishes.py 语法正确"
else
    echo "❌ dishes.py 语法错误"
    python3 -m py_compile backend/api/dishes.py
fi

# 7. 测试 Python 导入
echo ""
echo "ℹ️ 步骤7: 测试 Python 模块导入..."
cd backend
if python3 -c "from api.dishes import bp; print('✅ dishes 模块导入成功')" 2>&1; then
    echo "✅ dishes 模块可以正常导入"
else
    echo "❌ dishes 模块导入失败"
    python3 -c "from api.dishes import bp" 2>&1
fi
cd ..

# 8. 查看实时日志
echo ""
echo "=========================================="
echo "📋 诊断完成"
echo "=========================================="
echo ""
echo "如果问题仍然存在，请："
echo "1. 查看实时日志: sudo journalctl -u canteen-backend -f"
echo "2. 在另一个终端测试 API: curl -v http://localhost:5000/api/v1/dishes?page=1&per_page=5"
echo "3. 检查数据库: mysql -u root -ppassword canteen_recommendation -e 'SELECT * FROM dishes LIMIT 5;'"
echo ""

