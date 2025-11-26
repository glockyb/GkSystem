#!/bin/bash

# 诊断 profile API 500 错误

set -e

echo "=========================================="
echo "🔍 诊断 profile API 500 错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查后端服务状态
echo ""
echo "ℹ️ 步骤1: 检查后端服务状态..."
if systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "❌ 后端服务未运行"
    exit 1
fi

# 2. 查看后端日志（最近 50 行，包含 profile 相关）
echo ""
echo "ℹ️ 步骤2: 查看后端日志（profile 相关）..."
sudo journalctl -u canteen-backend -n 50 --no-pager | grep -A 10 -B 5 -i "profile\|traceback\|error\|exception" || echo "未发现相关错误"

# 3. 检查数据库字段
echo ""
echo "ℹ️ 步骤3: 检查数据库字段..."
mysql -u root -ppassword canteen_recommendation -e "DESCRIBE users;" 2>/dev/null | grep -E "role|is_admin" || echo "⚠️ role 或 is_admin 字段不存在"

# 4. 测试数据库查询
echo ""
echo "ℹ️ 步骤4: 测试数据库查询..."
mysql -u root -ppassword canteen_recommendation -e "SELECT id, username, email, role, is_admin, created_at FROM users LIMIT 1;" 2>&1

# 5. 测试 profile API（需要 token）
echo ""
echo "ℹ️ 步骤5: 测试 profile API..."
echo "请先登录获取 token，然后运行："
echo "  curl -H 'Authorization: Bearer YOUR_TOKEN' http://localhost:5000/api/v1/profile"
echo ""

# 6. 检查 Python 代码语法
echo ""
echo "ℹ️ 步骤6: 检查 Python 代码语法..."
cd backend
if [ -d "venv" ]; then
    source venv/bin/activate
fi

python3 << 'PYTHON_TEST'
import sys
sys.path.insert(0, '.')

try:
    from api import auth
    print("✅ auth 模块导入成功")
    
    # 检查 get_profile 函数
    if hasattr(auth.bp, 'view_functions'):
        print("✅ auth blueprint 正常")
    else:
        print("⚠️ auth blueprint 可能有问题")
        
except Exception as e:
    print(f"❌ 导入失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON_TEST

cd ..

# 7. 显示完整错误日志
echo ""
echo "ℹ️ 步骤7: 显示最近完整日志..."
sudo journalctl -u canteen-backend -n 20 --no-pager

echo ""
echo "=========================================="
echo "📋 诊断完成"
echo "=========================================="
echo ""
echo "如果看到错误信息，请提供完整的 traceback"
echo ""

