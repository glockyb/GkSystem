#!/bin/bash

# 初始化管理员账户

set -e

echo "=========================================="
echo "🔧 初始化管理员账户"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 检查 MySQL 是否运行
if ! systemctl is-active --quiet mysql; then
    echo "⚠️ MySQL 服务未运行，尝试启动..."
    sudo systemctl start mysql
    sleep 2
fi

# 执行 SQL 脚本
echo ""
echo "ℹ️ 执行数据库更新脚本..."
# 先尝试简化版（如果列已存在会报错，但可以继续）
mysql -u root -ppassword canteen_recommendation < backend/database/add_admin_support_simple.sql 2>/dev/null || true

# 如果简化版失败，尝试完整版
if ! mysql -u root -ppassword canteen_recommendation -e "SELECT role FROM users LIMIT 1" 2>/dev/null; then
    echo "使用完整版 SQL 脚本..."
    mysql -u root -ppassword canteen_recommendation < backend/database/add_admin_support.sql 2>/dev/null || true
fi

# 验证列是否存在
if mysql -u root -ppassword canteen_recommendation -e "SELECT role, is_admin FROM users LIMIT 1" 2>/dev/null; then
    echo "✅ 数据库更新成功"
else
    echo "⚠️ 数据库更新可能失败，尝试手动添加列..."
    # 手动添加列（忽略错误）
    mysql -u root -ppassword canteen_recommendation << 'SQL'
ALTER TABLE users ADD COLUMN role VARCHAR(20) DEFAULT 'user' AFTER email;
ALTER TABLE users ADD COLUMN is_admin BOOLEAN DEFAULT FALSE AFTER role;
CREATE INDEX idx_role ON users(role);
CREATE INDEX idx_is_admin ON users(is_admin);
SQL
    echo "✅ 数据库列已添加"
fi

# 创建管理员账户（如果不存在）
echo ""
echo "ℹ️ 检查管理员账户..."
ADMIN_EXISTS=$(mysql -u root -ppassword canteen_recommendation -sN -e "SELECT COUNT(*) FROM users WHERE username = 'admin'")

if [ "$ADMIN_EXISTS" = "0" ]; then
    echo "创建管理员账户..."
    # 使用 Python 生成 bcrypt 哈希
    python3 << 'PYTHON_SCRIPT'
import bcrypt
import pymysql

# 默认管理员密码: admin123
password = "admin123"
password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

try:
    connection = pymysql.connect(
        host='localhost',
        user='root',
        password='password',
        database='canteen_recommendation',
        charset='utf8mb4'
    )
    
    cursor = connection.cursor()
    cursor.execute("""
        INSERT INTO users (username, password_hash, email, role, is_admin)
        VALUES (%s, %s, %s, %s, %s)
    """, ('admin', password_hash, 'admin@example.com', 'admin', True))
    
    connection.commit()
    print("✅ 管理员账户创建成功")
    print("   用户名: admin")
    print("   密码: admin123")
    
    cursor.close()
    connection.close()
except Exception as e:
    print(f"❌ 创建管理员账户失败: {e}")
    exit(1)
PYTHON_SCRIPT
else
    echo "✅ 管理员账户已存在"
    echo "   用户名: admin"
    echo "   密码: admin123 (如果未修改)"
fi

echo ""
echo "=========================================="
echo "✅ 初始化完成"
echo "=========================================="
echo ""
echo "管理员账户信息:"
echo "  用户名: admin"
echo "  密码: admin123"
echo ""
echo "请使用此账户登录后台管理系统:"
echo "  http://your-server-ip/admin"
echo ""

