#!/bin/bash
# 启动后端服务的完整脚本

set -e

echo "=========================================="
echo "启动后端服务"
echo "=========================================="
echo ""

cd "$(dirname "$0")"

# 检查 MySQL
echo "🔍 检查 MySQL..."
if ! command -v mysql &> /dev/null; then
    echo "❌ MySQL 未安装"
    echo "请先安装 MySQL: brew install mysql"
    echo "然后运行: brew services start mysql"
    exit 1
fi

# 检查 MySQL 服务
if ! brew services list 2>/dev/null | grep -q "mysql.*started"; then
    echo "⚠️  MySQL 服务未启动，正在启动..."
    brew services start mysql || {
        echo "❌ 无法启动 MySQL 服务"
        echo "请手动启动: brew services start mysql"
        exit 1
    }
    echo "⏳ 等待 MySQL 启动（5秒）..."
    sleep 5
else
    echo "✅ MySQL 服务运行中"
fi

# 检查 Redis（可选）
echo "🔍 检查 Redis..."
if command -v redis-cli &> /dev/null; then
    if ! brew services list 2>/dev/null | grep -q "redis.*started"; then
        echo "⚠️  Redis 服务未启动，正在启动..."
        brew services start redis || echo "⚠️  Redis 启动失败，继续..."
        sleep 2
    else
        echo "✅ Redis 服务运行中"
    fi
else
    echo "⚠️  Redis 未安装（可选，推荐功能需要）"
fi

# 检查数据库
echo "🔍 检查数据库..."
mysql -u root -e "USE canteen_recommendation;" 2>/dev/null || {
    echo "⚠️  数据库不存在，正在创建..."
    mysql -u root << EOF
CREATE DATABASE IF NOT EXISTS canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF
    
    echo "📥 导入数据库初始化脚本..."
    if [ -f "backend/database/init.sql" ]; then
        mysql -u root canteen_recommendation < backend/database/init.sql || {
            echo "⚠️  数据库初始化失败，请手动导入"
        }
    fi
}

echo "✅ 数据库检查完成"

# 检查 Python 虚拟环境
echo "🔍 检查 Python 环境..."
cd backend

if [ ! -d "venv" ]; then
    echo "📦 创建 Python 虚拟环境..."
    python3 -m venv venv || {
        echo "❌ 无法创建虚拟环境"
        echo "请检查 Python 3 是否安装: python3 --version"
        exit 1
    }
fi

# 激活虚拟环境
source venv/bin/activate

# 检查依赖
if [ ! -f "venv/bin/flask" ]; then
    echo "📦 安装 Python 依赖..."
    pip3 install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple || pip3 install -r requirements.txt
fi

echo "✅ Python 环境检查完成"

# 检查数据和模型
echo "🔍 检查数据和模型..."
if [ ! -f "models/recommender_model.pkl" ] || [ ! -d "data/processed" ]; then
    echo "📊 初始化数据..."
    python3 data/preprocessor.py || echo "⚠️  数据预处理失败，继续..."
    
    echo "🤖 训练推荐模型..."
    python3 train_model.py || echo "⚠️  模型训练失败，继续..."
fi

echo ""
echo "=========================================="
echo "🚀 启动后端服务..."
echo "=========================================="
echo ""
echo "后端将在 http://localhost:5000 启动"
echo "健康检查: http://localhost:5000/health"
echo ""
echo "按 Ctrl+C 停止服务"
echo ""

# 启动后端
python3 app.py

