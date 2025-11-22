#!/bin/bash
# 修复版启动脚本

set -e

echo "=========================================="
echo "启动后端服务 (修复版)"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}INFO: $1${NC}"; }
log_success() { echo -e "${GREEN}SUCCESS: $1${NC}"; }
log_warning() { echo -e "${YELLOW}WARNING: $1${NC}"; }
log_error() { echo -e "${RED}ERROR: $1${NC}"; }

# 修复的Python环境设置函数
setup_python_env_fixed() {
    log_info "设置 Python 环境..."
    
    # 检查backend目录
    if [ ! -d "backend" ]; then
        log_error "backend 目录不存在"
        log_info "当前目录内容:"
        ls -la
        exit 1
    fi

    cd backend

    # 检查Python
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Python 3 未安装"
        echo "运行: sudo apt update && sudo apt install python3 python3-pip python3-venv"
        exit 1
    fi

    # 确保python3-venv已安装
    if ! python3 -c "import venv" &>/dev/null; then
        log_warning "安装 python3-venv..."
        sudo apt install -y python3-venv
    fi

    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        log_info "创建虚拟环境..."
        python3 -m venv venv
    fi

    # 验证虚拟环境
    if [ ! -f "venv/bin/activate" ]; then
        log_error "虚拟环境创建失败"
        exit 1
    fi

    # 激活虚拟环境
    source venv/bin/activate
    
    # 安装依赖
    if [ -f "requirements.txt" ]; then
        pip3 install -r requirements.txt
    fi
}

# 简化的主函数
main_fixed() {
    log_info "开始启动流程..."
    setup_python_env_fixed
    
    # 启动应用
    log_info "启动 Flask 应用..."
    python3 app.py
}

main_fixed