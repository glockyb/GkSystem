#!/bin/bash

# 修复图片加载问题（测试链接成功但web中不显示）

set -e

echo "=========================================="
echo "🔧 修复图片加载问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查图片文件
echo ""
echo "ℹ️ 步骤1: 检查图片文件..."
BACKEND_IMAGES_DIR="backend/static/images"
NGINX_IMAGES_DIR="/var/www/canteen/images"

if [ ! -d "$BACKEND_IMAGES_DIR" ]; then
    mkdir -p "$BACKEND_IMAGES_DIR"
    echo "✅ 创建图片目录: $BACKEND_IMAGES_DIR"
fi

# 检查图片文件数量
image_count=$(find "$BACKEND_IMAGES_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.svg" \) 2>/dev/null | wc -l)
echo "后端图片文件数量: $image_count"

# 2. 创建占位图片（如果不存在）
echo ""
echo "ℹ️ 步骤2: 创建占位图片..."
IMAGE_FILES=(
    "hongshaorou.jpg" "xihongshijidan.jpg" "gongbaojiding.jpg" "tangculiji.jpg"
    "disanxian.jpg" "qingjiaotudousi.jpg" "huiguorou.jpg" "suanlatudousi.jpg"
    "yuxiangrousi.jpg" "mapodoufu.jpg" "shuizhuyu.jpg" "koushuiji.jpg"
    "laziji.jpg" "hongshaopaigu.jpg" "kelejichi.jpg" "baiqieji.jpg"
    "tangcupaigu.jpg" "hongshaoshizitou.jpg" "ganbiandoujiao.jpg" "suanrongxilanhua.jpg"
    "qingchaoxiaobaicai.jpg" "culiubaicai.jpg" "liangbanhuanggua.jpg" "suanrongbocai.jpg"
    "ganguohuacai.jpg" "qingchaoshishu.jpg" "suanrongkongxincai.jpg" "liangbandoufu.jpg"
    "zicaidanhuatang.jpg" "xihongshijidantang.jpg" "dongguapaigutang.jpg" "yumipaigutang.jpg"
    "yinerlianzitang.jpg" "zicaixiapitang.jpg" "suanlatang.jpg" "dongguatang.jpg"
    "danchaofan.jpg" "yangzhouchaoan.jpg" "xihongshijidanmian.jpg" "zhajiangmian.jpg"
    "niuroumian.jpg" "dandanmian.jpg" "shuijiao.jpg" "xiaolongbao.jpg"
    "zhengjiao.jpg" "huntun.jpg" "baimifan.jpg" "xiaomizhou.jpg"
    "babaozhou.jpg" "zhajipai.jpg" "zhashutiao.jpg" "jimihua.jpg"
    "kaojichi.jpg" "shouzhuabing.jpg" "jianbingguozi.jpg" "kaolengmian.jpg"
    "guandongzhu.jpg"
)

created_count=0
for img in "${IMAGE_FILES[@]}"; do
    if [ ! -f "$BACKEND_IMAGES_DIR/$img" ]; then
        # 创建 SVG 占位图片
        cat > "$BACKEND_IMAGES_DIR/$img" << 'EOF'
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
        created_count=$((created_count + 1))
    fi
done

if [ $created_count -gt 0 ]; then
    echo "✅ 创建了 $created_count 个占位图片"
fi

# 3. 设置图片权限
echo ""
echo "ℹ️ 步骤3: 设置图片权限..."
chmod -R 755 "$BACKEND_IMAGES_DIR"
find "$BACKEND_IMAGES_DIR" -type f -exec chmod 644 {} \;
echo "✅ 图片权限已设置"

# 4. 复制图片到 Nginx 目录
echo ""
echo "ℹ️ 步骤4: 复制图片到 Nginx 目录..."
if [ -L "$NGINX_IMAGES_DIR" ]; then
    sudo rm "$NGINX_IMAGES_DIR"
fi

if [ ! -d "$NGINX_IMAGES_DIR" ]; then
    sudo mkdir -p "$NGINX_IMAGES_DIR"
fi

sudo cp -r "$BACKEND_IMAGES_DIR"/* "$NGINX_IMAGES_DIR/" 2>/dev/null || true
sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
sudo find "$NGINX_IMAGES_DIR" -type d -exec chmod 755 {} \;
sudo find "$NGINX_IMAGES_DIR" -type f -exec chmod 644 {} \;
echo "✅ 图片已复制到 Nginx 目录"

# 5. 检查 Nginx 配置
echo ""
echo "ℹ️ 步骤5: 检查 Nginx 配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

if ! sudo grep -q "location /images" "$NGINX_CONFIG"; then
    echo "⚠️ Nginx 配置中缺少 /images location，添加配置..."
    
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
    echo "✅ 已添加 /images location 配置"
fi

# 验证配置
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "✅ Nginx 配置正确"
    sudo systemctl reload nginx
else
    echo "❌ Nginx 配置有错误"
    sudo nginx -t
    exit 1
fi

# 6. 测试图片访问
echo ""
echo "ℹ️ 步骤6: 测试图片访问..."
TEST_IMAGE="hongshaorou.jpg"

# 测试直接访问
direct_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5000/static/images/$TEST_IMAGE" 2>&1 || echo "000")
echo "直接访问后端: HTTP $direct_code"

# 测试通过 Nginx
nginx_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/images/$TEST_IMAGE" 2>&1 || echo "000")
echo "通过 Nginx: HTTP $nginx_code"

if [ "$nginx_code" = "200" ]; then
    echo "✅ 图片可以通过 Nginx 访问"
else
    echo "⚠️ 图片访问返回 HTTP $nginx_code"
    echo "   检查文件:"
    ls -la "$NGINX_IMAGES_DIR/$TEST_IMAGE" 2>/dev/null || echo "   文件不存在"
    echo "   检查权限:"
    sudo -u www-data test -r "$NGINX_IMAGES_DIR/$TEST_IMAGE" && echo "   ✅ www-data 可读" || echo "   ❌ www-data 不可读"
fi

# 7. 检查前端代码中的图片路径处理
echo ""
echo "ℹ️ 步骤7: 检查前端代码..."
if grep -q "getImageUrl" frontend/src/views/Home.vue; then
    echo "✅ 前端代码中有图片路径处理函数"
else
    echo "⚠️ 前端代码中可能缺少图片路径处理"
fi

# 8. 重新构建和部署前端
echo ""
echo "ℹ️ 步骤8: 重新构建和部署前端..."
cd frontend

if [ -d "dist" ]; then
    rm -rf dist
fi

unset VITE_API_URL
export VITE_API_URL=""
npm run build

if [ ! -d "dist" ] || [ ! -f "dist/index.html" ]; then
    echo "❌ 前端构建失败"
    exit 1
fi

echo "✅ 前端构建成功"

# 部署到 Nginx
sudo rm -rf /var/www/canteen/*
sudo cp -r dist/* /var/www/canteen/
sudo chown -R www-data:www-data /var/www/canteen
sudo chmod -R 755 /var/www/canteen

echo "✅ 前端已部署"

# 重载 Nginx
sudo systemctl reload nginx

cd ..

# 9. 总结
echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "图片配置:"
echo "  后端目录: $BACKEND_IMAGES_DIR"
echo "  Nginx 目录: $NGINX_IMAGES_DIR"
echo "  图片数量: $(find "$NGINX_IMAGES_DIR" -type f 2>/dev/null | wc -l)"
echo ""
echo "💡 如果图片仍不显示，请："
echo "  1. 清除浏览器缓存 (Ctrl+Shift+R)"
echo "  2. 检查浏览器控制台 (F12 → Console → Network)"
echo "  3. 查看图片请求的 URL 和状态码"
echo "  4. 测试图片链接: http://119.3.232.65/images/hongshaorou.jpg"
echo ""

