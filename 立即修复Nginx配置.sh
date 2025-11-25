#!/bin/bash

# 立即修复 Nginx 配置错误

set -e

echo "=========================================="
echo "🔧 立即修复 Nginx 配置错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 恢复备份配置
echo ""
echo "ℹ️ 步骤1: 恢复备份配置..."
backup_files=$(ls -t /etc/nginx/sites-available/canteen.backup.* 2>/dev/null | head -1)
if [ -n "$backup_files" ]; then
    echo "找到备份文件: $backup_files"
    sudo cp "$backup_files" /etc/nginx/sites-available/canteen
    echo "✅ 已恢复备份配置"
else
    echo "⚠️ 未找到备份文件，查看当前配置..."
    sudo cat /etc/nginx/sites-available/canteen
fi

# 2. 查看当前配置结构
echo ""
echo "ℹ️ 步骤2: 查看当前配置结构..."
echo "location 块："
sudo grep -n "location" /etc/nginx/sites-available/canteen || echo "未找到 location 块"

# 3. 正确添加图片配置
echo ""
echo "ℹ️ 步骤3: 正确添加图片配置..."

# 读取当前配置
current_config=$(sudo cat /etc/nginx/sites-available/canteen)

# 检查是否已有图片配置（错误的嵌套配置）
if echo "$current_config" | grep -A 10 "location /api" | grep -q "location /images"; then
    echo "⚠️ 发现错误的嵌套配置，先删除..."
    # 删除错误的嵌套配置
    sudo sed -i '/location \/images/,/}/d' /etc/nginx/sites-available/canteen
fi

# 使用 awk 正确添加配置（在 location /api 块之后）
# 直接使用管道，不创建临时文件
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
' /etc/nginx/sites-available/canteen | sudo tee /etc/nginx/sites-available/canteen.new > /dev/null

sudo mv /etc/nginx/sites-available/canteen.new /etc/nginx/sites-available/canteen

# 4. 验证配置
echo ""
echo "ℹ️ 步骤4: 验证 Nginx 配置..."
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "✅ Nginx 配置正确"
    echo ""
    echo "配置内容（图片部分）："
    sudo grep -A 5 "location /images" /etc/nginx/sites-available/canteen
else
    echo "❌ Nginx 配置仍有错误"
    echo "错误信息："
    sudo nginx -t
    echo ""
    echo "当前配置："
    sudo cat /etc/nginx/sites-available/canteen
    exit 1
fi

# 5. 创建图片目录
echo ""
echo "ℹ️ 步骤5: 创建图片目录..."
mkdir -p backend/static/images
if [ ! -L "/var/www/canteen/images" ] && [ ! -d "/var/www/canteen/images" ]; then
    sudo ln -s "$(pwd)/backend/static/images" /var/www/canteen/images
    echo "✅ 图片目录符号链接已创建"
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

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "📋 关于 422 错误（JWT 认证）："
echo "1. 清除浏览器 localStorage 中的 token"
echo "2. 重新登录获取新 token"
echo "3. 查看后端日志: sudo journalctl -u canteen-backend -f"
echo ""

