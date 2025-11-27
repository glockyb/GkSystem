#!/bin/bash

# 修复后台管理系统
# 1. 确保管理员账户存在
# 2. 检查数据库字段
# 3. 测试后台管理功能

set -e

# 自动检测项目路径
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo "=========================================="
echo "🔧 修复后台管理系统"
echo "=========================================="
echo "项目路径: $SCRIPT_DIR"
echo ""

# 1. 检查数据库字段
echo ""
echo "ℹ️ 步骤1: 检查数据库字段..."
mysql -u root -ppassword canteen_recommendation << 'SQL' 2>/dev/null || true
-- 检查 role 字段
SET @dbname = DATABASE();
SET @tablename = "users";
SET @columnname = "role";
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (table_name = @tablename)
      AND (table_schema = @dbname)
      AND (column_name = @columnname)
  ) > 0,
  "SELECT 'role字段已存在' AS result;",
  "ALTER TABLE users ADD COLUMN role VARCHAR(20) DEFAULT 'user' AFTER email;"
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- 检查 is_admin 字段
SET @columnname = "is_admin";
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (table_name = @tablename)
      AND (table_schema = @dbname)
      AND (column_name = @columnname)
  ) > 0,
  "SELECT 'is_admin字段已存在' AS result;",
  "ALTER TABLE users ADD COLUMN is_admin TINYINT(1) DEFAULT 0 AFTER role;"
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

SELECT '数据库字段检查完成' AS result;
SQL

echo "✅ 数据库字段检查完成"

# 2. 检查是否有管理员账户
echo ""
echo "ℹ️ 步骤2: 检查管理员账户..."
ADMIN_COUNT=$(mysql -u root -ppassword canteen_recommendation -sN -e "SELECT COUNT(*) FROM users WHERE is_admin = 1 OR role = 'admin';" 2>/dev/null || echo "0")

if [ "$ADMIN_COUNT" -eq "0" ]; then
    echo "⚠️ 未找到管理员账户"
    echo ""
    read -p "是否创建管理员账户? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "请输入管理员用户名: " ADMIN_USERNAME
        read -sp "请输入管理员密码: " ADMIN_PASSWORD
        echo
        
        if [ -z "$ADMIN_USERNAME" ] || [ -z "$ADMIN_PASSWORD" ]; then
            echo "❌ 用户名和密码不能为空"
            exit 1
        fi
        
        # 使用 Python 创建管理员（因为需要加密密码）
        cd backend
        if [ -d "venv" ]; then
            source venv/bin/activate
        fi
        
        python3 << PYTHON_SCRIPT
import sys
import bcrypt
import pymysql
from utils.database import db

username = "$ADMIN_USERNAME"
password = "$ADMIN_PASSWORD"

try:
    connection = db.get_connection()
    cursor = connection.cursor()
    
    # 检查用户是否已存在
    cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
    existing_user = cursor.fetchone()
    
    if existing_user:
        # 更新现有用户为管理员
        user_id = existing_user[0] if isinstance(existing_user, (list, tuple)) else existing_user.get('id')
        cursor.execute("UPDATE users SET role = 'admin', is_admin = 1 WHERE id = %s", (user_id,))
        print(f"✅ 用户 {username} 已更新为管理员")
    else:
        # 创建新管理员
        password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        cursor.execute(
            "INSERT INTO users (username, password_hash, role, is_admin) VALUES (%s, %s, 'admin', 1)",
            (username, password_hash)
        )
        print(f"✅ 管理员账户 {username} 创建成功")
    
    connection.commit()
    cursor.close()
except Exception as e:
    print(f"❌ 创建管理员失败: {e}")
    sys.exit(1)
PYTHON_SCRIPT
        
        cd ..
    else
        echo "跳过创建管理员账户"
    fi
else
    echo "✅ 已找到 $ADMIN_COUNT 个管理员账户"
    echo ""
    echo "管理员列表:"
    mysql -u root -ppassword canteen_recommendation << 'SQL' 2>/dev/null
SELECT id, username, email, role, is_admin FROM users WHERE is_admin = 1 OR role = 'admin';
SQL
fi

# 3. 重启后端服务
echo ""
echo "ℹ️ 步骤3: 重启后端服务..."
if systemctl is-active --quiet canteen-backend; then
    sudo systemctl restart canteen-backend
    sleep 3
    if systemctl is-active --quiet canteen-backend; then
        echo "✅ 后端服务已重启"
    else
        echo "❌ 后端服务启动失败"
        echo "查看日志:"
        sudo journalctl -u canteen-backend -n 20 --no-pager | tail -10
    fi
else
    echo "⚠️ 后端服务未运行，请手动启动: sudo systemctl start canteen-backend"
fi

# 4. 测试后台管理 API
echo ""
echo "ℹ️ 步骤4: 测试后台管理 API..."
if curl -s http://localhost:5000/health | grep -q "healthy"; then
    echo "✅ 后端 API 健康检查通过"
    echo ""
    echo "⚠️ 注意：要测试管理员 API，需要："
    echo "1. 使用管理员账户登录"
    echo "2. 获取 JWT token"
    echo "3. 使用 token 访问 /api/v1/admin/stats"
else
    echo "❌ 后端 API 不可访问"
fi

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "下一步操作："
echo "1. 使用管理员账户登录系统"
echo "2. 登录后，点击右上角用户菜单中的'后台管理'"
echo "3. 或直接访问: http://your-server-ip/admin"
echo ""
echo "如果仍然无法访问后台管理："
echo "1. 检查浏览器控制台（F12）是否有错误"
echo "2. 确认用户确实是管理员（is_admin=1 或 role='admin'）"
echo "3. 清除浏览器缓存后重新登录"
echo ""

