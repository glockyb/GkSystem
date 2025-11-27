#!/bin/bash

# 重新部署前端（包含修复后的代码）
# 修复内容：
# 1. 菜品图片加载问题
# 2. 用户评分显示问题（登录后正确显示已评分的菜品）
# 3. 后台管理功能模块加载问题

set -e

# 自动检测项目路径
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo "=========================================="
echo "🔧 重新部署前端（包含修复）"
echo "=========================================="
echo "项目路径: $SCRIPT_DIR"
echo ""

# 1. 检查前端代码
echo ""
echo "ℹ️ 步骤1: 检查前端代码..."
if [ ! -d "frontend" ]; then
    echo "❌ frontend 目录不存在"
    exit 1
fi

cd frontend

# 2. 检查 Node.js 和 npm
echo ""
echo "ℹ️ 步骤2: 检查 Node.js 环境..."
if ! command -v node &> /dev/null; then
    echo "❌ Node.js 未安装"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm 未安装"
    exit 1
fi

echo "✅ Node.js 版本: $(node --version)"
echo "✅ npm 版本: $(npm --version)"

# 3. 安装/更新依赖
echo ""
echo "ℹ️ 步骤3: 检查并安装依赖..."
if [ ! -d "node_modules" ] || [ "package.json" -nt "node_modules" ]; then
    echo "安装/更新 npm 依赖..."
    npm install
    echo "✅ 依赖安装完成"
else
    echo "✅ 依赖已是最新"
fi

# 4. 重新构建前端
echo ""
echo "ℹ️ 步骤4: 重新构建前端（包含修复后的代码）..."
echo "这可能需要几分钟，请耐心等待..."
npm run build

if [ ! -d "dist" ]; then
    echo "❌ 构建失败：未找到 dist 目录"
    exit 1
fi

if [ ! -f "dist/index.html" ]; then
    echo "❌ 构建失败：未找到 index.html"
    exit 1
fi

echo "✅ 前端构建完成"

# 5. 备份旧文件
echo ""
echo "ℹ️ 步骤5: 备份旧文件..."
DEPLOY_DIR="/var/www/canteen"
if [ -d "$DEPLOY_DIR" ] && [ "$(ls -A $DEPLOY_DIR 2>/dev/null)" ]; then
    BACKUP_DIR="${DEPLOY_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "备份到: $BACKUP_DIR"
    sudo cp -r "$DEPLOY_DIR" "$BACKUP_DIR" 2>/dev/null || true
    echo "✅ 备份完成"
else
    echo "⚠️ 部署目录为空或不存在，跳过备份"
fi

# 6. 部署新文件
echo ""
echo "ℹ️ 步骤6: 部署新文件到 $DEPLOY_DIR..."
sudo mkdir -p "$DEPLOY_DIR"
sudo cp -r dist/* "$DEPLOY_DIR/"
sudo chown -R www-data:www-data "$DEPLOY_DIR"
sudo chmod -R 755 "$DEPLOY_DIR"
echo "✅ 文件已部署"

# 7. 确保图片目录存在
echo ""
echo "ℹ️ 步骤7: 确保图片目录存在..."
sudo mkdir -p /var/www/canteen/images
sudo chown -R www-data:www-data /var/www/canteen/images
sudo chmod -R 755 /var/www/canteen/images

# 检查是否有图片文件需要复制
if [ -d "../backend/static/images" ]; then
    echo "复制图片文件（如果存在）..."
    sudo cp -r ../backend/static/images/* /var/www/canteen/images/ 2>/dev/null || true
    sudo chown -R www-data:www-data /var/www/canteen/images
    echo "✅ 图片目录已准备"
fi

# 8. 检查 Nginx 配置
echo ""
echo "ℹ️ 步骤8: 检查 Nginx 配置..."
NGINX_CONF="/etc/nginx/sites-available/canteen"
if [ -f "$NGINX_CONF" ]; then
    # 检查 /images location
    if ! grep -q "location /images" "$NGINX_CONF"; then
        echo "⚠️ /images location 未配置，建议运行 修复所有问题.sh 来添加"
    else
        echo "✅ /images location 已配置"
    fi
    
    # 检查 /api location
    if ! grep -q "location /api" "$NGINX_CONF"; then
        echo "⚠️ /api location 未配置"
    else
        echo "✅ /api location 已配置"
    fi
    
    # 测试 Nginx 配置
    if sudo nginx -t 2>/dev/null; then
        echo "✅ Nginx 配置语法正确"
        sudo systemctl reload nginx
        echo "✅ Nginx 已重新加载"
    else
        echo "⚠️ Nginx 配置可能有误，请检查"
    fi
else
    echo "⚠️ Nginx 配置文件不存在: $NGINX_CONF"
fi

# 9. 重启后端服务（确保 API 正常）
echo ""
echo "ℹ️ 步骤9: 检查后端服务..."
if systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
    # 可选：重启后端以确保加载最新代码
    # sudo systemctl restart canteen-backend
    # sleep 2
else
    echo "⚠️ 后端服务未运行，请手动启动: sudo systemctl start canteen-backend"
fi

cd ..

# 10. 测试
echo ""
echo "ℹ️ 步骤10: 测试部署..."
echo "测试前端访问:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ 前端访问正常 (HTTP $HTTP_CODE)"
else
    echo "⚠️ 前端返回 HTTP $HTTP_CODE"
fi

echo ""
echo "测试 API:"
if curl -s http://localhost:5000/health 2>/dev/null | grep -q "healthy"; then
    echo "✅ API 健康检查通过"
else
    echo "⚠️ API 健康检查失败"
fi

echo ""
echo "=========================================="
echo "✅ 前端重新部署完成！"
echo "=========================================="
echo ""
echo "修复内容："
echo "1. ✅ 菜品图片加载问题 - 已修复图片路径处理"
echo "2. ✅ 用户评分显示问题 - 已修复登录后评分加载逻辑"
echo "3. ✅ 后台管理功能模块加载问题 - 已优化错误处理"
echo ""
echo "请执行以下操作："
echo "1. 清除浏览器缓存（重要！）"
echo "   - Chrome/Edge: Ctrl+Shift+Delete 或 Cmd+Shift+Delete"
echo "   - 或使用无痕模式测试"
echo ""
echo "2. 访问系统测试："
echo "   - 前端: http://your-server-ip/"
echo "   - 检查菜品图片是否正常显示"
echo "   - 登录后检查评分是否正确显示"
echo "   - 访问后台管理页面，检查功能模块是否正常加载"
echo ""
echo "3. 如果仍有问题，查看日志："
echo "   - Nginx 错误日志: sudo tail -f /var/log/nginx/canteen-error.log"
echo "   - 后端日志: sudo journalctl -u canteen-backend -f"
echo ""

