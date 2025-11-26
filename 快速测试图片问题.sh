#!/bin/bash

# 快速测试图片问题

set -e

echo "=========================================="
echo "🔍 快速测试图片问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

TEST_IMAGE="yuxiangrousi.jpg"
BACKEND_IMAGES_DIR="backend/static/images"
NGINX_IMAGES_DIR="/var/www/canteen/images"

# 1. 检查文件是否存在
echo ""
echo "ℹ️ 步骤1: 检查文件..."
echo "后端文件: $BACKEND_IMAGES_DIR/$TEST_IMAGE"
if [ -f "$BACKEND_IMAGES_DIR/$TEST_IMAGE" ]; then
    echo "✅ 存在"
    ls -lh "$BACKEND_IMAGES_DIR/$TEST_IMAGE"
else
    echo "❌ 不存在"
    echo "创建文件..."
    mkdir -p "$BACKEND_IMAGES_DIR"
    cat > "$BACKEND_IMAGES_DIR/$TEST_IMAGE" << 'EOF'
<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="400" height="300" fill="url(#grad)"/>
  <circle cx="200" cy="120" r="40" fill="rgba(255,255,255,0.3)"/>
  <path d="M 180 120 L 200 100 L 220 120 L 200 140 Z" fill="rgba(255,255,255,0.5)"/>
  <text x="200" y="200" font-family="Arial" font-size="16" fill="rgba(255,255,255,0.8)" text-anchor="middle">菜品图片</text>
</svg>
EOF
    chmod 644 "$BACKEND_IMAGES_DIR/$TEST_IMAGE"
fi

echo ""
echo "Nginx 文件: $NGINX_IMAGES_DIR/$TEST_IMAGE"
if [ -f "$NGINX_IMAGES_DIR/$TEST_IMAGE" ]; then
    echo "✅ 存在"
    ls -lh "$NGINX_IMAGES_DIR/$TEST_IMAGE"
else
    echo "❌ 不存在"
    echo "创建目录并复制文件..."
    sudo mkdir -p "$NGINX_IMAGES_DIR"
    sudo cp "$BACKEND_IMAGES_DIR/$TEST_IMAGE" "$NGINX_IMAGES_DIR/"
    sudo chown www-data:www-data "$NGINX_IMAGES_DIR/$TEST_IMAGE"
    sudo chmod 644 "$NGINX_IMAGES_DIR/$TEST_IMAGE"
    sudo chmod 755 "$NGINX_IMAGES_DIR"
fi

# 2. 检查权限
echo ""
echo "ℹ️ 步骤2: 检查权限..."
echo "文件权限:"
ls -lh "$NGINX_IMAGES_DIR/$TEST_IMAGE" 2>/dev/null || echo "文件不存在"
echo ""
echo "目录权限:"
ls -ld "$NGINX_IMAGES_DIR" 2>/dev/null || echo "目录不存在"
echo ""
echo "www-data 用户测试:"
sudo -u www-data test -r "$NGINX_IMAGES_DIR/$TEST_IMAGE" && echo "✅ 可读" || echo "❌ 不可读"

# 3. 检查 Nginx 配置
echo ""
echo "ℹ️ 步骤3: 检查 Nginx 配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

if sudo grep -q "location /images" "$NGINX_CONFIG"; then
    echo "✅ 配置存在"
    echo "配置内容:"
    sudo grep -A 6 "location /images" "$NGINX_CONFIG"
    
    # 检查 alias 路径
    alias_path=$(sudo grep -A 5 "location /images" "$NGINX_CONFIG" | grep "alias" | sed 's/.*alias[[:space:]]*\([^;]*\).*/\1/' | tr -d ' ')
    echo ""
    echo "配置的 alias 路径: '$alias_path'"
    echo "期望的路径: '/var/www/canteen/images'"
    
    if [ "$alias_path" != "/var/www/canteen/images" ]; then
        echo "⚠️ 路径不匹配，修复..."
        sudo sed -i "s|alias[[:space:]]*[^;]*;|alias /var/www/canteen/images;|g" "$NGINX_CONFIG"
        echo "✅ 已修复"
    fi
else
    echo "❌ 配置不存在，添加..."
    # 简单添加配置
    sudo tee -a "$NGINX_CONFIG" > /dev/null << 'EOF'

    location /images {
        alias /var/www/canteen/images;
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
EOF
    echo "✅ 已添加配置"
fi

# 验证配置
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "✅ Nginx 配置正确"
    sudo systemctl reload nginx
    sleep 1
else
    echo "❌ Nginx 配置有错误"
    sudo nginx -t
fi

# 4. 测试访问
echo ""
echo "ℹ️ 步骤4: 测试访问..."
echo "测试: http://localhost/images/$TEST_IMAGE"
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost/images/$TEST_IMAGE" 2>&1)
http_code=$(echo "$response" | grep "HTTP_CODE" | cut -d: -f2)
body=$(echo "$response" | grep -v "HTTP_CODE")

echo "HTTP 状态码: $http_code"
if [ "$http_code" = "200" ]; then
    echo "✅ 访问成功"
    echo "响应大小: $(echo "$body" | wc -c) 字节"
    echo "Content-Type 检查:"
    curl -s -I "http://localhost/images/$TEST_IMAGE" | grep -i "content-type" || echo "未找到 Content-Type"
else
    echo "❌ 访问失败"
    echo "响应内容:"
    echo "$body" | head -5
fi

# 5. 检查 Nginx 日志
echo ""
echo "ℹ️ 步骤5: 检查 Nginx 错误日志..."
sudo tail -5 /var/log/nginx/error.log 2>/dev/null | grep -i "images\|$TEST_IMAGE\|404" || echo "未发现相关错误"

# 6. 总结
echo ""
echo "=========================================="
echo "📋 测试结果"
echo "=========================================="
echo ""
echo "文件状态:"
[ -f "$NGINX_IMAGES_DIR/$TEST_IMAGE" ] && echo "  ✅ 文件存在" || echo "  ❌ 文件不存在"
[ -r "$NGINX_IMAGES_DIR/$TEST_IMAGE" ] && echo "  ✅ 文件可读" || echo "  ❌ 文件不可读"
echo ""
echo "Nginx 配置:"
sudo grep -q "location /images" "$NGINX_CONFIG" && echo "  ✅ 配置存在" || echo "  ❌ 配置不存在"
echo ""
echo "访问测试:"
[ "$http_code" = "200" ] && echo "  ✅ HTTP 200" || echo "  ❌ HTTP $http_code"
echo ""
echo "💡 如果仍有问题，请运行:"
echo "  ./全面修复图片显示问题.sh"
echo ""

