#!/bin/bash

# 优化UI和图片占位符

set -e

echo "=========================================="
echo "🎨 优化UI和图片占位符"
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

# 8. 总结
echo ""
echo "=========================================="
echo "✅ UI优化完成"
echo "=========================================="
echo ""
echo "🎨 优化内容:"
echo "  ✅ 图片加载失败时显示占位符和提示"
echo "  ✅ 图片加载时显示加载动画"
echo "  ✅ 优化卡片悬停效果"
echo "  ✅ 改进空状态显示"
echo "  ✅ 优化菜品名称显示（支持多行）"
echo "  ✅ 改进整体视觉层次"
echo ""
echo "📱 访问地址:"
echo "   前端: http://119.3.232.65"
echo ""
echo "💡 如果图片仍无法加载，会显示："
echo "   - 占位图标"
echo "   - '图片加载失败' 提示"
echo "   - 优雅的渐变背景"
echo ""
echo "请清除浏览器缓存后刷新页面查看效果！"
echo ""

