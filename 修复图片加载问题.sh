#!/bin/bash

# 修复图片加载问题（独立脚本）

set -e

echo "=========================================="
echo "🔧 修复图片加载问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

BACKEND_IMAGES_DIR="backend/static/images"
NGINX_IMAGES_DIR="/var/www/canteen/images"

# 1. 创建图片目录
echo ""
echo "ℹ️ 步骤1: 创建图片目录..."
mkdir -p "$BACKEND_IMAGES_DIR"
sudo mkdir -p "$NGINX_IMAGES_DIR"

# 2. 从数据库获取所有图片URL并创建占位图片
echo ""
echo "ℹ️ 步骤2: 从数据库获取图片URL并创建占位图片..."
python3 << 'PYTHON_SCRIPT'
import pymysql
import os
import sys

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
            
            # 确保文件名有扩展名
            if '.' not in filename:
                filename = filename + '.jpg'
            
            filepath = os.path.join(images_dir, filename)
            if not os.path.exists(filepath):
                with open(filepath, 'w') as f:
                    f.write(placeholder_svg)
                created += 1
                print(f"创建占位图片: {filename}")
    
    print(f"✅ 共创建了 {created} 个占位图片")
    print(f"✅ 图片目录: {images_dir}")
    
    cursor.close()
    connection.close()
except Exception as e:
    print(f"❌ 创建占位图片失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON_SCRIPT

# 3. 设置权限
echo ""
echo "ℹ️ 步骤3: 设置文件权限..."
chmod -R 755 "$BACKEND_IMAGES_DIR"
find "$BACKEND_IMAGES_DIR" -type f -exec chmod 644 {} \;

# 4. 复制图片到 Nginx 目录
echo ""
echo "ℹ️ 步骤4: 复制图片到 Nginx 目录..."
sudo rm -rf "$NGINX_IMAGES_DIR"/*
if [ -d "$BACKEND_IMAGES_DIR" ] && [ "$(ls -A $BACKEND_IMAGES_DIR)" ]; then
    sudo cp -r "$BACKEND_IMAGES_DIR"/* "$NGINX_IMAGES_DIR/" 2>/dev/null || true
    file_count=$(find "$NGINX_IMAGES_DIR" -type f 2>/dev/null | wc -l)
    echo "✅ 已复制 $file_count 个图片文件到 Nginx 目录"
else
    echo "⚠️ 后端图片目录为空，跳过复制"
fi

# 设置 Nginx 目录权限
sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
sudo find "$NGINX_IMAGES_DIR" -type d -exec chmod 755 {} \;
sudo find "$NGINX_IMAGES_DIR" -type f -exec chmod 644 {} \;

# 5. 检查并修复 Nginx 配置
echo ""
echo "ℹ️ 步骤5: 检查并修复 Nginx 配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

if ! sudo grep -q "location /images" "$NGINX_CONFIG"; then
    echo "添加 Nginx /images 配置..."
    # 在 location /api 之后添加
    sudo awk '/location \/api \{/,/\}/ {print; if (/^\s*\}/) {print "\n    location /images {\n        alias /var/www/canteen/images;\n        expires 30d;\n        add_header Cache-Control \"public, immutable\";\n        access_log off;\n    }"; next}} 1' "$NGINX_CONFIG" | sudo tee "$NGINX_CONFIG.tmp" > /dev/null
    sudo mv "$NGINX_CONFIG.tmp" "$NGINX_CONFIG"
    
    # 验证配置
    if sudo nginx -t 2>&1 | grep -q "successful"; then
        echo "✅ Nginx 配置正确"
        sudo systemctl reload nginx
    else
        echo "❌ Nginx 配置有错误"
        sudo nginx -t
        exit 1
    fi
else
    echo "✅ Nginx /images 配置已存在"
    # 验证配置
    if sudo nginx -t 2>&1 | grep -q "successful"; then
        sudo systemctl reload nginx
    fi
fi

# 6. 测试图片访问
echo ""
echo "ℹ️ 步骤6: 测试图片访问..."
TEST_IMAGE="yuxiangrousi.jpg"
if [ -f "$NGINX_IMAGES_DIR/$TEST_IMAGE" ]; then
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/images/$TEST_IMAGE" 2>&1 || echo "000")
    if [ "$http_code" = "200" ]; then
        echo "✅ 图片访问测试成功 (HTTP $http_code)"
    else
        echo "⚠️ 图片访问测试失败 (HTTP $http_code)"
    fi
else
    echo "⚠️ 测试图片不存在: $TEST_IMAGE"
fi

# 7. 显示统计信息
echo ""
echo "=========================================="
echo "📋 修复结果"
echo "=========================================="
echo ""
echo "后端图片目录: $BACKEND_IMAGES_DIR"
echo "  文件数: $(find "$BACKEND_IMAGES_DIR" -type f 2>/dev/null | wc -l)"
echo ""
echo "Nginx 图片目录: $NGINX_IMAGES_DIR"
echo "  文件数: $(find "$NGINX_IMAGES_DIR" -type f 2>/dev/null | wc -l)"
echo ""
echo "Nginx 配置:"
sudo grep -A 5 "location /images" "$NGINX_CONFIG" | head -6
echo ""
echo "💡 如果图片仍不显示，请："
echo "  1. 清除浏览器缓存 (Ctrl+Shift+R)"
echo "  2. 检查浏览器控制台 (F12 → Console → Network)"
echo "  3. 查看图片请求的完整 URL 和响应"
echo "  4. 检查 Nginx 日志: sudo tail -f /var/log/nginx/error.log"
echo ""
