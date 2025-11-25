#!/bin/bash

# 修复图片403和dishes API 500错误

set -e

echo "=========================================="
echo "🔧 修复图片403和dishes API 500错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 修复图片权限问题（403 Forbidden）
echo ""
echo "ℹ️ 步骤1: 修复图片权限问题（403 Forbidden）..."
BACKEND_IMAGES_DIR="backend/static/images"
NGINX_IMAGES_DIR="/var/www/canteen/images"

# 确保图片目录存在
if [ ! -d "$BACKEND_IMAGES_DIR" ]; then
    mkdir -p "$BACKEND_IMAGES_DIR"
    echo "✅ 创建图片目录: $BACKEND_IMAGES_DIR"
fi

# 设置图片目录和文件权限
echo "设置图片目录权限..."
chmod -R 755 "$BACKEND_IMAGES_DIR"
find "$BACKEND_IMAGES_DIR" -type f -exec chmod 644 {} \;
echo "✅ 后端图片目录权限已设置"

# 确保 Nginx 可以访问图片
echo ""
echo "检查 Nginx 图片目录..."
if [ -L "$NGINX_IMAGES_DIR" ]; then
    echo "✅ 图片目录是符号链接"
    REAL_PATH=$(readlink -f "$NGINX_IMAGES_DIR")
    echo "   实际路径: $REAL_PATH"
    
    # 确保实际目录权限正确
    if [ -d "$REAL_PATH" ]; then
        sudo chown -R www-data:www-data "$REAL_PATH"
        sudo chmod -R 755 "$REAL_PATH"
        sudo find "$REAL_PATH" -type f -exec chmod 644 {} \;
        echo "✅ 实际目录权限已设置"
    fi
elif [ -d "$NGINX_IMAGES_DIR" ]; then
    echo "✅ 图片目录存在"
    sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
    sudo chmod -R 755 "$NGINX_IMAGES_DIR"
    sudo find "$NGINX_IMAGES_DIR" -type f -exec chmod 644 {} \;
    echo "✅ Nginx 图片目录权限已设置"
else
    echo "⚠️ Nginx 图片目录不存在，创建符号链接..."
    sudo mkdir -p "$(dirname $NGINX_IMAGES_DIR)"
    sudo ln -s "$(pwd)/$BACKEND_IMAGES_DIR" "$NGINX_IMAGES_DIR"
    sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
    sudo chmod -R 755 "$NGINX_IMAGES_DIR"
    echo "✅ 已创建符号链接并设置权限"
fi

# 测试 Nginx 用户是否可以访问
echo ""
echo "测试 Nginx 用户访问权限..."
if sudo -u www-data test -r "$NGINX_IMAGES_DIR" 2>/dev/null; then
    echo "✅ Nginx 用户可以读取图片目录"
else
    echo "❌ Nginx 用户无法读取图片目录，修复权限..."
    sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
    sudo chmod -R 755 "$NGINX_IMAGES_DIR"
fi

# 2. 检查并修复 Nginx 配置
echo ""
echo "ℹ️ 步骤2: 检查并修复 Nginx 配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

# 检查 /images location 配置
if ! sudo grep -q "location /images" "$NGINX_CONFIG"; then
    echo "⚠️ Nginx 配置中缺少 /images location，添加配置..."
    
    # 备份配置
    if [ ! -f "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)" ]; then
        sudo cp "$NGINX_CONFIG" "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 使用 awk 在 location /api 块之后添加 /images 配置
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
    echo "✅ 已添加 /images location 配置"
else
    echo "✅ Nginx 配置中已有 /images location"
fi

# 验证并重载 Nginx
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "✅ Nginx 配置正确"
    sudo systemctl reload nginx
    sleep 1
else
    echo "❌ Nginx 配置有错误"
    sudo nginx -t
    exit 1
fi

# 3. 检查 dishes API 500 错误
echo ""
echo "ℹ️ 步骤3: 检查 dishes API 500 错误..."
echo "查看后端服务状态..."
if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "⚠️ 后端服务未运行，启动服务..."
    sudo systemctl start canteen-backend
    sleep 3
fi

# 查看最近的错误日志
echo ""
echo "查看最近的错误日志（最近 30 行）..."
sudo journalctl -u canteen-backend -n 30 --no-pager | tail -20

# 4. 测试 dishes API
echo ""
echo "ℹ️ 步骤4: 测试 dishes API..."
dishes_response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost:5000/api/v1/dishes?page=1&per_page=5" 2>&1)
http_code=$(echo "$dishes_response" | grep "HTTP_CODE" | cut -d: -f2)
response_body=$(echo "$dishes_response" | grep -v "HTTP_CODE")

echo "HTTP 状态码: $http_code"
if [ "$http_code" = "200" ]; then
    echo "✅ dishes API 正常"
    dish_count=$(echo "$response_body" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('dishes', [])))" 2>/dev/null || echo "N/A")
    echo "   返回 $dish_count 个菜品"
    echo ""
    echo "响应示例（前200字符）:"
    echo "$response_body" | head -c 200
    echo "..."
else
    echo "❌ dishes API 返回 HTTP $http_code"
    echo "完整响应:"
    echo "$response_body"
    echo ""
    echo "查看详细错误日志:"
    sudo journalctl -u canteen-backend -n 50 --no-pager | grep -iE "dishes|error|exception|traceback" | tail -20
fi

# 5. 重启后端服务
echo ""
echo "ℹ️ 步骤5: 重启后端服务（应用代码修复）..."
sudo systemctl restart canteen-backend
sleep 3

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务已重启"
else
    echo "❌ 后端服务启动失败"
    echo "查看错误日志:"
    sudo journalctl -u canteen-backend -n 30 --no-pager | tail -15
    exit 1
fi

# 6. 再次测试 API
echo ""
echo "ℹ️ 步骤6: 再次测试 dishes API..."
sleep 2
dishes_response2=$(curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost:5000/api/v1/dishes?page=1&per_page=5" 2>&1)
http_code2=$(echo "$dishes_response2" | grep "HTTP_CODE" | cut -d: -f2)

if [ "$http_code2" = "200" ]; then
    echo "✅ dishes API 现在正常 (HTTP $http_code2)"
else
    echo "❌ dishes API 仍然返回 HTTP $http_code2"
    echo "请查看实时日志: sudo journalctl -u canteen-backend -f"
fi

# 7. 测试图片访问
echo ""
echo "ℹ️ 步骤7: 测试图片访问..."
TEST_IMAGE="hongshaorou.jpg"

# 确保测试图片存在
if [ ! -f "$BACKEND_IMAGES_DIR/$TEST_IMAGE" ]; then
    echo "创建测试图片..."
    cat > "$BACKEND_IMAGES_DIR/$TEST_IMAGE" << 'EOF'
<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="400" height="300" fill="#f0f0f0"/>
  <text x="50%" y="50%" font-family="Arial" font-size="20" fill="#999" text-anchor="middle" dominant-baseline="middle">图片占位符</text>
</svg>
EOF
    sudo chown www-data:www-data "$BACKEND_IMAGES_DIR/$TEST_IMAGE"
    sudo chmod 644 "$BACKEND_IMAGES_DIR/$TEST_IMAGE"
fi

# 测试通过 Nginx 访问
img_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/images/$TEST_IMAGE" 2>&1)
echo "图片访问测试: http://localhost/images/$TEST_IMAGE"
echo "HTTP 状态码: $img_code"

if [ "$img_code" = "200" ]; then
    echo "✅ 图片可以通过 Nginx 访问"
elif [ "$img_code" = "403" ]; then
    echo "❌ 图片访问返回 403 Forbidden"
    echo "   检查权限:"
    ls -la "$NGINX_IMAGES_DIR/$TEST_IMAGE" 2>/dev/null || echo "   文件不存在"
    echo "   Nginx 用户测试:"
    sudo -u www-data test -r "$NGINX_IMAGES_DIR/$TEST_IMAGE" && echo "   ✅ 可读" || echo "   ❌ 不可读"
elif [ "$img_code" = "404" ]; then
    echo "❌ 图片访问返回 404 Not Found"
    echo "   检查文件路径:"
    ls -la "$NGINX_IMAGES_DIR/$TEST_IMAGE" 2>/dev/null || echo "   文件不存在"
else
    echo "⚠️ 图片访问返回 HTTP $img_code"
fi

# 8. 最终验证
echo ""
echo "=========================================="
echo "📋 修复结果"
echo "=========================================="
echo ""
echo "图片权限:"
echo "  后端目录: $BACKEND_IMAGES_DIR"
ls -ld "$BACKEND_IMAGES_DIR" 2>/dev/null || echo "  目录不存在"
echo "  Nginx 目录: $NGINX_IMAGES_DIR"
ls -ld "$NGINX_IMAGES_DIR" 2>/dev/null || echo "  目录不存在"
echo ""
echo "API 状态:"
if [ "$http_code2" = "200" ]; then
    echo "  ✅ dishes API 正常工作"
else
    echo "  ❌ dishes API 仍有问题"
    echo "     请运行: sudo journalctl -u canteen-backend -f"
fi
echo ""
echo "图片访问:"
if [ "$img_code" = "200" ]; then
    echo "  ✅ 图片可以正常访问"
else
    echo "  ❌ 图片访问仍有问题 (HTTP $img_code)"
    echo "     检查 Nginx 日志: sudo tail -f /var/log/nginx/error.log"
fi
echo ""
echo "📱 测试地址:"
echo "   图片: http://119.3.232.65/images/hongshaorou.jpg"
echo "   API: http://119.3.232.65/api/v1/dishes?page=1&per_page=5"
echo ""
echo "💡 如果前端仍有问题，请："
echo "   1. 清除浏览器缓存 (Ctrl+Shift+R)"
echo "   2. 检查浏览器控制台 (F12 → Console)"
echo "   3. 查看后端日志: sudo journalctl -u canteen-backend -f"
echo ""

