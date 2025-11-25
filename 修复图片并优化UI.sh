#!/bin/bash

# 修复图片加载并优化UI

set -e

echo "=========================================="
echo "🔧 修复图片加载并优化UI"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查前端代码
echo ""
echo "ℹ️ 步骤1: 检查前端代码..."
if [ ! -d "frontend" ]; then
    echo "❌ frontend 目录不存在"
    exit 1
fi
echo "✅ frontend 目录存在"

# 2. 清理旧的构建
echo ""
echo "ℹ️ 步骤2: 清理旧的构建..."
cd frontend
if [ -d "dist" ]; then
    rm -rf dist
    echo "✅ 已删除旧的 dist 目录"
fi

# 3. 检查环境变量
echo ""
echo "ℹ️ 步骤3: 检查环境变量..."
if [ -f ".env" ]; then
    echo "⚠️ 发现 .env 文件，确保 VITE_API_URL 未设置..."
    # 移除 VITE_API_URL 设置
    sed -i '/^VITE_API_URL=/d' .env 2>/dev/null || true
    echo "✅ 已清理 VITE_API_URL"
fi
unset VITE_API_URL
export VITE_API_URL=""

# 4. 安装依赖（如果需要）
echo ""
echo "ℹ️ 步骤4: 检查依赖..."
if [ ! -d "node_modules" ]; then
    echo "安装 npm 依赖..."
    npm install
else
    echo "✅ node_modules 已存在"
fi

# 5. 构建前端
echo ""
echo "ℹ️ 步骤5: 构建前端..."
npm run build

if [ ! -d "dist" ] || [ ! -f "dist/index.html" ]; then
    echo "❌ 构建失败"
    exit 1
fi
echo "✅ 前端构建成功"

# 6. 部署到 Nginx
echo ""
echo "ℹ️ 步骤6: 部署到 Nginx..."
sudo rm -rf /var/www/canteen/*
sudo cp -r dist/* /var/www/canteen/
sudo chown -R www-data:www-data /var/www/canteen
sudo chmod -R 755 /var/www/canteen
echo "✅ 文件已部署到 /var/www/canteen"

# 7. 验证 Nginx 配置
echo ""
echo "ℹ️ 步骤7: 验证 Nginx 配置..."
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "✅ Nginx 配置正确"
    sudo systemctl reload nginx
else
    echo "❌ Nginx 配置有错误"
    sudo nginx -t
    exit 1
fi

# 8. 验证部署
echo ""
echo "ℹ️ 步骤8: 验证部署..."
sleep 2
if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200"; then
    echo "✅ 前端页面可访问"
else
    echo "⚠️ 前端页面可能无法访问"
fi

# 9. 测试图片访问
echo ""
echo "ℹ️ 步骤9: 测试图片访问..."
img_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/images/hongshaorou.jpg" 2>&1)
if [ "$img_code" = "200" ]; then
    echo "✅ 图片可以正常访问 (HTTP $img_code)"
else
    echo "⚠️ 图片访问返回 HTTP $img_code"
fi

# 10. 总结
echo ""
echo "=========================================="
echo "✅ 修复和优化完成"
echo "=========================================="
echo ""
echo "📱 访问地址:"
echo "   前端: http://119.3.232.65"
echo "   图片: http://119.3.232.65/images/hongshaorou.jpg"
echo ""
echo "💡 如果前端仍有问题，请："
echo "   1. 清除浏览器缓存 (Ctrl+Shift+R 或 Cmd+Shift+R)"
echo "   2. 清除浏览器 localStorage (F12 → Application → Local Storage)"
echo "   3. 检查浏览器控制台 (F12 → Console)"
echo ""
echo "🎨 UI 优化内容:"
echo "   ✅ 改进卡片悬停效果"
echo "   ✅ 优化图片显示和加载"
echo "   ✅ 美化标签页样式"
echo "   ✅ 优化搜索区域样式"
echo "   ✅ 改进价格显示效果"
echo "   ✅ 添加渐变和阴影效果"
echo ""

