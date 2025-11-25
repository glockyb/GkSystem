#!/bin/bash

# 完全重新构建前端

set -e

echo "=========================================="
echo "🔧 完全重新构建前端"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 进入前端目录
echo ""
echo "ℹ️ 步骤1: 进入前端目录..."
cd frontend

# 2. 完全清除所有缓存和构建文件
echo ""
echo "ℹ️ 步骤2: 清除所有缓存和构建文件..."
rm -rf dist
rm -rf node_modules/.vite
rm -rf .vite
rm -rf .vite-cache
find . -name "*.log" -delete 2>/dev/null || true
echo "✅ 缓存已清除"

# 3. 检查并确保依赖完整
echo ""
echo "ℹ️ 步骤3: 检查依赖..."
if [ ! -d "node_modules" ] || [ ! -d "node_modules/vue" ]; then
    echo "安装依赖..."
    npm install
else
    echo "✅ 依赖已安装"
fi

# 4. 清除所有环境变量
echo ""
echo "ℹ️ 步骤4: 清除环境变量..."
unset VITE_API_URL
unset API_URL
export VITE_API_URL=""
export NODE_ENV=production
echo "✅ 环境变量已清除"

# 5. 检查 API 配置文件
echo ""
echo "ℹ️ 步骤5: 检查 API 配置..."
if [ -f "src/api/index.js" ]; then
    echo "✅ API 配置文件存在"
    
    # 确保使用相对路径
    if grep -q "baseURL.*'/api/v1'" src/api/index.js || grep -q "getApiBaseURL" src/api/index.js; then
        echo "✅ API 配置使用相对路径"
    else
        echo "⚠️ 检查 API 配置..."
        echo "当前配置："
        grep -A 3 "baseURL\|create\|axios" src/api/index.js | head -10
    fi
else
    echo "❌ API 配置文件不存在"
    exit 1
fi

# 6. 构建前端
echo ""
echo "ℹ️ 步骤6: 开始构建前端..."
echo "⚠️ 这可能需要几分钟，请耐心等待..."

# 确保没有环境变量干扰
env -i PATH="$PATH" HOME="$HOME" npm run build 2>&1 | tee /tmp/frontend-build-$(date +%s).log

# 7. 验证构建结果
echo ""
echo "ℹ️ 步骤7: 验证构建结果..."
if [ ! -d "dist" ]; then
    echo "❌ dist 目录不存在，构建失败"
    exit 1
fi

if [ ! -f "dist/index.html" ]; then
    echo "❌ index.html 不存在，构建失败"
    exit 1
fi

# 检查文件
file_count=$(find dist -type f | wc -l)
js_files=$(find dist/assets -name "*.js" 2>/dev/null | wc -l)
css_files=$(find dist/assets -name "*.css" 2>/dev/null | wc -l)

echo "✅ 构建完成"
echo "   总文件数: $file_count"
echo "   JS 文件: $js_files"
echo "   CSS 文件: $css_files"

if [ "$js_files" -eq 0 ]; then
    echo "❌ 没有 JS 文件，构建失败"
    exit 1
fi

# 8. 检查构建后的文件
echo ""
echo "ℹ️ 步骤8: 检查构建后的文件..."
echo "index.html 大小: $(stat -c%s dist/index.html) 字节"

# 检查 index.html 中的脚本引用
if grep -q "assets.*\.js" dist/index.html; then
    echo "✅ index.html 包含 JS 引用"
    echo "脚本引用："
    grep -o 'src="[^"]*\.js"' dist/index.html | head -3
else
    echo "❌ index.html 不包含 JS 引用"
    echo "index.html 内容："
    head -30 dist/index.html
fi

# 9. 部署前端
echo ""
echo "ℹ️ 步骤9: 部署前端..."
cd ..

# 备份现有文件
if [ -d "/var/www/canteen" ] && [ -n "$(ls -A /var/www/canteen 2>/dev/null)" ]; then
    backup_dir="/var/www/canteen.backup.$(date +%Y%m%d_%H%M%S)"
    echo "备份现有文件到: $backup_dir"
    sudo cp -r /var/www/canteen "$backup_dir" 2>/dev/null || true
fi

# 清空并部署
sudo rm -rf /var/www/canteen/*
sudo cp -r frontend/dist/* /var/www/canteen/
sudo chown -R www-data:www-data /var/www/canteen
sudo chmod -R 755 /var/www/canteen

# 验证部署
deployed_files=$(sudo find /var/www/canteen -type f | wc -l)
deployed_js=$(sudo find /var/www/canteen/assets -name "*.js" 2>/dev/null | wc -l)
echo "✅ 部署完成"
echo "   部署文件数: $deployed_files"
echo "   部署 JS 文件: $deployed_js"

# 10. 重启服务
echo ""
echo "ℹ️ 步骤10: 重启服务..."
sudo systemctl reload nginx
sleep 1

# 11. 验证
echo ""
echo "ℹ️ 步骤11: 验证部署..."
sleep 2

http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
if [ "$http_code" = "200" ]; then
    echo "✅ 前端访问正常 (HTTP 200)"
else
    echo "⚠️ 前端访问返回 HTTP $http_code"
fi

# 测试 API
api_response=$(curl -s http://localhost/api/v1/dishes/categories || echo "failed")
if echo "$api_response" | grep -q "categories\|error\|\[\]"; then
    echo "✅ API 代理正常"
else
    echo "⚠️ API 代理异常: ${api_response:0:100}"
fi

echo ""
echo "=========================================="
echo "✅ 重新构建完成"
echo "=========================================="
echo ""
echo "📋 下一步操作："
echo "1. 清除浏览器缓存 (Ctrl+Shift+Delete)"
echo "2. 强制刷新页面 (Ctrl+F5)"
echo "3. 打开浏览器控制台 (F12) 检查错误"
echo "4. 如果仍有问题，查看浏览器 Network 标签中的 API 请求"
echo ""

