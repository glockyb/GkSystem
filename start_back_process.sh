#!/bin/bash
# 修复路径问题的启动脚本

set -e

echo "=========================================="
echo "启动后端服务 (路径修复版)"
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

# 详细路径诊断
diagnose_paths() {
    log_info "路径诊断..."
    echo "当前目录: $(pwd)"
    echo "目录内容:"
    ls -la
    echo ""
    
    # 检查backend目录
    if [ -d "backend" ]; then
        echo "backend目录内容:"
        ls -la backend/
        echo ""
        
        # 检查venv
        if [ -d "backend/venv" ]; then
            echo "venv目录内容:"
            ls -la backend/venv/
            echo ""
            
            if [ -d "backend/venv/bin" ]; then
                echo "venv/bin目录内容:"
                ls -la backend/venv/bin/
                echo ""
                
                if [ -f "backend/venv/bin/activate" ]; then
                    echo "✓ activate脚本存在"
                else
                    echo "✗ activate脚本不存在"
                    find backend/venv -name "activate" -type f
                fi
            else
                echo "✗ venv/bin目录不存在"
            fi
        else
            echo "✗ venv目录不存在"
        fi
    else
        echo "✗ backend目录不存在"
    fi
}

# 修复的Python环境设置
setup_python_env_fixed() {
    log_info "设置 Python 环境..."
    
    # 诊断当前状态
    diagnose_paths
    
    # 检查backend目录
    if [ ! -d "backend" ]; then
        log_error "错误: backend 目录不存在"
        log_info "当前目录内容:"
        ls -la
        log_info "请确保脚本在项目根目录运行"
        exit 1
    fi

    # 进入backend目录
    cd backend
    log_info "已进入backend目录: $(pwd)"
    
    # 检查Python
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Python 3 未安装"
        exit 1
    fi

    # 创建或修复虚拟环境
    if [ ! -d "venv" ]; then
        log_info "创建虚拟环境..."
        python3 -m venv venv
        if [ $? -ne 0 ]; then
            log_error "虚拟环境创建失败"
            exit 1
        fi
    else
        log_success "虚拟环境目录已存在"
    fi

    # 详细检查虚拟环境结构
    log_info "检查虚拟环境结构..."
    if [ ! -f "venv/bin/activate" ]; then
        log_error "虚拟环境不完整，activate脚本不存在"
        log_info "venv目录结构:"
        find venv -type f -name "python" -o -name "activate" 2>/dev/null
        log_info "删除并重新创建虚拟环境..."
        rm -rf venv
        python3 -m venv venv
    fi

    # 验证虚拟环境
    if [ ! -f "venv/bin/activate" ]; then
        log_error "虚拟环境创建仍然失败"
        exit 1
    fi

    log_success "虚拟环境验证成功"

    # 激活虚拟环境
    log_info "激活虚拟环境..."
    source venv/bin/activate
    
    # 检查激活是否成功
    if [ -z "$VIRTUAL_ENV" ]; then
        log_error "虚拟环境激活失败"
        exit 1
    fi
    
    log_success "虚拟环境已激活: $VIRTUAL_ENV"

    # 安装依赖
    log_info "安装Python依赖..."
    pip3 install --upgrade pip
    
    # 检查requirements.txt
    if [ -f "requirements.txt" ]; then
        log_info "找到requirements.txt，安装依赖..."
        pip3 install -r requirements.txt
    else
        log_warning "requirements.txt 不存在，安装基础依赖"
        pip3 install flask numpy pandas scikit-learn sqlalchemy pymysql redis
    fi
    
    log_success "依赖安装完成"
}

# 主函数
main_fixed() {
    log_info "开始启动流程..."
    
    setup_python_env_fixed
    
    # 最终检查
    log_info "最终环境检查:"
    echo "Python路径: $(which python3)"
    echo "Python版本: $(python3 --version)"
    echo "虚拟环境: $VIRTUAL_ENV"
    
    # 检查Flask是否可用
    if python3 -c "import flask; print('Flask版本:', flask.__version__)" 2>/dev/null; then
        log_success "Flask可用"
    else
        log_error "Flask不可用，依赖安装可能有问题"
    fi
    
    # 启动应用
    log_info "启动 Flask 应用..."
    python3 app.py
}

main_fixed