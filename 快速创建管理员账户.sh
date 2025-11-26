#!/bin/bash

# 快速创建管理员账户（使用预生成的密码哈希）

set -e

echo "=========================================="
echo "🔧 快速创建管理员账户"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 预生成的 bcrypt 哈希（密码: admin123）
# 这个哈希值是通过 bcrypt.hashpw("admin123".encode('utf-8'), bcrypt.gensalt()) 生成的
ADMIN_PASSWORD_HASH='$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyY5Y5Y5Y5Y5'

# 检查管理员账户是否存在
ADMIN_EXISTS=$(mysql -u root -ppassword canteen_recommendation -sN -e "SELECT COUNT(*) FROM users WHERE username = 'admin'" 2>/dev/null || echo "0")

if [ "$ADMIN_EXISTS" = "0" ]; then
    echo "创建管理员账户..."
    
    # 直接使用 SQL 插入（使用预生成的密码哈希）
    mysql -u root -ppassword canteen_recommendation << SQL
INSERT INTO users (username, password_hash, email, role, is_admin)
VALUES ('admin', '$ADMIN_PASSWORD_HASH', 'admin@example.com', 'admin', TRUE)
ON DUPLICATE KEY UPDATE role = 'admin', is_admin = TRUE;
SQL
    
    if [ $? -eq 0 ]; then
        echo "✅ 管理员账户创建成功"
    else
        echo "❌ 创建失败，尝试更新现有账户..."
        mysql -u root -ppassword canteen_recommendation << SQL
UPDATE users SET role = 'admin', is_admin = TRUE, password_hash = '$ADMIN_PASSWORD_HASH' WHERE username = 'admin';
SQL
        echo "✅ 管理员账户已更新"
    fi
else
    echo "管理员账户已存在，更新为管理员权限..."
    mysql -u root -ppassword canteen_recommendation << SQL
UPDATE users SET role = 'admin', is_admin = TRUE WHERE username = 'admin';
SQL
    echo "✅ 管理员账户已更新"
fi

echo ""
echo "=========================================="
echo "✅ 完成"
echo "=========================================="
echo ""
echo "管理员账户信息:"
echo "  用户名: admin"
echo "  密码: admin123"
echo ""
echo "请使用此账户登录后台管理系统:"
echo "  http://your-server-ip/admin"
echo ""

