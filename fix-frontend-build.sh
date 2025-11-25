#!/bin/bash

# 完整修复前端构建问题

set -e

echo "=========================================="
echo "🔧 完整修复前端构建"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 进入前端目录
echo ""
echo "ℹ️ 步骤1: 进入前端目录..."
cd frontend

# 2. 清除所有构建缓存
echo ""
echo "ℹ️ 步骤2: 清除构建缓存..."
rm -rf dist
rm -rf node_modules/.vite
rm -rf .vite

# 3. 检查并安装依赖
echo ""
echo "ℹ️ 步骤3: 检查依赖..."
if [ ! -d "node_modules" ] || [ -z "$(ls -A node_modules 2>/dev/null)" ]; then
    echo "⚠️ node_modules 不存在或为空，安装依赖..."
    npm install
else
    echo "✅ node_modules 存在，检查关键依赖..."
    if [ ! -d "node_modules/vue" ]; then
        echo "⚠️ Vue 未安装，重新安装依赖..."
        npm install
    fi
fi

# 4. 清除环境变量
echo ""
echo "ℹ️ 步骤4: 清除环境变量..."
unset VITE_API_URL
export VITE_API_URL=""

# 5. 检查关键文件
echo ""
echo "ℹ️ 步骤5: 检查关键文件..."
if [ ! -f "src/main.js" ]; then
    echo "❌ src/main.js 不存在"
    exit 1
fi
if [ ! -f "src/App.vue" ]; then
    echo "❌ src/App.vue 不存在"
    exit 1
fi
if [ ! -f "index.html" ]; then
    echo "❌ index.html 不存在"
    exit 1
fi
echo "✅ 关键文件存在"

# 6. 构建前端
echo ""
echo "ℹ️ 步骤6: 开始构建前端..."
echo "⚠️ 这可能需要几分钟，请耐心等待..."

# 设置构建环境
export NODE_ENV=production
unset VITE_API_URL

# 执行构建
npm run build 2>&1 | tee /tmp/frontend-build.log

# 7. 检查构建结果
echo ""
echo "ℹ️ 步骤7: 检查构建结果..."
if [ ! -d "dist" ]; then
    echo "❌ dist 目录不存在，构建失败"
    echo "构建日志："
    cat /tmp/frontend-build.log
    exit 1
fi

# 检查文件数量和大小
file_count=$(find dist -type f | wc -l)
index_size=$(stat -c%s dist/index.html 2>/dev/null || echo "0")

echo "   文件数量: $file_count"
echo "   index.html 大小: $index_size 字节"

if [ "$file_count" -lt 5 ]; then
    echo "⚠️ 文件数量过少，构建可能不完整"
    echo "构建的文件列表："
    find dist -type f | head -20
fi

if [ "$index_size" -lt 1000 ]; then
    echo "⚠️ index.html 文件过小，可能构建失败"
    echo "index.html 内容："
    head -20 dist/index.html
fi

# 检查是否有JS文件
js_files=$(find dist -name "*.js" | wc -l)
css_files=$(find dist -name "*.css" | wc -l)

echo "   JS 文件: $js_files"
echo "   CSS 文件: $css_files"

if [ "$js_files" -eq 0 ]; then
    echo "❌ 没有 JS 文件，构建失败"
    echo "构建日志："
    cat /tmp/frontend-build.log | tail -50
    exit 1
fi

# 8. 部署前端
echo ""
echo "ℹ️ 步骤8: 部署前端文件..."
cd ..

# 备份现有文件
if [ -d "/var/www/canteen" ] && [ -n "$(ls -A /var/www/canteen 2>/dev/null)" ]; then
    echo "备份现有文件..."
    sudo rm -rf /var/www/canteen.backup.*
    backup_dir="/var/www/canteen.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp -r /var/www/canteen "$backup_dir" 2>/dev/null || true
fi

# 清空并复制新文件
sudo rm -rf /var/www/canteen/*
sudo cp -r frontend/dist/* /var/www/canteen/
sudo chown -R www-data:www-data /var/www/canteen
sudo chmod -R 755 /var/www/canteen

# 验证部署
deployed_files=$(sudo find /var/www/canteen -type f | wc -l)
echo "✅ 部署完成，文件数量: $deployed_files"

# 9. 重启服务
echo ""
echo "ℹ️ 步骤9: 重启服务..."
sudo systemctl restart canteen-backend
sleep 2
sudo systemctl reload nginx
sleep 1

# 10. 验证
echo ""
echo "ℹ️ 步骤10: 验证部署..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
if [ "$http_code" = "200" ]; then
    echo "✅ 前端访问正常 (HTTP 200)"
    
    # 检查页面内容
    page_content=$(curl -s http://localhost/ | head -c 500)
    if echo "$page_content" | grep -q "app\|vue\|script"; then
        echo "✅ 页面内容正常"
    else
        echo "⚠️ 页面内容可能异常"
        echo "页面开头内容："
        echo "$page_content"
    fi
else
    echo "⚠️ 前端访问返回 HTTP $http_code"
fi

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "📱 访问地址："
echo "   http://$(hostname -I | awk '{print $1}')"
echo ""
echo "📋 如果仍有问题："
echo "1. 清除浏览器缓存 (Ctrl+Shift+Delete)"
echo "2. 强制刷新 (Ctrl+F5)"
echo "3. 查看浏览器控制台 (F12)"
echo "4. 查看 Nginx 日志: sudo tail -f /var/log/nginx/error.log"
echo ""
