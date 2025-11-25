#!/bin/bash

# 诊断并修复图片404问题

set -e

echo "=========================================="
echo "🔍 诊断并修复图片404问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查图片文件
echo ""
echo "ℹ️ 步骤1: 检查图片文件..."
BACKEND_IMAGES_DIR="backend/static/images"
NGINX_IMAGES_DIR="/var/www/canteen/images"

echo "后端图片目录: $BACKEND_IMAGES_DIR"
if [ -d "$BACKEND_IMAGES_DIR" ]; then
    echo "✅ 目录存在"
    file_count=$(find "$BACKEND_IMAGES_DIR" -type f 2>/dev/null | wc -l)
    echo "   文件数量: $file_count"
    echo "   示例文件:"
    ls -lh "$BACKEND_IMAGES_DIR" | head -5
else
    echo "❌ 目录不存在"
    mkdir -p "$BACKEND_IMAGES_DIR"
fi

echo ""
echo "Nginx 图片目录: $NGINX_IMAGES_DIR"
if [ -d "$NGINX_IMAGES_DIR" ] || [ -L "$NGINX_IMAGES_DIR" ]; then
    echo "✅ 目录存在"
    if [ -L "$NGINX_IMAGES_DIR" ]; then
        echo "   是符号链接"
        real_path=$(readlink -f "$NGINX_IMAGES_DIR")
        echo "   实际路径: $real_path"
    fi
    file_count=$(find "$NGINX_IMAGES_DIR" -type f 2>/dev/null | wc -l)
    echo "   文件数量: $file_count"
    echo "   示例文件:"
    ls -lh "$NGINX_IMAGES_DIR" 2>/dev/null | head -5 || echo "   无法列出文件"
else
    echo "❌ 目录不存在"
fi

# 2. 检查特定图片文件
echo ""
echo "ℹ️ 步骤2: 检查特定图片文件..."
TEST_IMAGE="yuxiangrousi.jpg"

echo "检查: $TEST_IMAGE"
if [ -f "$BACKEND_IMAGES_DIR/$TEST_IMAGE" ]; then
    echo "✅ 后端文件存在: $BACKEND_IMAGES_DIR/$TEST_IMAGE"
    ls -lh "$BACKEND_IMAGES_DIR/$TEST_IMAGE"
else
    echo "❌ 后端文件不存在"
fi

if [ -f "$NGINX_IMAGES_DIR/$TEST_IMAGE" ]; then
    echo "✅ Nginx 文件存在: $NGINX_IMAGES_DIR/$TEST_IMAGE"
    ls -lh "$NGINX_IMAGES_DIR/$TEST_IMAGE"
else
    echo "❌ Nginx 文件不存在"
fi

# 3. 创建所有缺失的图片文件
echo ""
echo "ℹ️ 步骤3: 创建所有缺失的图片文件..."
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
    "guandongzhu.jpg" "suanrongfensizhengshanbei.jpg"
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

# 4. 设置权限
echo ""
echo "ℹ️ 步骤4: 设置图片权限..."
chmod -R 755 "$BACKEND_IMAGES_DIR"
find "$BACKEND_IMAGES_DIR" -type f -exec chmod 644 {} \;
echo "✅ 后端图片权限已设置"

# 5. 确保 Nginx 目录存在并复制文件
echo ""
echo "ℹ️ 步骤5: 确保 Nginx 目录存在并复制文件..."
# 删除符号链接（如果存在）
if [ -L "$NGINX_IMAGES_DIR" ]; then
    echo "删除现有符号链接..."
    sudo rm "$NGINX_IMAGES_DIR"
fi

# 创建目录
if [ ! -d "$NGINX_IMAGES_DIR" ]; then
    sudo mkdir -p "$NGINX_IMAGES_DIR"
    echo "✅ 创建 Nginx 图片目录"
fi

# 复制所有图片文件
echo "复制图片文件到 Nginx 目录..."
sudo cp -r "$BACKEND_IMAGES_DIR"/* "$NGINX_IMAGES_DIR/" 2>/dev/null || true

# 设置权限
sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
sudo find "$NGINX_IMAGES_DIR" -type d -exec chmod 755 {} \;
sudo find "$NGINX_IMAGES_DIR" -type f -exec chmod 644 {} \;
echo "✅ 图片已复制到 Nginx 目录"

# 6. 验证文件
echo ""
echo "ℹ️ 步骤6: 验证文件..."
if [ -f "$NGINX_IMAGES_DIR/$TEST_IMAGE" ]; then
    echo "✅ 测试图片存在: $NGINX_IMAGES_DIR/$TEST_IMAGE"
    ls -lh "$NGINX_IMAGES_DIR/$TEST_IMAGE"
    
    # 检查权限
    if sudo -u www-data test -r "$NGINX_IMAGES_DIR/$TEST_IMAGE" 2>/dev/null; then
        echo "✅ www-data 用户可以读取"
    else
        echo "❌ www-data 用户无法读取，修复权限..."
        sudo chmod 644 "$NGINX_IMAGES_DIR/$TEST_IMAGE"
        sudo chown www-data:www-data "$NGINX_IMAGES_DIR/$TEST_IMAGE"
    fi
else
    echo "❌ 测试图片不存在"
    echo "   手动创建..."
    sudo tee "$NGINX_IMAGES_DIR/$TEST_IMAGE" > /dev/null << 'EOF'
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
    sudo chown www-data:www-data "$NGINX_IMAGES_DIR/$TEST_IMAGE"
    sudo chmod 644 "$NGINX_IMAGES_DIR/$TEST_IMAGE"
fi

# 7. 检查 Nginx 配置
echo ""
echo "ℹ️ 步骤7: 检查 Nginx 配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

if sudo grep -q "location /images" "$NGINX_CONFIG"; then
    echo "✅ Nginx 配置中有 /images location"
    echo "配置内容:"
    sudo grep -A 5 "location /images" "$NGINX_CONFIG"
    
    # 检查 alias 路径是否正确
    alias_path=$(sudo grep -A 5 "location /images" "$NGINX_CONFIG" | grep "alias" | awk '{print $2}' | tr -d ';')
    echo ""
    echo "配置的 alias 路径: $alias_path"
    
    if [ "$alias_path" != "/var/www/canteen/images" ]; then
        echo "⚠️ alias 路径不正确，修复..."
        sudo sed -i "s|alias $alias_path|alias /var/www/canteen/images|g" "$NGINX_CONFIG"
        echo "✅ 已修复 alias 路径"
    fi
else
    echo "❌ Nginx 配置中缺少 /images location，添加配置..."
    
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
    sleep 1
else
    echo "❌ Nginx 配置有错误"
    sudo nginx -t
    exit 1
fi

# 8. 测试图片访问
echo ""
echo "ℹ️ 步骤8: 测试图片访问..."
echo "测试: http://localhost/images/$TEST_IMAGE"
img_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/images/$TEST_IMAGE" 2>&1 || echo "000")
echo "HTTP 状态码: $img_code"

if [ "$img_code" = "200" ]; then
    echo "✅ 图片可以正常访问"
    
    # 测试内容类型
    content_type=$(curl -s -I "http://localhost/images/$TEST_IMAGE" 2>&1 | grep -i "content-type" || echo "")
    echo "Content-Type: $content_type"
else
    echo "❌ 图片访问返回 HTTP $img_code"
    echo ""
    echo "详细诊断:"
    echo "1. 文件是否存在:"
    ls -la "$NGINX_IMAGES_DIR/$TEST_IMAGE" 2>/dev/null || echo "   文件不存在"
    echo ""
    echo "2. 文件权限:"
    if [ -f "$NGINX_IMAGES_DIR/$TEST_IMAGE" ]; then
        ls -lh "$NGINX_IMAGES_DIR/$TEST_IMAGE"
    fi
    echo ""
    echo "3. www-data 用户测试:"
    sudo -u www-data test -r "$NGINX_IMAGES_DIR/$TEST_IMAGE" && echo "   ✅ 可读" || echo "   ❌ 不可读"
    echo ""
    echo "4. Nginx 错误日志:"
    sudo tail -5 /var/log/nginx/error.log
    echo ""
    echo "5. 目录权限:"
    ls -ld "$NGINX_IMAGES_DIR"
    ls -ld "$(dirname $NGINX_IMAGES_DIR)"
fi

# 9. 检查所有图片文件
echo ""
echo "ℹ️ 步骤9: 检查所有图片文件..."
missing_count=0
for img in "${IMAGE_FILES[@]}"; do
    if [ ! -f "$NGINX_IMAGES_DIR/$img" ]; then
        echo "⚠️ 缺失: $img"
        missing_count=$((missing_count + 1))
    fi
done

if [ $missing_count -eq 0 ]; then
    echo "✅ 所有图片文件都存在"
else
    echo "⚠️ 缺失 $missing_count 个图片文件"
    echo "   重新复制..."
    sudo cp -r "$BACKEND_IMAGES_DIR"/* "$NGINX_IMAGES_DIR/" 2>/dev/null || true
    sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
    sudo find "$NGINX_IMAGES_DIR" -type f -exec chmod 644 {} \;
fi

# 10. 最终验证
echo ""
echo "=========================================="
echo "📋 诊断结果"
echo "=========================================="
echo ""
echo "图片目录: $NGINX_IMAGES_DIR"
echo "文件数量: $(find "$NGINX_IMAGES_DIR" -type f 2>/dev/null | wc -l)"
echo ""
echo "测试图片: $TEST_IMAGE"
if [ -f "$NGINX_IMAGES_DIR/$TEST_IMAGE" ]; then
    echo "✅ 文件存在"
    echo "   权限: $(stat -c "%a %U:%G" "$NGINX_IMAGES_DIR/$TEST_IMAGE" 2>/dev/null || echo "unknown")"
else
    echo "❌ 文件不存在"
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
    echo "  3. Nginx 配置: sudo cat /etc/nginx/sites-available/canteen | grep -A 5 'location /images'"
fi
echo ""

