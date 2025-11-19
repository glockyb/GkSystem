#!/bin/bash
# 本地开发环境启动脚本

echo "=========================================="
echo "本地开发环境启动脚本"
echo "=========================================="
echo ""

# 检查服务状态
echo "🔍 检查服务状态..."
echo ""

# 检查 MySQL
if brew services list | grep -q "mysql.*started"; then
    echo "✅ MySQL 服务运行中"
else
    echo "⚠️  MySQL 服务未启动，正在启动..."
    brew services start mysql
    sleep 3
fi

# 检查 Redis
if brew services list | grep -q "redis.*started"; then
    echo "✅ Redis 服务运行中"
else
    echo "⚠️  Redis 服务未启动，正在启动..."
    brew services start redis
    sleep 2
fi

echo ""
echo "=========================================="
echo "启动后端服务"
echo "=========================================="
echo ""

cd "$(dirname "$0")/backend"

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "❌ 错误: 虚拟环境未创建"
    echo "请先运行: bash setup-local.sh"
    exit 1
fi

# 激活虚拟环境
source venv/bin/activate

echo "🚀 启动后端服务（端口 5000）..."
echo "   按 Ctrl+C 停止服务"
echo ""

# 启动后端
python3 app.py

