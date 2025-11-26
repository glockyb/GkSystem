#!/bin/bash

# 立即修复 profile API 500 错误

set -e

echo "=========================================="
echo "🔧 立即修复 profile API 500 错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 确保数据库字段存在
echo ""
echo "ℹ️ 步骤1: 确保数据库字段存在..."
mysql -u root -ppassword canteen_recommendation << 'SQL' 2>&1 | grep -v "Duplicate column\|Duplicate key" || true
ALTER TABLE users ADD COLUMN role VARCHAR(20) DEFAULT 'user' AFTER email;
ALTER TABLE users ADD COLUMN is_admin BOOLEAN DEFAULT FALSE AFTER role;
CREATE INDEX idx_role ON users(role);
CREATE INDEX idx_is_admin ON users(is_admin);
SQL

# 2. 重启后端服务
echo ""
echo "ℹ️ 步骤2: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 4

# 3. 检查服务状态
echo ""
echo "ℹ️ 步骤3: 检查服务状态..."
if systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行正常"
    
    # 测试健康检查
    sleep 1
    if curl -s http://localhost:5000/health | grep -q "healthy"; then
        echo "✅ 健康检查通过"
    else
        echo "⚠️ 健康检查失败"
    fi
else
    echo "❌ 后端服务启动失败"
    echo "查看错误日志:"
    sudo journalctl -u canteen-backend -n 30 --no-pager | tail -20
    exit 1
fi

# 4. 查看最近日志
echo ""
echo "ℹ️ 步骤4: 查看最近日志（最后 15 行）..."
sudo journalctl -u canteen-backend -n 15 --no-pager

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "如果问题仍然存在，请运行诊断脚本:"
echo "  ./诊断profile500错误.sh"
echo ""
echo "或查看实时日志:"
echo "  sudo journalctl -u canteen-backend -f"
echo ""

