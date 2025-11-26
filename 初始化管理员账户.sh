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
mysql -u root -ppassword canteen_recommendation < backend/database/add_admin_support.sql

if [ $? -eq 0 ]; then
    echo "✅ 数据库更新成功"
else
    echo "❌ 数据库更新失败"
    exit 1
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

