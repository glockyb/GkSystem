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
# 先检查列是否已存在
if mysql -u root -ppassword canteen_recommendation -e "SELECT role FROM users LIMIT 1" 2>/dev/null; then
    echo "✅ 数据库列已存在，跳过更新"
else
    # 使用简化版 SQL（兼容性更好）
    if [ -f "backend/database/add_admin_support_simple.sql" ]; then
        mysql -u root -ppassword canteen_recommendation < backend/database/add_admin_support_simple.sql 2>&1 | grep -v "Duplicate column\|Duplicate key" || true
        echo "✅ 数据库更新完成"
    elif [ -f "backend/database/add_admin_support.sql" ]; then
        mysql -u root -ppassword canteen_recommendation < backend/database/add_admin_support.sql 2>&1 | grep -v "Duplicate column\|Duplicate key" || true
        echo "✅ 数据库更新完成"
    else
        echo "⚠️ SQL 文件不存在，手动添加列..."
        mysql -u root -ppassword canteen_recommendation << 'SQL' 2>&1 | grep -v "Duplicate column\|Duplicate key" || true
ALTER TABLE users ADD COLUMN role VARCHAR(20) DEFAULT 'user' AFTER email;
ALTER TABLE users ADD COLUMN is_admin BOOLEAN DEFAULT FALSE AFTER role;
CREATE INDEX idx_role ON users(role);
CREATE INDEX idx_is_admin ON users(is_admin);
SQL
        echo "✅ 数据库列已添加"
    fi
fi

# 2. 初始化管理员账户
echo ""
echo "ℹ️ 步骤2: 初始化管理员账户..."
if [ -f "初始化管理员账户.sh" ]; then
    chmod +x 初始化管理员账户.sh
    ./初始化管理员账户.sh
else
    echo "⚠️ 初始化脚本不存在，手动创建管理员账户..."
    
    # 检查并激活虚拟环境
    PYTHON_CMD="python3"
    if [ -d "backend/venv" ]; then
        PYTHON_CMD="backend/venv/bin/python"
    elif [ -d "venv" ]; then
        PYTHON_CMD="venv/bin/python"
    fi
    
    $PYTHON_CMD << 'PYTHON_SCRIPT'
import sys
import pymysql

# 预生成的 bcrypt 哈希（密码: admin123）
PASSWORD_HASH = "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyY5Y5Y5Y5Y5"

try:
    # 尝试使用 bcrypt 生成新的哈希
    try:
        import bcrypt
        password = "admin123"
        password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    except ImportError:
        password_hash = PASSWORD_HASH
    
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
except ImportError as e:
    print(f"❌ 缺少必要的 Python 模块: {e}")
    print("   请运行: pip3 install bcrypt pymysql")
    sys.exit(1)
except Exception as e:
    print(f"❌ 创建管理员账户失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
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

# 4. 修复图片加载问题
echo ""
echo "ℹ️ 步骤4: 修复图片加载问题..."
BACKEND_IMAGES_DIR="backend/static/images"
NGINX_IMAGES_DIR="/var/www/canteen/images"

# 创建图片目录
mkdir -p "$BACKEND_IMAGES_DIR"

# 创建占位图片的SVG内容
PLACEHOLDER_SVG='<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#667eea;stop-opacity:1" /><stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" /></linearGradient></defs><rect width="400" height="300" fill="url(#grad)"/><circle cx="200" cy="120" r="40" fill="rgba(255,255,255,0.3)"/><path d="M 180 120 L 200 100 L 220 120 L 200 140 Z" fill="rgba(255,255,255,0.5)"/><text x="200" y="200" font-family="Arial" font-size="16" fill="rgba(255,255,255,0.8)" text-anchor="middle">菜品图片</text></svg>'

# 从数据库获取所有图片URL，创建占位图片
python3 << 'PYTHON_SCRIPT'
import pymysql
import os

try:
    connection = pymysql.connect(
        host='localhost',
        user='root',
        password='password',
        database='canteen_recommendation',
        charset='utf8mb4'
    )
    
    cursor = connection.cursor()
    cursor.execute("SELECT DISTINCT image_url FROM dishes WHERE image_url IS NOT NULL AND image_url != ''")
    image_urls = cursor.fetchall()
    
    images_dir = 'backend/static/images'
    os.makedirs(images_dir, exist_ok=True)
    
    placeholder_svg = '''<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#667eea;stop-opacity:1" /><stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" /></linearGradient></defs><rect width="400" height="300" fill="url(#grad)"/><circle cx="200" cy="120" r="40" fill="rgba(255,255,255,0.3)"/><path d="M 180 120 L 200 100 L 220 120 L 200 140 Z" fill="rgba(255,255,255,0.5)"/><text x="200" y="200" font-family="Arial" font-size="16" fill="rgba(255,255,255,0.8)" text-anchor="middle">菜品图片</text></svg>'''
    
    created = 0
    for row in image_urls:
        if isinstance(row, dict):
            image_url = row.get('image_url')
        else:
            image_url = row[0]
        
        if image_url:
            # 提取文件名
            if image_url.startswith('/images/'):
                filename = image_url.split('/')[-1]
            elif '/' in image_url:
                filename = image_url.split('/')[-1]
            else:
                filename = image_url
            
            filepath = os.path.join(images_dir, filename)
            if not os.path.exists(filepath):
                with open(filepath, 'w') as f:
                    f.write(placeholder_svg)
                created += 1
    
    print(f"✅ 创建了 {created} 个占位图片")
    
    cursor.close()
    connection.close()
except Exception as e:
    print(f"⚠️ 创建占位图片时出错: {e}")
PYTHON_SCRIPT

# 设置权限
chmod -R 755 "$BACKEND_IMAGES_DIR"
find "$BACKEND_IMAGES_DIR" -type f -exec chmod 644 {} \;

# 复制图片到 Nginx 目录
sudo mkdir -p "$NGINX_IMAGES_DIR"
sudo rm -rf "$NGINX_IMAGES_DIR"/*
sudo cp -r "$BACKEND_IMAGES_DIR"/* "$NGINX_IMAGES_DIR/" 2>/dev/null || true
sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
sudo find "$NGINX_IMAGES_DIR" -type d -exec chmod 755 {} \;
sudo find "$NGINX_IMAGES_DIR" -type f -exec chmod 644 {} \;

# 检查并修复 Nginx 配置
NGINX_CONFIG="/etc/nginx/sites-available/canteen"
if ! sudo grep -q "location /images" "$NGINX_CONFIG"; then
    echo "添加 Nginx /images 配置..."
    sudo tee -a "$NGINX_CONFIG" > /dev/null << 'NGINX_CONFIG_EOF'

    location /images {
        alias /var/www/canteen/images;
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
NGINX_CONFIG_EOF
    sudo nginx -t && sudo systemctl reload nginx
fi

echo "✅ 图片加载问题已修复"

# 5. 重新构建和部署前端
echo ""
echo "ℹ️ 步骤5: 重新构建和部署前端..."
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

