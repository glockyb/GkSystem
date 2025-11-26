#!/bin/bash

# 全面修复：图片加载、后台管理、favicon

set -e

echo "=========================================="
echo "🔧 全面修复：图片、后台管理、favicon"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 修复 Nginx 配置 - 添加 /images location
echo ""
echo "ℹ️ 步骤1: 修复 Nginx 配置（添加 /images location）..."

# 检查当前 Nginx 配置
NGINX_CONF="/etc/nginx/sites-available/canteen"
if [ ! -f "$NGINX_CONF" ]; then
    echo "⚠️ Nginx 配置文件不存在: $NGINX_CONF"
    echo "请先配置 Nginx，或手动添加 /images location"
else
    # 检查是否已有 /images location
    if grep -q "location /images" "$NGINX_CONF"; then
        echo "✅ /images location 已存在"
    else
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
            sudo cp "${NGINX_CONF}.backup.$(date +%Y%m%d_%H%M%S)" "$NGINX_CONF"
            exit 1
        fi
    fi
fi

# 2. 确保图片目录存在且有正确权限
echo ""
echo "ℹ️ 步骤2: 确保图片目录存在且有正确权限..."
sudo mkdir -p /var/www/canteen/images
sudo chown -R www-data:www-data /var/www/canteen/images
sudo chmod -R 755 /var/www/canteen/images

# 检查是否有图片文件
if [ -d "backend/static/images" ]; then
    echo "复制图片文件到 /var/www/canteen/images..."
    sudo cp -r backend/static/images/* /var/www/canteen/images/ 2>/dev/null || true
    sudo chown -R www-data:www-data /var/www/canteen/images
    sudo chmod -R 644 /var/www/canteen/images/*
    echo "✅ 图片文件已复制"
fi

# 3. 添加 favicon.ico
echo ""
echo "ℹ️ 步骤3: 添加 favicon.ico..."
if [ ! -f "frontend/public/favicon.ico" ]; then
    # 创建一个简单的 favicon（使用 ImageMagick 或直接复制）
    if command -v convert >/dev/null 2>&1; then
        echo "使用 ImageMagick 创建 favicon..."
        convert -size 32x32 xc:blue -pointsize 20 -fill white -gravity center -annotate +0+0 "G" frontend/public/favicon.ico 2>/dev/null || true
    else
        echo "⚠️ ImageMagick 未安装，跳过 favicon 创建"
        echo "您可以手动添加 favicon.ico 到 frontend/public/"
    fi
else
    echo "✅ favicon.ico 已存在"
fi

# 4. 检查并修复后台管理 API
echo ""
echo "ℹ️ 步骤4: 检查后台管理 API..."
# 重启后端服务以确保 admin 模块已加载
sudo systemctl restart canteen-backend
sleep 3

if systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行正常"
else
    echo "❌ 后端服务启动失败"
    echo "查看日志:"
    sudo journalctl -u canteen-backend -n 20 --no-pager | tail -10
fi

# 5. 重新构建前端（包含 favicon）
echo ""
echo "ℹ️ 步骤5: 重新构建前端..."
cd frontend
if [ -d "node_modules" ]; then
    npm run build
    echo "✅ 前端构建完成"
    
    # 部署到 Nginx
    if [ -d "dist" ]; then
        echo "部署前端文件..."
        sudo cp -r dist/* /var/www/canteen/ 2>/dev/null || true
        sudo chown -R www-data:www-data /var/www/canteen/
        echo "✅ 前端文件已部署"
    fi
else
    echo "⚠️ node_modules 不存在，跳过构建"
fi
cd ..

# 6. 测试
echo ""
echo "ℹ️ 步骤6: 测试..."
echo "测试图片访问:"
if curl -s -o /dev/null -w "%{http_code}" http://localhost/images/hongshaorou.jpg | grep -q "200\|404"; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/images/hongshaorou.jpg)
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ 图片访问正常 (HTTP $HTTP_CODE)"
    else
        echo "⚠️ 图片访问返回 HTTP $HTTP_CODE（可能文件不存在）"
    fi
else
    echo "⚠️ 无法测试图片访问"
fi

echo ""
echo "测试 API:"
if curl -s http://localhost:5000/health | grep -q "healthy"; then
    echo "✅ API 健康检查通过"
else
    echo "⚠️ API 健康检查失败"
fi

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "请检查："
echo "1. 访问 http://your-server/images/hongshaorou.jpg 查看图片"
echo "2. 访问后台管理页面，查看控制台是否有错误"
echo "3. 检查 favicon.ico 是否显示"
echo ""
echo "如果问题仍然存在，请查看："
echo "  - Nginx 错误日志: sudo tail -f /var/log/nginx/canteen-error.log"
echo "  - 后端日志: sudo journalctl -u canteen-backend -f"
echo ""

