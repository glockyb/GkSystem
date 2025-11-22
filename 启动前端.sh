#!/bin/bash
# 启动前端开发服务器 (优化版)
# 适用于本地开发和测试

set -e  # 遇到错误立即退出

echo "=========================================="
echo "启动前端开发服务器"
echo "=========================================="
echo ""

# 获取脚本目录并切换到前端目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/frontend"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}INFO: $1${NC}"; }
log_success() { echo -e "${GREEN}SUCCESS: $1${NC}"; }
log_warning() { echo -e "${YELLOW}WARNING: $1${NC}"; }
log_error() { echo -e "${RED}ERROR: $1${NC}"; }

# 检查前端目录是否存在
check_frontend_dir() {
    if [ ! -d "$SCRIPT_DIR/frontend" ]; then
        log_error "frontend 目录不存在: $SCRIPT_DIR/frontend"
        echo "请确保前端代码位于正确的目录结构中"
        exit 1
    fi
}

# 检查 Node.js 环境
check_node_env() {
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js 未安装"
        echo "请先安装 Node.js:"
        echo "Ubuntu/Debian: sudo apt install nodejs npm"
        echo "或访问: https://nodejs.org/"
        exit 1
    fi

    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm 未安装"
        echo "请先安装 npm:"
        echo "Ubuntu/Debian: sudo apt install npm"
        exit 1
    fi

    log_success "Node.js 版本: $(node --version)"
    log_success "npm 版本: $(npm --version)"
}

# 检查并安装依赖
install_dependencies() {
    if [ ! -d "node_modules" ] || [ ! -f "package-lock.json" ]; then
        log_info "📦 安装前端依赖..."
        
        # 检查 package.json 是否存在
        if [ ! -f "package.json" ]; then
            log_error "package.json 不存在"
            echo "请确保当前目录包含前端项目"
            exit 1
        fi
        
        # 使用国内镜像安装
        if npm install --registry=https://registry.npmmirror.com; then
            log_success "依赖安装完成"
        else
            log_warning "国内镜像安装失败，尝试官方源..."
            if npm install; then
                log_success "依赖安装完成"
            else
                log_error "依赖安装失败"
                echo "请检查网络连接或 package.json 配置"
                exit 1
            fi
        fi
    else
        log_info "依赖已安装，检查更新..."
        npm update --registry=https://registry.npmmirror.com || true
    fi
}

# 检查 package.json 中的脚本
check_npm_scripts() {
    if [ ! -f "package.json" ]; then
        log_error "package.json 不存在"
        exit 1
    fi

    # 检查是否有 dev 脚本
    if ! npm run | grep -q " dev "; then
        log_warning "package.json 中没有找到 'dev' 脚本"
        echo "可用的脚本:"
        npm run
        echo ""
        echo "请选择要运行的脚本（输入脚本名）: "
        read -r script_name
        if [ -z "$script_name" ]; then
            script_name="start"  # 默认尝试 start
        fi
        SCRIPT_TO_RUN="$script_name"
    else
        SCRIPT_TO_RUN="dev"
    fi
}

# 显示启动信息
show_startup_info() {
    echo ""
    log_info "🚀 启动前端开发服务器..."
    echo "   项目目录: $(pwd)"
    echo "   启动命令: npm run $SCRIPT_TO_RUN"
    echo "   访问地址: http://localhost:8080"
    echo "   按 Ctrl+C 停止服务"
    echo ""
    echo "=========================================="
}

# 主函数
main() {
    log_info "开始启动前端服务..."
    
    check_frontend_dir
    check_node_env
    install_dependencies
    check_npm_scripts
    show_startup_info
    
    # 启动前端服务
    log_info "执行: npm run $SCRIPT_TO_RUN"
    npm run "$SCRIPT_TO_RUN"
}

# 设置信号处理
trap 'echo ""; log_info "前端服务已停止"; exit 0' INT TERM

# 运行主函数
main "$@"