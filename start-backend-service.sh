#!/bin/bash
# 启动后端服务脚本（生产环境）
# 用于在云主机上启动后端服务

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/backend"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 检查虚拟环境
if [ ! -d "venv" ]; then
    log_error "虚拟环境不存在"
    echo "请先运行: python3 -m venv venv"
    exit 1
fi

# 激活虚拟环境
source venv/bin/activate

# 检查依赖
if ! python3 -c "import flask" >/dev/null 2>&1; then
    log_warning "依赖未安装，正在安装..."
    pip3 install -r requirements.txt
fi

# 检查 MySQL
if ! systemctl is-active mysql >/dev/null 2>&1 && ! systemctl is-active mysqld >/dev/null 2>&1; then
    log_warning "MySQL 未运行，正在启动..."
    sudo systemctl start mysql 2>/dev/null || sudo systemctl start mysqld 2>/dev/null || {
        log_error "无法启动 MySQL"
        exit 1
    }
    sleep 3
fi

# 检查 Redis
if ! systemctl is-active redis-server >/dev/null 2>&1 && ! systemctl is-active redis >/dev/null 2>&1; then
    log_warning "Redis 未运行，正在启动..."
    sudo systemctl start redis-server 2>/dev/null || sudo systemctl start redis 2>/dev/null || {
        log_warning "Redis 启动失败，但继续执行（可选服务）"
    }
fi

log_info "启动后端服务..."
log_info "后端地址: http://0.0.0.0:5000"
log_info "健康检查: http://localhost:5000/health"
log_info "按 Ctrl+C 停止服务"
echo ""

# 启动服务（生产环境建议使用 gunicorn）
if command -v gunicorn >/dev/null 2>&1; then
    log_info "使用 Gunicorn 启动（生产模式）"
    gunicorn -w 4 -b 0.0.0.0:5000 --timeout 120 app:app
else
    log_info "使用 Flask 开发服务器启动"
    log_warning "生产环境建议安装 Gunicorn: pip install gunicorn"
    python3 app.py
fi

