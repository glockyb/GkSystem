#!/bin/bash

# 修复前端代码并重新部署

set -e

echo "=========================================="
echo "🔧 修复前端代码并重新部署"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查前端目录
echo ""
echo "ℹ️ 步骤1: 检查前端目录..."
if [ ! -d "frontend" ]; then
    echo "❌ frontend 目录不存在"
    exit 1
fi
echo "✅ frontend 目录存在"

# 2. 清理旧的构建文件
echo ""
echo "ℹ️ 步骤2: 清理旧的构建文件..."
cd frontend
if [ -d "dist" ]; then
    rm -rf dist
    echo "✅ 已删除旧的 dist 目录"
fi
if [ -d "node_modules" ]; then
    # 检查是否是跨平台问题
    if [ -f "node_modules/.package-lock.json" ] || [ -d "node_modules/@esbuild" ]; then
        echo "⚠️ 检测到可能的跨平台 node_modules，清理..."
        rm -rf node_modules
    fi
fi

# 3. 安装依赖（如果需要）
echo ""
echo "ℹ️ 步骤3: 检查并安装依赖..."
if [ ! -d "node_modules" ]; then
    echo "安装 npm 依赖..."
    npm install
else
    echo "✅ node_modules 已存在"
fi

# 4. 检查环境变量
echo ""
echo "ℹ️ 步骤4: 检查环境变量..."
if [ -f ".env" ]; then
    echo "⚠️ 发现 .env 文件，检查内容:"
    cat .env | grep -v "PASSWORD\|SECRET\|KEY" || true
    echo ""
    echo "⚠️ 为了确保使用相对路径，将备份并清空 VITE_API_URL..."
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    # 移除 VITE_API_URL 设置
    sed -i '/^VITE_API_URL=/d' .env 2>/dev/null || true
    echo "✅ 已清理 VITE_API_URL 环境变量"
else
    echo "✅ 未发现 .env 文件"
fi

# 5. 构建前端
echo ""
echo "ℹ️ 步骤5: 构建前端..."
unset VITE_API_URL
export VITE_API_URL=""
npm run build

if [ ! -d "dist" ] || [ ! -f "dist/index.html" ]; then
    echo "❌ 构建失败，dist 目录或 index.html 不存在"
    exit 1
fi
echo "✅ 前端构建成功"

# 6. 检查构建产物
echo ""
echo "ℹ️ 步骤6: 检查构建产物..."
echo "dist 目录内容:"
ls -lh dist/ | head -10
echo ""
echo "检查 index.html:"
head -20 dist/index.html | grep -E "script|link" || true

# 7. 部署到 Nginx
echo ""
echo "ℹ️ 步骤7: 部署到 Nginx..."
sudo rm -rf /var/www/canteen/*
sudo cp -r dist/* /var/www/canteen/
sudo chown -R www-data:www-data /var/www/canteen
sudo chmod -R 755 /var/www/canteen
echo "✅ 文件已部署到 /var/www/canteen"

# 8. 检查 Nginx 配置
echo ""
echo "ℹ️ 步骤8: 检查 Nginx 配置..."
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "✅ Nginx 配置正确"
    sudo systemctl reload nginx
else
    echo "❌ Nginx 配置有错误"
    sudo nginx -t
    exit 1
fi

# 9. 验证部署
echo ""
echo "ℹ️ 步骤9: 验证部署..."
sleep 2
if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200"; then
    echo "✅ 前端页面可访问"
else
    echo "⚠️ 前端页面可能无法访问，HTTP 状态码:"
    curl -s -o /dev/null -w "%{http_code}" http://localhost/
fi

# 10. 检查后端服务
echo ""
echo "ℹ️ 步骤10: 检查后端服务..."
if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "⚠️ 后端服务未运行，启动中..."
    sudo systemctl start canteen-backend
    sleep 3
fi

# 11. 测试 API
echo ""
echo "ℹ️ 步骤11: 测试 API..."
echo "测试分类 API:"
categories_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/v1/dishes/categories)
if [ "$categories_status" = "200" ]; then
    echo "✅ 分类 API 正常 (HTTP $categories_status)"
else
    echo "❌ 分类 API 返回 HTTP $categories_status"
fi

echo "测试菜品列表 API:"
dishes_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5000/api/v1/dishes?page=1&per_page=5")
if [ "$dishes_status" = "200" ]; then
    echo "✅ 菜品列表 API 正常 (HTTP $dishes_status)"
else
    echo "❌ 菜品列表 API 返回 HTTP $dishes_status"
fi

echo ""
echo "=========================================="
echo "✅ 前端修复和部署完成"
echo "=========================================="
echo ""
echo "📋 访问地址:"
echo "  前端: http://119.3.232.65"
echo "  后端 API: http://119.3.232.65:5000"
echo ""
echo "📋 如果仍有问题，请："
echo "1. 清除浏览器缓存 (Ctrl+Shift+R 或 Cmd+Shift+R)"
echo "2. 清除浏览器 localStorage (F12 → Application → Local Storage → 清除)"
echo "3. 查看浏览器控制台错误 (F12 → Console)"
echo "4. 查看后端日志: sudo journalctl -u canteen-backend -f"
echo "5. 查看 Nginx 日志: sudo tail -f /var/log/nginx/error.log"
echo ""

