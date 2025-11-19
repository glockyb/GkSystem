#!/bin/bash
# 一键安装所有需要的环境

set -e

echo "=========================================="
echo "一键安装项目运行环境"
echo "=========================================="
echo ""

cd "$(dirname "$0")"

# 检查 Homebrew
if ! command -v brew &> /dev/null; then
    echo "❌ 错误: 未安装 Homebrew"
    echo "请先安装 Homebrew: https://brew.sh"
    exit 1
fi

echo "✅ Homebrew 已安装"
echo ""

# 步骤1: 安装 MySQL
echo "=========================================="
echo "步骤1: 安装 MySQL"
echo "=========================================="

if brew list mysql &> /dev/null 2>&1; then
    echo "✅ MySQL 已安装"
else
    echo "📦 正在安装 MySQL（这可能需要几分钟）..."
    echo "   如果卡住，请按 Ctrl+C 取消，然后手动运行: brew install mysql"
    brew install mysql || {
        echo "❌ MySQL 安装失败"
        echo "可能的原因："
        echo "1. 网络问题 - 请检查网络连接"
        echo "2. Xcode 命令行工具问题 - 运行: xcode-select --install"
        echo "3. 磁盘空间不足"
        exit 1
    }
    echo "✅ MySQL 安装完成"
fi

# 启动 MySQL 服务
echo "🔧 启动 MySQL 服务..."
brew services start mysql || brew services restart mysql
echo "⏳ 等待 MySQL 启动（5秒）..."
sleep 5

# 步骤2: 安装 Redis
echo ""
echo "=========================================="
echo "步骤2: 安装 Redis"
echo "=========================================="

if brew list redis &> /dev/null 2>&1; then
    echo "✅ Redis 已安装"
else
    echo "📦 正在安装 Redis..."
    brew install redis || {
        echo "⚠️  Redis 安装失败，继续（Redis 是可选的）"
    }
fi

# 启动 Redis 服务
if command -v redis-server &> /dev/null; then
    echo "🔧 启动 Redis 服务..."
    brew services start redis || brew services restart redis
    sleep 2
fi

# 步骤3: 创建数据库
echo ""
echo "=========================================="
echo "步骤3: 创建数据库"
echo "=========================================="

echo "📊 创建数据库..."
mysql -u root << 'EOF' 2>/dev/null || {
    echo "⚠️  无法自动创建数据库（可能需要密码）"
    echo "   请手动运行以下命令："
    echo "   mysql -u root -p"
    echo "   CREATE DATABASE canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    echo "   exit;"
}
CREATE DATABASE IF NOT EXISTS canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF

# 导入初始化脚本
if [ -f "backend/database/init.sql" ]; then
    echo "📥 导入数据库初始化脚本..."
    mysql -u root canteen_recommendation < backend/database/init.sql 2>/dev/null || {
        echo "⚠️  无法自动导入数据库（可能需要密码）"
        echo "   请手动运行："
        echo "   mysql -u root -p canteen_recommendation < backend/database/init.sql"
    }
else
    echo "⚠️  未找到数据库初始化脚本: backend/database/init.sql"
fi

# 步骤4: 设置 Python 环境
echo ""
echo "=========================================="
echo "步骤4: 设置 Python 环境"
echo "=========================================="

cd backend

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: Python 3 未安装"
    echo "请安装 Python 3: brew install python3"
    exit 1
fi

echo "✅ Python 3 已安装: $(python3 --version)"

# 创建虚拟环境
if [ ! -d "venv" ]; then
    echo "📦 创建 Python 虚拟环境..."
    python3 -m venv venv || {
        echo "❌ 无法创建虚拟环境"
        exit 1
    }
else
    echo "✅ 虚拟环境已存在"
fi

# 激活虚拟环境
source venv/bin/activate

# 安装依赖
echo "📦 安装 Python 依赖（使用国内镜像）..."
pip3 install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple || pip3 install --upgrade pip

pip3 install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple || {
    echo "⚠️  使用国内镜像失败，尝试使用默认源..."
    pip3 install -r requirements.txt || {
        echo "❌ Python 依赖安装失败"
        exit 1
    }
}

echo "✅ Python 依赖安装完成"

# 步骤5: 初始化数据
echo ""
echo "=========================================="
echo "步骤5: 初始化数据"
echo "=========================================="

echo "📊 执行数据预处理..."
python3 data/preprocessor.py || {
    echo "⚠️  数据预处理失败，但继续..."
}

echo "🤖 训练推荐模型..."
python3 train_model.py || {
    echo "⚠️  模型训练失败，但继续..."
}

echo ""
echo "=========================================="
echo "✅ 环境安装完成！"
echo "=========================================="
echo ""
echo "下一步："
echo ""
echo "1. 启动后端服务："
echo "   cd backend"
echo "   source venv/bin/activate"
echo "   python3 app.py"
echo ""
echo "2. 或者使用启动脚本："
echo "   bash 启动后端.sh"
echo ""
echo "3. 访问系统："
echo "   前端: http://localhost:8080"
echo "   后端: http://localhost:5000"
echo ""
echo "=========================================="

