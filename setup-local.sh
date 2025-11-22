#!/bin/bash
# 本地开发环境设置脚本 (macOS)
# 用于在 macOS 上配置完整的开发环境

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "=========================================="
log_info "本地开发环境设置脚本 (macOS)"
echo "=========================================="
echo ""

# 检查 Homebrew
if ! command -v brew &> /dev/null; then
    log_error "未安装 Homebrew"
    echo "请先安装 Homebrew: https://brew.sh"
    exit 1
fi

log_success "Homebrew 已安装"
echo ""

# 检查并安装 Python 3
if ! command -v python3 &> /dev/null; then
    log_info "安装 Python 3..."
    brew install python3
    log_success "Python 3 已安装"
else
    log_success "Python 3 已安装: $(python3 --version)"
fi

# 检查并安装 MySQL
if ! command -v mysql &> /dev/null; then
    log_info "安装 MySQL..."
    brew install mysql
    log_success "MySQL 已安装"
else
    log_success "MySQL 已安装: $(mysql --version | head -1)"
fi

# 检查并安装 Redis
if ! command -v redis-cli &> /dev/null; then
    log_info "安装 Redis..."
    brew install redis
    log_success "Redis 已安装"
else
    log_success "Redis 已安装: $(redis-cli --version)"
fi

# 检查 Node.js
if ! command -v node &> /dev/null; then
    log_warning "Node.js 未安装"
    echo "请手动安装 Node.js: https://nodejs.org"
else
    log_success "Node.js 已安装: $(node --version)"
fi

echo ""
echo "=========================================="
echo "服务启动检查"
echo "=========================================="
echo ""

# 启动 MySQL
log_info "启动 MySQL 服务..."
brew services start mysql 2>/dev/null || log_warning "MySQL 可能已在运行"
sleep 2

# 启动 Redis
log_info "启动 Redis 服务..."
brew services start redis 2>/dev/null || log_warning "Redis 可能已在运行"
sleep 2

log_info "等待服务启动（3秒）..."
sleep 3

# 检查 MySQL
if mysql -u root -e "SELECT 1" &> /dev/null 2>&1; then
    log_success "MySQL 服务运行正常"
else
    log_warning "MySQL 服务可能需要密码，请手动检查"
    echo "   运行: mysql -u root -p"
fi

# 检查 Redis
if redis-cli ping &> /dev/null 2>&1; then
    log_success "Redis 服务运行正常"
else
    log_warning "Redis 服务可能未启动，请手动检查"
    echo "   运行: brew services start redis"
fi

echo ""
echo "=========================================="
echo "数据库初始化"
echo "=========================================="
echo ""

cd "$(dirname "$0")"

# 创建数据库
log_info "创建数据库..."
if mysql -u root -e "CREATE DATABASE IF NOT EXISTS canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null; then
    log_success "数据库创建成功"
else
    log_warning "无法自动创建数据库，请手动创建："
    echo "   mysql -u root -p"
    echo "   CREATE DATABASE canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
fi

# 导入初始化脚本
if [ -f "backend/database/init.sql" ]; then
    log_info "导入数据库初始化脚本..."
    if mysql -u root canteen_recommendation < backend/database/init.sql 2>/dev/null; then
        log_success "数据库初始化完成"
    else
        log_warning "无法自动导入，请手动导入："
        echo "   mysql -u root -p canteen_recommendation < backend/database/init.sql"
    fi
else
    log_warning "未找到数据库初始化脚本: backend/database/init.sql"
fi

echo ""
echo "=========================================="
echo "Python 环境设置"
echo "=========================================="
echo ""

cd backend

# 创建虚拟环境
if [ ! -d "venv" ]; then
    log_info "创建 Python 虚拟环境..."
    python3 -m venv venv
    log_success "虚拟环境创建成功"
else
    log_success "虚拟环境已存在"
fi

# 激活虚拟环境并安装依赖
log_info "安装 Python 依赖..."
source venv/bin/activate
if pip3 install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple; then
    log_success "Python 依赖安装完成"
else
    log_warning "使用镜像安装失败，尝试官方源..."
    pip3 install -r requirements.txt || {
        log_error "依赖安装失败"
        exit 1
    }
    log_success "Python 依赖安装完成"
fi

echo ""
echo "=========================================="
echo "前端环境设置"
echo "=========================================="
echo ""

cd ../frontend

# 安装前端依赖
if [ ! -d "node_modules" ]; then
    log_info "安装前端依赖..."
    if npm install --registry=https://registry.npmmirror.com; then
        log_success "前端依赖安装完成"
    else
        log_warning "使用镜像安装失败，尝试官方源..."
        npm install || {
            log_error "前端依赖安装失败"
            exit 1
        }
        log_success "前端依赖安装完成"
    fi
else
    log_success "前端依赖已安装"
fi

echo ""
echo "=========================================="
log_success "环境设置完成！"
echo "=========================================="
echo ""
echo "📋 下一步："
echo ""
echo "1. 启动后端服务："
echo "   ./启动后端.sh"
echo "   或手动启动:"
echo "   cd backend"
echo "   source venv/bin/activate"
echo "   python3 app.py"
echo ""
echo "2. 启动前端服务（新开一个终端）："
echo "   ./启动前端.sh"
echo "   或手动启动:"
echo "   cd frontend"
echo "   npm run dev"
echo ""
echo "3. 访问系统："
echo "   前端: http://localhost:8080 (Vite 代理到 5173)"
echo "   后端: http://localhost:5000"
echo "   健康检查: http://localhost:5000/health"
echo ""
echo "4. 初始化数据（可选，在 backend 目录下）："
echo "   cd backend"
echo "   source venv/bin/activate"
echo "   python3 data/preprocessor.py"
echo "   python3 train_model.py"
echo ""
echo "💡 提示："
echo "   - 使用 ./启动前端.sh 和 ./启动后端.sh 可以自动处理依赖"
echo "   - 详细说明请查看: 本地运行指南.md"
echo "=========================================="

