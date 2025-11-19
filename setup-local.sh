#!/bin/bash
# 本地开发环境设置脚本

set -e

echo "=========================================="
echo "本地开发环境设置脚本"
echo "=========================================="
echo ""

# 检查 Homebrew
if ! command -v brew &> /dev/null; then
    echo "❌ 错误: 未安装 Homebrew"
    echo "请先安装 Homebrew: https://brew.sh"
    exit 1
fi

echo "✅ Homebrew 已安装"
echo ""

# 检查并安装 Python 3
if ! command -v python3 &> /dev/null; then
    echo "📦 安装 Python 3..."
    brew install python3
else
    echo "✅ Python 3 已安装: $(python3 --version)"
fi

# 检查并安装 MySQL
if ! command -v mysql &> /dev/null; then
    echo "📦 安装 MySQL..."
    brew install mysql
    echo "✅ MySQL 已安装"
else
    echo "✅ MySQL 已安装: $(mysql --version | head -1)"
fi

# 检查并安装 Redis
if ! command -v redis-cli &> /dev/null; then
    echo "📦 安装 Redis..."
    brew install redis
    echo "✅ Redis 已安装"
else
    echo "✅ Redis 已安装: $(redis-cli --version)"
fi

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo "⚠️  警告: Node.js 未安装"
    echo "请手动安装 Node.js: https://nodejs.org"
else
    echo "✅ Node.js 已安装: $(node --version)"
fi

echo ""
echo "=========================================="
echo "服务启动检查"
echo "=========================================="
echo ""

# 启动 MySQL
echo "🔧 启动 MySQL 服务..."
brew services start mysql || echo "⚠️  MySQL 可能已在运行"

# 启动 Redis
echo "🔧 启动 Redis 服务..."
brew services start redis || echo "⚠️  Redis 可能已在运行"

echo ""
echo "⏳ 等待服务启动（5秒）..."
sleep 5

# 检查 MySQL
if mysql -u root -e "SELECT 1" &> /dev/null 2>&1; then
    echo "✅ MySQL 服务运行正常"
else
    echo "⚠️  MySQL 服务可能需要密码，请手动检查"
    echo "   运行: mysql -u root -p"
fi

# 检查 Redis
if redis-cli ping &> /dev/null 2>&1; then
    echo "✅ Redis 服务运行正常"
else
    echo "⚠️  Redis 服务可能未启动，请手动检查"
    echo "   运行: brew services start redis"
fi

echo ""
echo "=========================================="
echo "数据库初始化"
echo "=========================================="
echo ""

cd "$(dirname "$0")"

# 创建数据库
echo "📊 创建数据库..."
mysql -u root -e "CREATE DATABASE IF NOT EXISTS canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || {
    echo "⚠️  无法自动创建数据库，请手动创建："
    echo "   mysql -u root -p"
    echo "   CREATE DATABASE canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
}

# 导入初始化脚本
if [ -f "backend/database/init.sql" ]; then
    echo "📥 导入数据库初始化脚本..."
    mysql -u root canteen_recommendation < backend/database/init.sql 2>/dev/null || {
        echo "⚠️  无法自动导入，请手动导入："
        echo "   mysql -u root -p canteen_recommendation < backend/database/init.sql"
    }
else
    echo "⚠️  未找到数据库初始化脚本"
fi

echo ""
echo "=========================================="
echo "Python 环境设置"
echo "=========================================="
echo ""

cd backend

# 创建虚拟环境
if [ ! -d "venv" ]; then
    echo "📦 创建 Python 虚拟环境..."
    python3 -m venv venv
else
    echo "✅ 虚拟环境已存在"
fi

# 激活虚拟环境并安装依赖
echo "📦 安装 Python 依赖..."
source venv/bin/activate
pip3 install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple || pip3 install -r requirements.txt

echo ""
echo "=========================================="
echo "前端环境设置"
echo "=========================================="
echo ""

cd ../frontend

# 安装前端依赖
if [ ! -d "node_modules" ]; then
    echo "📦 安装前端依赖..."
    npm install --registry=https://registry.npmmirror.com || npm install
else
    echo "✅ 前端依赖已安装"
fi

echo ""
echo "=========================================="
echo "✅ 环境设置完成！"
echo "=========================================="
echo ""
echo "下一步："
echo ""
echo "1. 启动后端服务："
echo "   cd backend"
echo "   source venv/bin/activate"
echo "   python3 app.py"
echo ""
echo "2. 启动前端服务（新开一个终端）："
echo "   cd frontend"
echo "   npm run dev"
echo ""
echo "3. 访问系统："
echo "   前端: http://localhost:5173"
echo "   后端: http://localhost:5000"
echo ""
echo "4. 初始化数据（在 backend 目录下）："
echo "   source venv/bin/activate"
echo "   python3 data/preprocessor.py"
echo "   python3 train_model.py"
echo ""
echo "详细说明请查看: 本地运行指南.md"
echo "=========================================="

