#!/bin/bash

# 修复 profile API 500 错误

set -e

echo "=========================================="
echo "🔧 修复 profile API 500 错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查数据库字段是否存在
echo ""
echo "ℹ️ 步骤1: 检查数据库字段..."
if mysql -u root -ppassword canteen_recommendation -e "SELECT role, is_admin FROM users LIMIT 1" 2>/dev/null; then
    echo "✅ role 和 is_admin 字段已存在"
else
    echo "⚠️ role 和 is_admin 字段不存在，添加字段..."
    mysql -u root -ppassword canteen_recommendation << 'SQL' 2>&1 | grep -v "Duplicate column" || true
ALTER TABLE users ADD COLUMN role VARCHAR(20) DEFAULT 'user' AFTER email;
ALTER TABLE users ADD COLUMN is_admin BOOLEAN DEFAULT FALSE AFTER role;
CREATE INDEX idx_role ON users(role);
CREATE INDEX idx_is_admin ON users(is_admin);
SQL
    echo "✅ 字段已添加"
fi

# 2. 重启后端服务
echo ""
echo "ℹ️ 步骤2: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 3

if systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行正常"
else
    echo "❌ 后端服务启动失败，查看日志:"
    sudo journalctl -u canteen-backend -n 20 --no-pager
    exit 1
fi

# 3. 测试 profile API
echo ""
echo "ℹ️ 步骤3: 测试 profile API..."
# 获取一个测试 token（需要先登录）
echo "请先登录获取 token，然后测试:"
echo "  curl -H 'Authorization: Bearer YOUR_TOKEN' http://localhost:5000/api/v1/profile"
echo ""

# 4. 检查后端日志
echo ""
echo "ℹ️ 步骤4: 检查后端日志（最近 10 行）..."
sudo journalctl -u canteen-backend -n 10 --no-pager | grep -i "profile\|error\|traceback" || echo "未发现相关错误"

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "如果问题仍然存在，请："
echo "  1. 查看后端日志: sudo journalctl -u canteen-backend -f"
echo "  2. 检查数据库字段: mysql -u root -ppassword canteen_recommendation -e 'DESCRIBE users;'"
echo "  3. 测试 API: curl -H 'Authorization: Bearer YOUR_TOKEN' http://localhost:5000/api/v1/profile"
echo ""

