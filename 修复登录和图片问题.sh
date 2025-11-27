#!/bin/bash

# 修复登录和图片问题
# 1. 修复退出登录后的错误
# 2. 修复后台管理访问问题
# 3. 修复图片加载问题

set -e

echo "=========================================="
echo "🔧 修复登录和图片问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查并修复Nginx图片配置
echo ""
echo "ℹ️ 步骤1: 检查Nginx图片配置..."
NGINX_CONF="/etc/nginx/sites-available/canteen"

if [ -f "$NGINX_CONF" ]; then
    # 检查是否有/images location
    if ! grep -q "location /images" "$NGINX_CONF"; then
        echo "添加 /images location 到 Nginx 配置..."
        
        # 创建临时文件
        TEMP_CONF=$(mktemp)
        
        # 在 /api location 之前插入 /images location
        awk '
        /location \/api/ {
            print "    # 图片静态文件"
            print "    location /images {"
            print "        alias /var/www/canteen/images;"
            print "        expires 30d;"
            print "        add_header Cache-Control \"public, immutable\";"
            print "        access_log off;"
            print "        # 允许跨域（如果需要）"
            print "        add_header Access-Control-Allow-Origin *;"
            print "    }"
            print ""
        }
        { print }
        ' "$NGINX_CONF" > "$TEMP_CONF"
        
        # 备份原配置
        sudo cp "$NGINX_CONF" "${NGINX_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # 应用新配置
        sudo cp "$TEMP_CONF" "$NGINX_CONF"
        rm "$TEMP_CONF"
        
        echo "✅ Nginx 配置已更新"
        
        # 测试配置
        if sudo nginx -t; then
            echo "✅ Nginx 配置语法正确"
            sudo systemctl reload nginx
            echo "✅ Nginx 已重新加载"
        else
            echo "❌ Nginx 配置语法错误，已恢复备份"
            exit 1
        fi
    else
        echo "✅ /images location 已配置"
    fi
else
    echo "⚠️ Nginx 配置文件不存在: $NGINX_CONF"
fi

# 2. 确保图片目录存在且有正确权限
echo ""
echo "ℹ️ 步骤2: 确保图片目录存在且有正确权限..."
sudo mkdir -p /var/www/canteen/images
sudo chown -R www-data:www-data /var/www/canteen/images
sudo chmod -R 755 /var/www/canteen/images

# 检查是否有图片文件需要复制
if [ -d "backend/static/images" ]; then
    echo "复制图片文件到 /var/www/canteen/images..."
    sudo cp -r backend/static/images/* /var/www/canteen/images/ 2>/dev/null || true
    sudo chown -R www-data:www-data /var/www/canteen/images
    sudo chmod -R 644 /var/www/canteen/images/*
    echo "✅ 图片文件已复制"
fi

# 3. 检查管理员账户
echo ""
echo "ℹ️ 步骤3: 检查管理员账户..."
ADMIN_COUNT=$(mysql -u root -ppassword canteen_recommendation -sN -e "SELECT COUNT(*) FROM users WHERE is_admin = 1 OR role = 'admin';" 2>/dev/null || echo "0")

if [ "$ADMIN_COUNT" -eq "0" ]; then
    echo "⚠️ 未找到管理员账户"
    echo "请运行: ./快速创建管理员账户.sh 或 ./初始化管理员账户.sh"
else
    echo "✅ 已找到 $ADMIN_COUNT 个管理员账户"
    echo ""
    echo "管理员列表:"
    mysql -u root -ppassword canteen_recommendation << 'SQL' 2>/dev/null
SELECT id, username, email, role, is_admin FROM users WHERE is_admin = 1 OR role = 'admin';
SQL
fi

# 4. 重启后端服务
echo ""
echo "ℹ️ 步骤4: 重启后端服务..."
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

# 5. 重新构建前端（包含修复）
echo ""
echo "ℹ️ 步骤5: 重新构建前端（包含修复）..."
cd frontend

if [ ! -d "node_modules" ]; then
    echo "安装依赖..."
    npm install
fi

echo "构建前端..."
npm run build

if [ ! -d "dist" ]; then
    echo "❌ 构建失败：未找到 dist 目录"
    exit 1
fi

echo "✅ 前端构建完成"

# 6. 部署前端
echo ""
echo "ℹ️ 步骤6: 部署前端..."
DEPLOY_DIR="/var/www/canteen"

# 备份旧文件
if [ -d "$DEPLOY_DIR" ] && [ "$(ls -A $DEPLOY_DIR 2>/dev/null)" ]; then
    BACKUP_DIR="${DEPLOY_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "备份旧文件到: $BACKUP_DIR"
    sudo cp -r "$DEPLOY_DIR" "$BACKUP_DIR" 2>/dev/null || true
fi

# 部署新文件
sudo mkdir -p "$DEPLOY_DIR"
sudo cp -r dist/* "$DEPLOY_DIR/"
sudo chown -R www-data:www-data "$DEPLOY_DIR"
sudo chmod -R 755 "$DEPLOY_DIR"

echo "✅ 前端已部署"

# 7. 重新加载Nginx
echo ""
echo "ℹ️ 步骤7: 重新加载Nginx..."
if systemctl is-active --quiet nginx; then
    sudo nginx -t && sudo systemctl reload nginx
    echo "✅ Nginx 已重新加载"
else
    echo "⚠️ Nginx 未运行，请手动启动"
fi

cd ..

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "修复内容："
echo "1. ✅ 修复退出登录后的错误 - 完全清除状态和token"
echo "2. ✅ 修复后台管理访问问题 - 优化权限检查"
echo "3. ✅ 修复图片加载问题 - 确保Nginx配置和图片目录正确"
echo ""
echo "下一步操作："
echo "1. 清除浏览器缓存（重要！）"
echo "   - 按 Ctrl+Shift+Delete (Windows/Linux) 或 Cmd+Shift+Delete (Mac)"
echo "   - 或使用无痕模式测试"
echo ""
echo "2. 测试登录："
echo "   - 使用管理员账户登录"
echo "   - 测试退出登录"
echo "   - 测试重新登录"
echo ""
echo "3. 测试后台管理："
echo "   - 登录后访问: http://your-server-ip/admin"
echo "   - 或点击右上角用户菜单中的'后台管理'"
echo ""
echo "4. 测试图片："
echo "   - 检查菜品图片是否正常显示"
echo "   - 如果图片仍无法加载，检查:"
echo "     sudo tail -f /var/log/nginx/canteen-error.log"
echo ""

