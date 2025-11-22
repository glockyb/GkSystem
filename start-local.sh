#!/bin/bash
# 本地开发环境启动脚本 (macOS)
# 用于在 macOS 上启动本地开发环境

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
log_info "本地开发环境启动脚本 (macOS)"
echo "=========================================="
echo ""

# 检查 Homebrew
if ! command -v brew &> /dev/null; then
    log_error "Homebrew 未安装"
    echo "请先安装 Homebrew: https://brew.sh"
    exit 1
fi

# 检查服务状态
log_info "检查服务状态..."
echo ""

# 检查 MySQL
if brew services list 2>/dev/null | grep -q "mysql.*started"; then
    log_success "MySQL 服务运行中"
else
    log_warning "MySQL 服务未启动，正在启动..."
    brew services start mysql || {
        log_error "无法启动 MySQL 服务"
        echo "请手动启动: brew services start mysql"
        exit 1
    }
    sleep 3
    log_success "MySQL 服务已启动"
fi

# 检查 Redis
if brew services list 2>/dev/null | grep -q "redis.*started"; then
    log_success "Redis 服务运行中"
else
    log_warning "Redis 服务未启动，正在启动..."
    brew services start redis || {
        log_warning "Redis 启动失败，但继续执行（可选服务）"
    }
    sleep 2
    log_success "Redis 服务已启动"
fi

echo ""
echo "=========================================="
log_info "启动后端服务"
echo "=========================================="
echo ""

# 进入项目目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/backend"

# 检查虚拟环境
if [ ! -d "venv" ]; then
    log_error "虚拟环境未创建"
    echo "请先运行: bash setup-local.sh"
    exit 1
fi

# 激活虚拟环境
source venv/bin/activate
log_success "虚拟环境已激活"

# 检查 Python 依赖
if ! python3 -c "import flask" >/dev/null 2>&1; then
    log_warning "Python 依赖可能未安装，尝试安装..."
    pip3 install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple || pip3 install -r requirements.txt
fi

log_info "启动后端服务（端口 5000）..."
echo "   健康检查: http://localhost:5000/health"
echo "   按 Ctrl+C 停止服务"
echo ""

# 启动后端
python3 app.py

