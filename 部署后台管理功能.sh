#!/bin/bash

# 部署后台管理功能

set -e

echo "=========================================="
echo "🚀 部署后台管理功能"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 更新数据库
echo ""
echo "ℹ️ 步骤1: 更新数据库结构..."
if [ -f "backend/database/add_admin_support.sql" ]; then
    mysql -u root -ppassword canteen_recommendation < backend/database/add_admin_support.sql
    echo "✅ 数据库更新完成"
else
    echo "⚠️ SQL 文件不存在，跳过数据库更新"
fi

# 2. 初始化管理员账户
echo ""
echo "ℹ️ 步骤2: 初始化管理员账户..."
if [ -f "初始化管理员账户.sh" ]; then
    chmod +x 初始化管理员账户.sh
    ./初始化管理员账户.sh
else
    echo "⚠️ 初始化脚本不存在，手动创建管理员账户..."
    python3 << 'PYTHON_SCRIPT'
import bcrypt
import pymysql

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
    
    # 检查是否存在
    cursor.execute("SELECT COUNT(*) FROM users WHERE username = 'admin'")
    exists = cursor.fetchone()[0]
    
    if exists == 0:
        cursor.execute("""
            INSERT INTO users (username, password_hash, email, role, is_admin)
            VALUES (%s, %s, %s, %s, %s)
        """, ('admin', password_hash, 'admin@example.com', 'admin', True))
        connection.commit()
        print("✅ 管理员账户创建成功")
    else:
        # 更新现有账户为管理员
        cursor.execute("""
            UPDATE users SET role = 'admin', is_admin = TRUE WHERE username = 'admin'
        """)
        connection.commit()
        print("✅ 管理员账户已更新")
    
    cursor.close()
    connection.close()
except Exception as e:
    print(f"❌ 创建管理员账户失败: {e}")
    exit(1)
PYTHON_SCRIPT
fi

# 3. 重启后端服务
echo ""
echo "ℹ️ 步骤3: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 3

if systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行正常"
else
    echo "❌ 后端服务启动失败，查看日志:"
    sudo journalctl -u canteen-backend -n 20 --no-pager
    exit 1
fi

# 4. 重新构建和部署前端
echo ""
echo "ℹ️ 步骤4: 重新构建和部署前端..."
cd frontend

# 清理旧的构建
if [ -d "dist" ]; then
    rm -rf dist
fi

# 确保没有设置 VITE_API_URL
unset VITE_API_URL
export VITE_API_URL=""

# 安装依赖（如果需要）
if [ ! -d "node_modules" ]; then
    echo "安装前端依赖..."
    npm install
fi

# 构建
echo "构建前端..."
npm run build

if [ ! -d "dist" ] || [ ! -f "dist/index.html" ]; then
    echo "❌ 前端构建失败"
    exit 1
fi

echo "✅ 前端构建成功"

# 部署到 Nginx
echo ""
echo "ℹ️ 步骤5: 部署前端到 Nginx..."
sudo rm -rf /var/www/canteen/*
sudo cp -r dist/* /var/www/canteen/
sudo chown -R www-data:www-data /var/www/canteen
sudo chmod -R 755 /var/www/canteen

echo "✅ 前端已部署"

# 重载 Nginx
sudo systemctl reload nginx

cd ..

# 6. 验证
echo ""
echo "=========================================="
echo "📋 部署完成"
echo "=========================================="
echo ""
echo "✅ 后台管理功能已部署"
echo ""
echo "管理员账户信息:"
echo "  用户名: admin"
echo "  密码: admin123"
echo ""
echo "访问地址:"
echo "  前端: http://your-server-ip/"
echo "  管理后台: http://your-server-ip/admin"
echo ""
echo "功能说明:"
echo "  - 数据统计: 查看系统整体数据"
echo "  - 菜品管理: 添加、编辑、删除菜品"
echo "  - 用户管理: 查看、编辑、删除用户"
echo "  - 评分管理: 查看、删除用户评分"
echo ""

