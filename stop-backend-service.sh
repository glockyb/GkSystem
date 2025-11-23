#!/bin/bash
# 停止后端服务脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }

# 检查是否使用 systemd 服务
if systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_info "停止 systemd 服务..."
    sudo systemctl stop canteen-backend
    log_success "后端服务已停止"
else
    log_info "查找 Python 进程..."
    PID=$(ps aux | grep '[p]ython.*app.py' | awk '{print $2}')
    if [ -n "$PID" ]; then
        kill $PID
        log_success "后端进程已停止 (PID: $PID)"
    else
        log_info "未找到运行中的后端进程"
    fi
fi

