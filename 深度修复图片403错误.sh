#!/bin/bash

# 深度修复图片403错误

set -e

echo "=========================================="
echo "🔧 深度修复图片403错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

BACKEND_IMAGES_DIR="backend/static/images"
NGINX_IMAGES_DIR="/var/www/canteen/images"

# 1. 检查当前状态
echo ""
echo "ℹ️ 步骤1: 检查当前状态..."
echo "后端图片目录: $BACKEND_IMAGES_DIR"
if [ -d "$BACKEND_IMAGES_DIR" ]; then
    echo "✅ 目录存在"
    ls -ld "$BACKEND_IMAGES_DIR"
    echo "目录内容:"
    ls -la "$BACKEND_IMAGES_DIR" | head -5
else
    echo "❌ 目录不存在"
    mkdir -p "$BACKEND_IMAGES_DIR"
fi

echo ""
echo "Nginx 图片目录: $NGINX_IMAGES_DIR"
if [ -L "$NGINX_IMAGES_DIR" ]; then
    echo "✅ 是符号链接"
    REAL_PATH=$(readlink -f "$NGINX_IMAGES_DIR")
    echo "   实际路径: $REAL_PATH"
    ls -ld "$NGINX_IMAGES_DIR"
    ls -ld "$REAL_PATH"
elif [ -d "$NGINX_IMAGES_DIR" ]; then
    echo "✅ 是普通目录"
    ls -ld "$NGINX_IMAGES_DIR"
else
    echo "❌ 不存在"
fi

# 2. 检查父目录权限
echo ""
echo "ℹ️ 步骤2: 检查父目录权限..."
PARENT_DIR=$(dirname "$NGINX_IMAGES_DIR")
echo "父目录: $PARENT_DIR"
ls -ld "$PARENT_DIR"

# 检查所有父目录的权限
CURRENT_DIR="$PARENT_DIR"
while [ "$CURRENT_DIR" != "/" ]; do
    if [ -d "$CURRENT_DIR" ]; then
        PERM=$(stat -c "%a" "$CURRENT_DIR" 2>/dev/null || stat -f "%OLp" "$CURRENT_DIR" 2>/dev/null || echo "unknown")
        OWNER=$(stat -c "%U:%G" "$CURRENT_DIR" 2>/dev/null || stat -f "%Su:%Sg" "$CURRENT_DIR" 2>/dev/null || echo "unknown")
        echo "  $CURRENT_DIR: $PERM ($OWNER)"
        
        # 检查 www-data 是否可以访问
        if sudo -u www-data test -x "$CURRENT_DIR" 2>/dev/null; then
            echo "    ✅ www-data 可以进入"
        else
            echo "    ❌ www-data 无法进入，修复权限..."
            sudo chmod 755 "$CURRENT_DIR"
        fi
    fi
    CURRENT_DIR=$(dirname "$CURRENT_DIR")
done

# 3. 修复后端图片目录权限
echo ""
echo "ℹ️ 步骤3: 修复后端图片目录权限..."
if [ -d "$BACKEND_IMAGES_DIR" ]; then
    # 设置目录权限为 755
    chmod 755 "$BACKEND_IMAGES_DIR"
    # 设置文件权限为 644
    find "$BACKEND_IMAGES_DIR" -type f -exec chmod 644 {} \;
    find "$BACKEND_IMAGES_DIR" -type d -exec chmod 755 {} \;
    
    # 设置所有者为当前用户（因为后端可能需要写入）
    # 但确保 www-data 可以读取
    chown -R $(whoami):$(whoami) "$BACKEND_IMAGES_DIR"
    
    echo "✅ 后端图片目录权限已设置"
    ls -ld "$BACKEND_IMAGES_DIR"
fi

# 4. 处理 Nginx 图片目录
echo ""
echo "ℹ️ 步骤4: 处理 Nginx 图片目录..."

# 如果存在符号链接，先删除
if [ -L "$NGINX_IMAGES_DIR" ]; then
    echo "删除现有符号链接..."
    sudo rm "$NGINX_IMAGES_DIR"
fi

# 如果存在普通目录，检查权限
if [ -d "$NGINX_IMAGES_DIR" ]; then
    echo "目录已存在，修复权限..."
    # 设置所有父目录权限
    sudo chmod 755 "$(dirname $NGINX_IMAGES_DIR)"
    # 设置目录和文件权限
    sudo chmod -R 755 "$NGINX_IMAGES_DIR"
    sudo find "$NGINX_IMAGES_DIR" -type f -exec chmod 644 {} \;
    sudo find "$NGINX_IMAGES_DIR" -type d -exec chmod 755 {} \;
    # 设置所有者
    sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
else
    echo "创建目录..."
    sudo mkdir -p "$NGINX_IMAGES_DIR"
    sudo chmod 755 "$(dirname $NGINX_IMAGES_DIR)"
    sudo chmod 755 "$NGINX_IMAGES_DIR"
    sudo chown www-data:www-data "$NGINX_IMAGES_DIR"
fi

# 5. 复制图片文件到 Nginx 目录
echo ""
echo "ℹ️ 步骤5: 复制图片文件到 Nginx 目录..."
if [ -d "$BACKEND_IMAGES_DIR" ] && [ "$(ls -A $BACKEND_IMAGES_DIR 2>/dev/null)" ]; then
    echo "复制图片文件..."
    sudo cp -r "$BACKEND_IMAGES_DIR"/* "$NGINX_IMAGES_DIR/" 2>/dev/null || true
    sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
    sudo find "$NGINX_IMAGES_DIR" -type f -exec chmod 644 {} \;
    sudo find "$NGINX_IMAGES_DIR" -type d -exec chmod 755 {} \;
    echo "✅ 图片文件已复制"
else
    echo "⚠️ 后端图片目录为空，创建测试图片..."
    TEST_IMAGE="$NGINX_IMAGES_DIR/hongshaorou.jpg"
    sudo tee "$TEST_IMAGE" > /dev/null << 'EOF'
<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="400" height="300" fill="#f0f0f0"/>
  <text x="50%" y="50%" font-family="Arial" font-size="20" fill="#999" text-anchor="middle" dominant-baseline="middle">图片占位符</text>
</svg>
EOF
    sudo chown www-data:www-data "$TEST_IMAGE"
    sudo chmod 644 "$TEST_IMAGE"
    echo "✅ 测试图片已创建"
fi

# 6. 验证权限
echo ""
echo "ℹ️ 步骤6: 验证权限..."
echo "检查目录权限:"
ls -ld "$NGINX_IMAGES_DIR"
echo ""
echo "检查文件权限:"
ls -la "$NGINX_IMAGES_DIR" | head -5
echo ""
echo "测试 www-data 用户访问:"
if sudo -u www-data test -r "$NGINX_IMAGES_DIR" 2>/dev/null; then
    echo "✅ www-data 可以读取目录"
else
    echo "❌ www-data 无法读取目录"
    sudo chmod 755 "$NGINX_IMAGES_DIR"
    sudo chown www-data:www-data "$NGINX_IMAGES_DIR"
fi

TEST_FILE="$NGINX_IMAGES_DIR/hongshaorou.jpg"
if [ -f "$TEST_FILE" ]; then
    if sudo -u www-data test -r "$TEST_FILE" 2>/dev/null; then
        echo "✅ www-data 可以读取文件: hongshaorou.jpg"
    else
        echo "❌ www-data 无法读取文件: hongshaorou.jpg"
        echo "   修复文件权限..."
        sudo chmod 644 "$TEST_FILE"
        sudo chown www-data:www-data "$TEST_FILE"
    fi
else
    echo "⚠️ 测试文件不存在: $TEST_FILE"
fi

# 7. 检查 Nginx 配置
echo ""
echo "ℹ️ 步骤7: 检查 Nginx 配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

if sudo grep -q "location /images" "$NGINX_CONFIG"; then
    echo "✅ Nginx 配置中有 /images location"
    echo "配置内容:"
    sudo grep -A 5 "location /images" "$NGINX_CONFIG"
else
    echo "❌ Nginx 配置中缺少 /images location"
    echo "添加配置..."
    
    # 备份
    sudo cp "$NGINX_CONFIG" "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 添加配置
    sudo awk '
    /location \/api {/ {
        in_api = 1
        print
        next
    }
    in_api && /^[[:space:]]*}/ {
        in_api = 0
        print
        print ""
        print "    location /images {"
        print "        alias /var/www/canteen/images;"
        print "        expires 30d;"
        print "        add_header Cache-Control \"public, immutable\";"
        print "        access_log off;"
        print "    }"
        next
    }
    { print }
    ' "$NGINX_CONFIG" | sudo tee "${NGINX_CONFIG}.new" > /dev/null
    
    sudo mv "${NGINX_CONFIG}.new" "$NGINX_CONFIG"
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
    exit 1
fi

# 8. 测试图片访问
echo ""
echo "ℹ️ 步骤8: 测试图片访问..."
TEST_IMAGE="hongshaorou.jpg"

# 确保文件存在
if [ ! -f "$NGINX_IMAGES_DIR/$TEST_IMAGE" ]; then
    echo "创建测试图片..."
    sudo tee "$NGINX_IMAGES_DIR/$TEST_IMAGE" > /dev/null << 'EOF'
<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="400" height="300" fill="#f0f0f0"/>
  <text x="50%" y="50%" font-family="Arial" font-size="20" fill="#999" text-anchor="middle" dominant-baseline="middle">图片占位符</text>
</svg>
EOF
    sudo chown www-data:www-data "$NGINX_IMAGES_DIR/$TEST_IMAGE"
    sudo chmod 644 "$NGINX_IMAGES_DIR/$TEST_IMAGE"
fi

# 测试访问
echo "测试: http://localhost/images/$TEST_IMAGE"
img_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/images/$TEST_IMAGE" 2>&1)
echo "HTTP 状态码: $img_code"

if [ "$img_code" = "200" ]; then
    echo "✅ 图片可以正常访问"
elif [ "$img_code" = "403" ]; then
    echo "❌ 仍然返回 403"
    echo ""
    echo "详细诊断:"
    echo "1. 文件权限:"
    ls -la "$NGINX_IMAGES_DIR/$TEST_IMAGE"
    echo ""
    echo "2. 目录权限:"
    ls -ld "$NGINX_IMAGES_DIR"
    ls -ld "$(dirname $NGINX_IMAGES_DIR)"
    echo ""
    echo "3. www-data 用户测试:"
    sudo -u www-data test -x "$(dirname $NGINX_IMAGES_DIR)" && echo "   ✅ 可以进入父目录" || echo "   ❌ 无法进入父目录"
    sudo -u www-data test -x "$NGINX_IMAGES_DIR" && echo "   ✅ 可以进入图片目录" || echo "   ❌ 无法进入图片目录"
    sudo -u www-data test -r "$NGINX_IMAGES_DIR/$TEST_IMAGE" && echo "   ✅ 可以读取文件" || echo "   ❌ 无法读取文件"
    echo ""
    echo "4. Nginx 错误日志:"
    sudo tail -5 /var/log/nginx/error.log
    echo ""
    echo "5. 尝试强制修复:"
    sudo chmod 755 "$(dirname $NGINX_IMAGES_DIR)"
    sudo chmod 755 "$NGINX_IMAGES_DIR"
    sudo chmod 644 "$NGINX_IMAGES_DIR/$TEST_IMAGE"
    sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
    echo "   已强制修复权限，请再次测试"
elif [ "$img_code" = "404" ]; then
    echo "❌ 返回 404，文件不存在或路径错误"
    echo "   检查文件: ls -la $NGINX_IMAGES_DIR/$TEST_IMAGE"
else
    echo "⚠️ 返回 HTTP $img_code"
fi

# 9. 最终验证
echo ""
echo "=========================================="
echo "📋 修复结果"
echo "=========================================="
echo ""
echo "图片目录: $NGINX_IMAGES_DIR"
ls -ld "$NGINX_IMAGES_DIR"
echo ""
echo "测试文件: $NGINX_IMAGES_DIR/$TEST_IMAGE"
if [ -f "$NGINX_IMAGES_DIR/$TEST_IMAGE" ]; then
    ls -la "$NGINX_IMAGES_DIR/$TEST_IMAGE"
fi
echo ""
echo "访问测试:"
echo "  http://localhost/images/$TEST_IMAGE -> HTTP $img_code"
echo "  http://119.3.232.65/images/$TEST_IMAGE"
echo ""
if [ "$img_code" = "200" ]; then
    echo "✅ 图片访问正常"
else
    echo "❌ 图片访问仍有问题"
    echo ""
    echo "请检查:"
    echo "  1. Nginx 错误日志: sudo tail -f /var/log/nginx/error.log"
    echo "  2. 文件权限: ls -la $NGINX_IMAGES_DIR"
    echo "  3. SELinux 状态: getenforce (如果启用，可能需要设置上下文)"
fi
echo ""

