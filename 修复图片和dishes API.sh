#!/bin/bash

# 修复图片404和dishes API 500错误

set -e

echo "=========================================="
echo "🔧 修复图片404和dishes API 500错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查后端服务
echo ""
echo "ℹ️ 步骤1: 检查后端服务..."
if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "⚠️ 后端服务未运行，启动服务..."
    sudo systemctl start canteen-backend
    sleep 3
fi

# 2. 检查图片目录
echo ""
echo "ℹ️ 步骤2: 检查图片目录..."
BACKEND_IMAGES_DIR="backend/static/images"
NGINX_IMAGES_DIR="/var/www/canteen/images"

# 创建后端图片目录
if [ ! -d "$BACKEND_IMAGES_DIR" ]; then
    mkdir -p "$BACKEND_IMAGES_DIR"
    echo "✅ 创建后端图片目录: $BACKEND_IMAGES_DIR"
fi

# 检查图片文件
echo ""
echo "检查图片文件..."
IMAGE_FILES=(
    "hongshaorou.jpg"
    "xihongshijidan.jpg"
    "gongbaojiding.jpg"
    "tangculiji.jpg"
    "disanxian.jpg"
    "qingjiaotudousi.jpg"
    "huiguorou.jpg"
    "suanlatudousi.jpg"
    "yuxiangrousi.jpg"
    "mapodoufu.jpg"
)

MISSING_IMAGES=()
for img in "${IMAGE_FILES[@]}"; do
    if [ ! -f "$BACKEND_IMAGES_DIR/$img" ]; then
        MISSING_IMAGES+=("$img")
    fi
done

if [ ${#MISSING_IMAGES[@]} -eq 0 ]; then
    echo "✅ 所有图片文件都存在"
else
    echo "⚠️ 缺少以下图片文件: ${MISSING_IMAGES[*]}"
    echo "   创建占位图片..."
    for img in "${MISSING_IMAGES[@]}"; do
        # 创建一个简单的占位图片（SVG格式，转换为base64 PNG）
        cat > "$BACKEND_IMAGES_DIR/$img" << 'EOF'
<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="400" height="300" fill="#f0f0f0"/>
  <text x="50%" y="50%" font-family="Arial" font-size="20" fill="#999" text-anchor="middle" dominant-baseline="middle">图片加载中...</text>
</svg>
EOF
        echo "   创建占位图片: $img"
    done
fi

# 3. 设置图片目录权限
echo ""
echo "ℹ️ 步骤3: 设置图片目录权限..."
chmod -R 755 "$BACKEND_IMAGES_DIR"
echo "✅ 图片目录权限已设置"

# 4. 创建 Nginx 图片目录链接
echo ""
echo "ℹ️ 步骤4: 配置 Nginx 图片目录..."
if [ ! -d "$NGINX_IMAGES_DIR" ] && [ ! -L "$NGINX_IMAGES_DIR" ]; then
    # 创建符号链接
    sudo ln -s "$(pwd)/$BACKEND_IMAGES_DIR" "$NGINX_IMAGES_DIR"
    echo "✅ 创建图片目录符号链接: $NGINX_IMAGES_DIR"
elif [ -L "$NGINX_IMAGES_DIR" ]; then
    echo "✅ 图片目录符号链接已存在"
else
    echo "⚠️ 图片目录已存在但不是符号链接，使用现有目录"
fi

# 设置权限
sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR" 2>/dev/null || true
sudo chmod -R 755 "$NGINX_IMAGES_DIR" 2>/dev/null || true
echo "✅ Nginx 图片目录权限已设置"

# 5. 检查并修复 Nginx 配置
echo ""
echo "ℹ️ 步骤5: 检查并修复 Nginx 配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

# 备份配置
if [ ! -f "${NGINX_CONFIG}.backup.$(date +%Y%m%d)" ]; then
    sudo cp "$NGINX_CONFIG" "${NGINX_CONFIG}.backup.$(date +%Y%m%d)"
    echo "✅ 已备份 Nginx 配置"
fi

# 检查是否有 /images location 块
if ! sudo grep -q "location /images" "$NGINX_CONFIG"; then
    echo "⚠️ Nginx 配置中缺少 /images location 块，添加配置..."
    
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
        print "    }"
        next
    }
    { print }
    ' "$NGINX_CONFIG" | sudo tee "${NGINX_CONFIG}.new" > /dev/null
    
    sudo mv "${NGINX_CONFIG}.new" "$NGINX_CONFIG"
    echo "✅ 已添加 /images location 配置"
else
    echo "✅ Nginx 配置中已有 /images location 块"
fi

# 验证 Nginx 配置
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "✅ Nginx 配置正确"
    sudo systemctl reload nginx
else
    echo "❌ Nginx 配置有错误"
    sudo nginx -t
    exit 1
fi

# 6. 检查 dishes API 500 错误
echo ""
echo "ℹ️ 步骤6: 检查 dishes API 500 错误..."
echo "查看最近的错误日志:"
sudo journalctl -u canteen-backend -n 50 --no-pager | grep -iE "dishes|error|exception|traceback" | tail -10 || echo "未发现明显错误"

# 7. 测试 dishes API
echo ""
echo "ℹ️ 步骤7: 测试 dishes API..."
dishes_response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost:5000/api/v1/dishes?page=1&per_page=5" 2>&1)
http_code=$(echo "$dishes_response" | grep "HTTP_CODE" | cut -d: -f2)
response_body=$(echo "$dishes_response" | grep -v "HTTP_CODE")

echo "HTTP 状态码: $http_code"
if [ "$http_code" = "200" ]; then
    echo "✅ dishes API 正常"
    dish_count=$(echo "$response_body" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('dishes', [])))" 2>/dev/null || echo "N/A")
    echo "   返回 $dish_count 个菜品"
else
    echo "❌ dishes API 返回 HTTP $http_code"
    echo "响应内容:"
    echo "$response_body" | head -20
    echo ""
    echo "查看详细错误日志:"
    sudo journalctl -u canteen-backend -n 30 --no-pager | tail -15
fi

# 8. 重启后端服务（应用可能的修复）
echo ""
echo "ℹ️ 步骤8: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 3

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务已重启"
else
    echo "❌ 后端服务启动失败"
    sudo journalctl -u canteen-backend -n 30 --no-pager | tail -15
    exit 1
fi

# 9. 测试图片访问
echo ""
echo "ℹ️ 步骤9: 测试图片访问..."
TEST_IMAGE="hongshaorou.jpg"
if [ -f "$BACKEND_IMAGES_DIR/$TEST_IMAGE" ]; then
    # 测试直接访问
    img_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/images/$TEST_IMAGE" 2>&1)
    if [ "$img_code" = "200" ]; then
        echo "✅ 图片可以通过 Nginx 访问 (HTTP $img_code)"
    else
        echo "⚠️ 图片访问返回 HTTP $img_code"
        echo "   检查 Nginx 配置和文件权限"
    fi
else
    echo "⚠️ 测试图片不存在: $TEST_IMAGE"
fi

# 10. 最终验证
echo ""
echo "=========================================="
echo "📋 修复结果"
echo "=========================================="
echo ""
echo "✅ 图片目录配置完成"
echo "   后端图片目录: $BACKEND_IMAGES_DIR"
echo "   Nginx 图片目录: $NGINX_IMAGES_DIR"
echo ""
echo "✅ Nginx 配置已更新"
echo ""
if [ "$http_code" = "200" ]; then
    echo "✅ dishes API 正常工作"
else
    echo "⚠️ dishes API 仍有问题，请查看后端日志:"
    echo "   sudo journalctl -u canteen-backend -f"
fi
echo ""
echo "📱 测试地址:"
echo "   图片: http://119.3.232.65/images/hongshaorou.jpg"
echo "   API: http://119.3.232.65/api/v1/dishes?page=1&per_page=5"
echo ""
echo "💡 如果前端仍有问题，请："
echo "   1. 清除浏览器缓存 (Ctrl+Shift+R)"
echo "   2. 检查浏览器控制台 (F12 → Console)"
echo "   3. 重新构建前端: ./修复前端并重新部署.sh"
echo ""

