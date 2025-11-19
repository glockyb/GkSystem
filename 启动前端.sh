#!/bin/bash
# 启动前端开发服务器

echo "=========================================="
echo "启动前端开发服务器"
echo "=========================================="
echo ""

cd "$(dirname "$0")/frontend"

# 检查依赖是否安装
if [ ! -d "node_modules" ]; then
    echo "📦 安装前端依赖..."
    npm install --registry=https://registry.npmmirror.com
fi

echo "🚀 启动前端开发服务器..."
echo "   访问地址: http://localhost:8080"
echo "   按 Ctrl+C 停止服务"
echo ""

# 启动前端
npm run dev

