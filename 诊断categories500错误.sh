#!/bin/bash

# 诊断 categories API 500 错误

set -e

echo "=========================================="
echo "🔍 诊断 categories API 500 错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查后端服务状态
echo ""
echo "ℹ️ 步骤1: 检查后端服务状态..."
if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "❌ 后端服务未运行"
    exit 1
fi

# 2. 查看最近的错误日志
echo ""
echo "ℹ️ 步骤2: 查看最近的错误日志（最近 50 行）..."
echo "----------------------------------------"
sudo journalctl -u canteen-backend -n 50 --no-pager | tail -30
echo "----------------------------------------"

# 3. 查看 categories 相关的错误
echo ""
echo "ℹ️ 步骤3: 查看 categories 相关的错误..."
categories_errors=$(sudo journalctl -u canteen-backend -n 200 --no-pager | grep -i "categories\|category\|dishes\|error\|exception\|traceback" | tail -30)
if [ -n "$categories_errors" ]; then
    echo "发现相关错误:"
    echo "$categories_errors"
else
    echo "未发现明显的 categories 相关错误"
fi

# 4. 测试数据库连接和查询
echo ""
echo "ℹ️ 步骤4: 测试数据库连接和查询..."
if mysql -u root -ppassword -e "SELECT 1;" canteen_recommendation >/dev/null 2>&1; then
    echo "✅ 数据库连接正常"
    
    echo ""
    echo "测试分类查询:"
    mysql -u root -ppassword -e "SELECT DISTINCT category FROM dishes WHERE category IS NOT NULL;" canteen_recommendation 2>&1
    
    echo ""
    echo "检查 dishes 表结构:"
    mysql -u root -ppassword -e "DESCRIBE dishes;" canteen_recommendation 2>&1 | head -10
    
    echo ""
    echo "检查 dishes 表数据（前 5 条）:"
    mysql -u root -ppassword -e "SELECT id, name, category FROM dishes LIMIT 5;" canteen_recommendation 2>&1
    
    echo ""
    echo "检查 NULL category 的数量:"
    mysql -u root -ppassword -e "SELECT COUNT(*) as null_count FROM dishes WHERE category IS NULL;" canteen_recommendation 2>&1
    
    echo ""
    echo "检查非 NULL category 的数量:"
    mysql -u root -ppassword -e "SELECT COUNT(*) as not_null_count FROM dishes WHERE category IS NOT NULL;" canteen_recommendation 2>&1
else
    echo "❌ 数据库连接失败"
fi

# 5. 测试后端 API（直接访问）
echo ""
echo "ℹ️ 步骤5: 测试后端 API（直接访问）..."
echo "测试 /api/v1/dishes/categories:"
categories_response=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:5000/api/v1/dishes/categories 2>&1)
http_code=$(echo "$categories_response" | grep "HTTP_CODE" | cut -d: -f2)
response_body=$(echo "$categories_response" | grep -v "HTTP_CODE")
echo "HTTP 状态码: $http_code"
echo "响应内容:"
echo "$response_body" | head -20

# 6. 检查 Python 代码
echo ""
echo "ℹ️ 步骤6: 检查 Python 代码语法..."
if python3 -m py_compile backend/api/dishes.py 2>&1; then
    echo "✅ dishes.py 语法正确"
else
    echo "❌ dishes.py 语法错误"
    python3 -m py_compile backend/api/dishes.py
fi

# 7. 测试 Python 导入和函数
echo ""
echo "ℹ️ 步骤7: 测试 Python 模块导入..."
cd backend
if python3 -c "
import sys
sys.path.insert(0, '.')
from utils.database import db
try:
    conn = db.get_connection()
    if conn:
        cursor = conn.cursor()
        cursor.execute('SELECT DISTINCT category FROM dishes WHERE category IS NOT NULL')
        rows = cursor.fetchall()
        print(f'✅ 数据库查询成功，找到 {len(rows)} 个分类')
        if rows:
            print('前 5 个分类:', [row.get('category') if isinstance(row, dict) else row[0] for row in rows[:5]])
        cursor.close()
    else:
        print('❌ 无法获取数据库连接')
except Exception as e:
    print(f'❌ 错误: {e}')
    import traceback
    traceback.print_exc()
" 2>&1; then
    echo "✅ Python 模块和数据库查询测试完成"
else
    echo "❌ Python 模块测试失败"
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
echo "2. 在另一个终端测试 API: curl -v http://localhost:5000/api/v1/dishes/categories"
echo "3. 检查数据库: mysql -u root -ppassword canteen_recommendation -e 'SELECT DISTINCT category FROM dishes WHERE category IS NOT NULL;'"
echo ""

