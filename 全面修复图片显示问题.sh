#!/bin/bash

# 全面修复图片显示问题

set -e

echo "=========================================="
echo "🔧 全面修复图片显示问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 创建所有图片文件
echo ""
echo "ℹ️ 步骤1: 创建所有图片文件..."
BACKEND_IMAGES_DIR="backend/static/images"
NGINX_IMAGES_DIR="/var/www/canteen/images"

mkdir -p "$BACKEND_IMAGES_DIR"

# 所有需要的图片文件
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

# 创建占位图片的SVG内容
PLACEHOLDER_SVG='<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#667eea;stop-opacity:1" /><stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" /></linearGradient></defs><rect width="400" height="300" fill="url(#grad)"/><circle cx="200" cy="120" r="40" fill="rgba(255,255,255,0.3)"/><path d="M 180 120 L 200 100 L 220 120 L 200 140 Z" fill="rgba(255,255,255,0.5)"/><text x="200" y="200" font-family="Arial" font-size="16" fill="rgba(255,255,255,0.8)" text-anchor="middle">菜品图片</text></svg>'

created_count=0
for img in "${IMAGE_FILES[@]}"; do
    if [ ! -f "$BACKEND_IMAGES_DIR/$img" ]; then
        echo "$PLACEHOLDER_SVG" > "$BACKEND_IMAGES_DIR/$img"
        created_count=$((created_count + 1))
    fi
done

if [ $created_count -gt 0 ]; then
    echo "✅ 创建了 $created_count 个占位图片"
else
    echo "✅ 所有图片文件已存在"
fi

# 2. 设置后端图片权限
echo ""
echo "ℹ️ 步骤2: 设置后端图片权限..."
chmod -R 755 "$BACKEND_IMAGES_DIR"
find "$BACKEND_IMAGES_DIR" -type f -exec chmod 644 {} \;
echo "✅ 后端图片权限已设置"

# 3. 确保 Nginx 目录存在
echo ""
echo "ℹ️ 步骤3: 确保 Nginx 目录存在..."
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

# 4. 复制所有图片到 Nginx 目录
echo ""
echo "ℹ️ 步骤4: 复制所有图片到 Nginx 目录..."
sudo rm -rf "$NGINX_IMAGES_DIR"/*
sudo cp -r "$BACKEND_IMAGES_DIR"/* "$NGINX_IMAGES_DIR/" 2>/dev/null || true

# 设置权限
sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
sudo find "$NGINX_IMAGES_DIR" -type d -exec chmod 755 {} \;
sudo find "$NGINX_IMAGES_DIR" -type f -exec chmod 644 {} \;

file_count=$(find "$NGINX_IMAGES_DIR" -type f 2>/dev/null | wc -l)
echo "✅ 已复制 $file_count 个图片文件到 Nginx 目录"

# 5. 验证文件权限
echo ""
echo "ℹ️ 步骤5: 验证文件权限..."
TEST_IMAGE="yuxiangrousi.jpg"
if [ -f "$NGINX_IMAGES_DIR/$TEST_IMAGE" ]; then
    echo "✅ 测试图片存在"
    ls -lh "$NGINX_IMAGES_DIR/$TEST_IMAGE"
    
    # 测试 www-data 用户访问
    if sudo -u www-data test -r "$NGINX_IMAGES_DIR/$TEST_IMAGE" 2>/dev/null; then
        echo "✅ www-data 用户可以读取"
    else
        echo "❌ www-data 用户无法读取，修复..."
        sudo chmod 644 "$NGINX_IMAGES_DIR/$TEST_IMAGE"
        sudo chown www-data:www-data "$NGINX_IMAGES_DIR/$TEST_IMAGE"
        sudo chmod 755 "$(dirname $NGINX_IMAGES_DIR)"
        sudo chmod 755 "$NGINX_IMAGES_DIR"
    fi
else
    echo "❌ 测试图片不存在，创建..."
    echo "$PLACEHOLDER_SVG" | sudo tee "$NGINX_IMAGES_DIR/$TEST_IMAGE" > /dev/null
    sudo chown www-data:www-data "$NGINX_IMAGES_DIR/$TEST_IMAGE"
    sudo chmod 644 "$NGINX_IMAGES_DIR/$TEST_IMAGE"
fi

# 6. 检查并修复 Nginx 配置
echo ""
echo "ℹ️ 步骤6: 检查并修复 Nginx 配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

# 备份配置
if [ ! -f "${NGINX_CONFIG}.backup.$(date +%Y%m%d)" ]; then
    sudo cp "$NGINX_CONFIG" "${NGINX_CONFIG}.backup.$(date +%Y%m%d)"
fi

# 检查配置
if ! sudo grep -q "location /images" "$NGINX_CONFIG"; then
    echo "⚠️ Nginx 配置中缺少 /images location，添加配置..."
    
    # 使用 Python 或 awk 来正确插入配置
    sudo python3 << PYTHON_SCRIPT
import re

config_file = "$NGINX_CONFIG"
with open(config_file, 'r') as f:
    content = f.read()

# 检查是否已有 /images location
if 'location /images' not in content:
    # 在 location /api 块之后添加
    pattern = r'(location /api \{.*?\n\s*\})'
    replacement = r'\1\n\n    location /images {\n        alias /var/www/canteen/images;\n        expires 30d;\n        add_header Cache-Control "public, immutable";\n        access_log off;\n    }'
    
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    with open(config_file, 'w') as f:
        f.write(content)
    print("✅ 已添加 /images location 配置")
else:
    print("✅ /images location 已存在")
PYTHON_SCRIPT
else
    echo "✅ Nginx 配置中已有 /images location"
    
    # 检查 alias 路径
    alias_path=$(sudo grep -A 5 "location /images" "$NGINX_CONFIG" | grep "alias" | awk '{print $2}' | tr -d ';' | tr -d ' ')
    if [ "$alias_path" != "/var/www/canteen/images" ]; then
        echo "⚠️ alias 路径不正确: $alias_path，修复为: /var/www/canteen/images"
        sudo sed -i "s|alias $alias_path|alias /var/www/canteen/images;|g" "$NGINX_CONFIG"
        sudo sed -i "s|alias $alias_path;|alias /var/www/canteen/images;|g" "$NGINX_CONFIG"
    fi
fi

# 显示当前配置
echo ""
echo "当前 /images location 配置:"
sudo grep -A 6 "location /images" "$NGINX_CONFIG" || echo "未找到配置"

# 验证配置
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "✅ Nginx 配置正确"
    sudo systemctl reload nginx
    sleep 2
else
    echo "❌ Nginx 配置有错误"
    sudo nginx -t
    echo ""
    echo "尝试手动修复配置..."
    # 如果配置有错误，尝试恢复备份
    if [ -f "${NGINX_CONFIG}.backup.$(date +%Y%m%d)" ]; then
        sudo cp "${NGINX_CONFIG}.backup.$(date +%Y%m%d)" "$NGINX_CONFIG"
        echo "已恢复备份配置"
    fi
    exit 1
fi

# 7. 测试图片访问
echo ""
echo "ℹ️ 步骤7: 测试图片访问..."
TEST_IMAGES=("yuxiangrousi.jpg" "hongshaorou.jpg" "mapodoufu.jpg")

for test_img in "${TEST_IMAGES[@]}"; do
    echo "测试: $test_img"
    img_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/images/$test_img" 2>&1 || echo "000")
    echo "  HTTP 状态码: $img_code"
    
    if [ "$img_code" != "200" ]; then
        echo "  ❌ 访问失败"
        echo "  检查文件:"
        ls -la "$NGINX_IMAGES_DIR/$test_img" 2>/dev/null || echo "    文件不存在"
    else
        echo "  ✅ 访问成功"
    fi
done

# 8. 检查 Nginx 错误日志
echo ""
echo "ℹ️ 步骤8: 检查 Nginx 错误日志（最近 10 行）..."
sudo tail -10 /var/log/nginx/error.log 2>/dev/null | grep -i "images\|404\|permission" || echo "未发现相关错误"

# 9. 重新构建和部署前端
echo ""
echo "ℹ️ 步骤9: 重新构建和部署前端..."
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

# 10. 最终验证
echo ""
echo "=========================================="
echo "📋 修复结果"
echo "=========================================="
echo ""
echo "图片文件:"
echo "  后端目录: $BACKEND_IMAGES_DIR ($(find "$BACKEND_IMAGES_DIR" -type f 2>/dev/null | wc -l) 个文件)"
echo "  Nginx 目录: $NGINX_IMAGES_DIR ($(find "$NGINX_IMAGES_DIR" -type f 2>/dev/null | wc -l) 个文件)"
echo ""
echo "Nginx 配置:"
sudo grep -A 5 "location /images" "$NGINX_CONFIG" | head -6
echo ""
echo "访问测试:"
for test_img in "${TEST_IMAGES[@]}"; do
    img_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/images/$test_img" 2>&1 || echo "000")
    status=$([ "$img_code" = "200" ] && echo "✅" || echo "❌")
    echo "  $status http://119.3.232.65/images/$test_img (HTTP $img_code)"
done
echo ""
echo "💡 如果图片仍不显示，请："
echo "  1. 清除浏览器缓存 (Ctrl+Shift+R)"
echo "  2. 检查浏览器控制台 (F12 → Console → Network)"
echo "  3. 查看图片请求的完整 URL 和响应"
echo "  4. 检查 Nginx 日志: sudo tail -f /var/log/nginx/error.log"
echo "  5. 手动测试: curl -v http://localhost/images/yuxiangrousi.jpg"
echo ""

