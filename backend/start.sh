#!/bin/bash
# 后端启动脚本 (backend 目录专用)
# 从 backend 目录运行此脚本

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
log_info "启动校园食堂菜品推荐系统后端服务"
echo "=========================================="
echo ""

# 检查Python环境
if ! command -v python3 &> /dev/null; then
    log_error "未找到 Python3"
    echo "请先安装 Python 3.8+:"
    echo "  - macOS: brew install python3"
    echo "  - Ubuntu: sudo apt install python3 python3-pip python3-venv"
    exit 1
fi

log_success "Python 版本: $(python3 --version)"

# 检查依赖
if [ ! -d "venv" ]; then
    log_info "创建虚拟环境..."
    python3 -m venv venv
    log_success "虚拟环境创建成功"
else
    log_success "虚拟环境已存在"
fi

log_info "激活虚拟环境..."
source venv/bin/activate

# 检查并安装依赖
if [ ! -f "requirements.txt" ]; then
    log_warning "requirements.txt 不存在"
else
    log_info "检查 Python 依赖..."
    if ! python3 -c "import flask" >/dev/null 2>&1; then
        log_info "安装依赖..."
        pip3 install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple || pip3 install -r requirements.txt
        log_success "依赖安装完成"
    else
        log_success "Python 依赖已安装"
    fi
fi

# 检查数据库连接（可选，不强制）
log_info "检查数据库连接..."
if python3 -c "from utils.database import db; db.get_connection(); print('数据库连接成功')" 2>/dev/null; then
    log_success "数据库连接正常"
else
    log_warning "数据库连接失败，请检查配置（config.py）"
fi

# 检查Redis连接（可选）
log_info "检查 Redis 连接..."
if python3 -c "from utils.database import db; db.get_redis().ping(); print('Redis连接成功')" 2>/dev/null; then
    log_success "Redis 连接正常"
else
    log_warning "Redis 连接失败，推荐功能可能受影响（可选服务）"
fi

# 检查模型文件（可选）
if [ ! -f "models/recommender_model.pkl" ] && [ -f "train_model.py" ]; then
    log_warning "模型文件不存在，训练模型..."
    python3 train_model.py || log_warning "模型训练失败，但继续启动"
fi

echo ""
log_info "启动 Flask 服务..."
echo "   后端地址: http://localhost:5000"
echo "   健康检查: http://localhost:5000/health"
echo "   按 Ctrl+C 停止服务"
echo ""

# 启动Flask服务
python3 app.py
