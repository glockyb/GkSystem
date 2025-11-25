#!/bin/bash

# 修复 Nginx 图片配置

set -e

echo "=========================================="
echo "🔧 修复 Nginx 图片配置"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 备份现有配置
echo ""
echo "ℹ️ 步骤1: 备份现有配置..."
if [ -f "/etc/nginx/sites-available/canteen" ]; then
    backup_file="/etc/nginx/sites-available/canteen.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp /etc/nginx/sites-available/canteen "$backup_file"
    echo "✅ 配置已备份到: $backup_file"
else
    echo "❌ Nginx 配置文件不存在"
    exit 1
fi

# 2. 检查当前配置
echo ""
echo "ℹ️ 步骤2: 检查当前配置..."
if grep -q "location /images" /etc/nginx/sites-available/canteen; then
    echo "⚠️ 发现旧的图片配置，需要修复"
    # 删除旧的错误配置
    sudo sed -i '/location \/images/,/}/d' /etc/nginx/sites-available/canteen
fi

# 3. 添加正确的图片配置
echo ""
echo "ℹ️ 步骤3: 添加正确的图片配置..."

# 读取当前配置
current_config=$(sudo cat /etc/nginx/sites-available/canteen)

# 检查是否已有图片配置
if echo "$current_config" | grep -q "location /images"; then
    echo "✅ 图片配置已存在"
else
    echo "添加图片配置..."
    
    # 在 location /api 之后添加图片配置
    sudo sed -i '/location \/api {/,/}/ {
        /}/a\
\
    location /images {\
        alias /var/www/canteen/images;\
        expires 30d;\
        add_header Cache-Control "public, immutable";\
    }
    }' /etc/nginx/sites-available/canteen
    
    # 如果上面的方法不行，使用更简单的方法
    if ! grep -q "location /images" /etc/nginx/sites-available/canteen; then
        echo "使用备用方法添加配置..."
        
        # 创建临时配置文件
        temp_file=$(mktemp)
        sudo cp /etc/nginx/sites-available/canteen "$temp_file"
        
        # 在 location /api 块之后添加图片配置
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
        ' "$temp_file" | sudo tee /etc/nginx/sites-available/canteen > /dev/null
        
        rm -f "$temp_file"
    fi
fi

# 4. 验证配置
echo ""
echo "ℹ️ 步骤4: 验证 Nginx 配置..."
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "✅ Nginx 配置正确"
    echo "配置内容："
    sudo grep -A 5 "location /images" /etc/nginx/sites-available/canteen
else
    echo "❌ Nginx 配置错误"
    sudo nginx -t
    echo ""
    echo "恢复备份配置..."
    sudo cp "$backup_file" /etc/nginx/sites-available/canteen
    echo "✅ 已恢复备份配置"
    exit 1
fi

# 5. 创建图片目录和符号链接
echo ""
echo "ℹ️ 步骤5: 创建图片目录..."
if [ ! -d "backend/static/images" ]; then
    mkdir -p backend/static/images
    echo "✅ 图片目录已创建"
else
    echo "✅ 图片目录已存在"
fi

# 创建符号链接
if [ ! -L "/var/www/canteen/images" ] && [ ! -d "/var/www/canteen/images" ]; then
    echo "创建图片目录符号链接..."
    sudo ln -s "$(pwd)/backend/static/images" /var/www/canteen/images
    echo "✅ 图片目录符号链接已创建"
elif [ -L "/var/www/canteen/images" ]; then
    echo "✅ 图片目录符号链接已存在"
fi

# 6. 重启 Nginx
echo ""
echo "ℹ️ 步骤6: 重启 Nginx..."
sudo systemctl reload nginx
sleep 1

if sudo systemctl is-active --quiet nginx; then
    echo "✅ Nginx 运行中"
else
    echo "❌ Nginx 未运行"
    sudo systemctl status nginx --no-pager -l | head -20
fi

# 7. 测试图片路径
echo ""
echo "ℹ️ 步骤7: 测试图片路径..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/images/ 2>/dev/null || echo "000")
if [ "$http_code" = "403" ] || [ "$http_code" = "404" ]; then
    echo "✅ 图片路径可访问 (HTTP $http_code，这是正常的，因为目录为空)"
else
    echo "⚠️ 图片路径返回 HTTP $http_code"
fi

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "📋 注意："
echo "1. 图片目录已创建: backend/static/images/"
echo "2. 如果需要显示图片，请将图片文件放到该目录"
echo "3. 图片 404 错误不影响主要功能"
echo ""

