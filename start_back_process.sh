#!/bin/bash
# 健壮版启动脚本

set -e

echo "=========================================="
echo "启动后端服务 (健壮版)"
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

# 安装系统依赖
install_system_deps() {
    log_info "检查系统依赖..."
    
    if ! command -v python3 >/dev/null 2>&1; then
        log_info "安装 Python3..."
        sudo apt update && sudo apt install -y python3
    fi
    
    if ! python3 -c "import venv" &>/dev/null; then
        log_info "安装 python3-venv..."
        sudo apt install -y python3-venv
    fi
    
    if ! command -v pip3 >/dev/null 2>&1; then
        log_info "安装 python3-pip..."
        sudo apt install -y python3-pip
    fi
}

# 创建虚拟环境（多方法尝试）
create_venv() {
    local venv_dir="$1"
    
    log_info "尝试创建虚拟环境: $venv_dir"
    
    # 方法1: 使用 venv
    log_info "方法1: 使用 python3 -m venv"
    if python3 -m venv "$venv_dir" 2>/dev/null; then
        log_success "虚拟环境创建成功 (方法1)"
        return 0
    fi
    
    # 方法2: 使用 virtualenv
    log_info "方法2: 使用 virtualenv"
    if command -v virtualenv >/dev/null 2>&1 || pip3 install --user virtualenv; then
        if virtualenv "$venv_dir"; then
            log_success "虚拟环境创建成功 (方法2)"
            return 0
        fi
    fi
    
    # 方法3: 手动创建（最后的手段）
    log_info "方法3: 手动创建虚拟环境结构"
    mkdir -p "$venv_dir/bin" "$venv_dir/lib" "$venv_dir/include"
    python_path=$(which python3)
    cat > "$venv_dir/bin/activate" << 'EOF'
#!/bin/bash
export VIRTUAL_ENV="__VENV_DIR__"
export PATH="$VIRTUAL_ENV/bin:$PATH"
unset PYTHONHOME
EOF
    sed -i "s|__VENV_DIR__|$(pwd)/$venv_dir|" "$venv_dir/bin/activate"
    ln -sf "$python_path" "$venv_dir/bin/python"
    ln -sf "$python_path" "$venv_dir/bin/python3"
    
    log_warning "使用手动创建的虚拟环境（有限功能）"
    return 0
}

# 设置Python环境
setup_python_env_robust() {
    log_info "设置 Python 环境..."
    
    if [ ! -d "backend" ]; then
        log_error "backend 目录不存在"
        exit 1
    fi

    cd backend

    install_system_deps

    # 删除可能损坏的虚拟环境
    if [ -d "venv" ] && [ ! -f "venv/bin/activate" ]; then
        log_warning "删除损坏的虚拟环境"
        rm -rf venv
    fi

    # 创建或使用现有虚拟环境
    if [ ! -d "venv" ]; then
        create_venv "venv"
    else
        log_success "虚拟环境已存在"
    fi

    # 激活虚拟环境
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
        log_success "虚拟环境已激活"
    else
        log_warning "无法激活虚拟环境，使用系统Python"
    fi

    # 安装依赖
    log_info "安装Python依赖..."
    pip3 install --upgrade pip
    
    if [ -f "requirements.txt" ]; then
        pip3 install -r requirements.txt
    else
        log_warning "requirements.txt 不存在，安装基础依赖"
        pip3 install flask numpy pandas scikit-learn sqlalchemy pymysql redis
    fi
}

# 主函数
main_robust() {
    log_info "开始启动流程..."
    
    setup_python_env_robust
    
    # 检查Python环境
    log_info "Python环境检查:"
    python3 -c "import sys; print('Python路径:', sys.executable)"
    python3 -c "import flask; print('Flask版本:', flask.__version__)" 2>/dev/null || log_warning "Flask未正确安装"
    
    # 启动应用
    log_info "启动 Flask 应用..."
    python3 app.py
}

main_robust