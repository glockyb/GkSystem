#!/bin/bash
# 安装 Python 开发头文件

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 检查是否为 root
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
    log_warning "建议使用 sudo 运行此脚本"
fi

echo "=========================================="
log_info "安装 Python 开发头文件"
echo "=========================================="
echo ""

# 检测 Python 版本
if command -v python3.9 >/dev/null 2>&1; then
    PYTHON_CMD="python3.9"
    PYTHON_VERSION="3.9"
elif command -v python3.10 >/dev/null 2>&1; then
    PYTHON_CMD="python3.10"
    PYTHON_VERSION="3.10"
elif command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
else
    log_error "未找到 Python 3"
    exit 1
fi

log_info "检测到 Python 版本: $PYTHON_VERSION"

# 检测系统类型
if command -v apt-get >/dev/null 2>&1; then
    log_info "检测到 Ubuntu/Debian 系统"
    
    # 更新包列表
    log_info "更新包列表..."
    $SUDO apt-get update
    
    # 安装 Python 开发头文件
    log_info "安装 Python 开发头文件..."
    if $SUDO apt-get install -y "python${PYTHON_VERSION}-dev" 2>&1; then
        log_success "Python ${PYTHON_VERSION}-dev 安装成功"
    elif $SUDO apt-get install -y python3-dev 2>&1; then
        log_success "python3-dev 安装成功"
    else
        log_warning "特定版本开发包安装失败，尝试通用包..."
        $SUDO apt-get install -y python-dev || log_warning "python-dev 安装失败"
    fi
    
    # 安装编译工具
    log_info "安装编译工具..."
    $SUDO apt-get install -y build-essential gcc g++ make || log_warning "编译工具安装可能失败"
    
elif command -v yum >/dev/null 2>&1; then
    log_info "检测到 CentOS/RHEL 系统"
    
    # 安装 Python 开发头文件
    log_info "安装 Python 开发头文件..."
    MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
    
    if $SUDO yum install -y "python${MAJOR}${MINOR}-devel" 2>&1; then
        log_success "Python ${PYTHON_VERSION}-devel 安装成功"
    elif $SUDO yum install -y python3-devel 2>&1; then
        log_success "python3-devel 安装成功"
    else
        log_warning "特定版本开发包安装失败，尝试通用包..."
        $SUDO yum install -y python-devel || log_warning "python-devel 安装失败"
    fi
    
    # 安装编译工具
    log_info "安装编译工具..."
    $SUDO yum groupinstall -y "Development Tools" || \
    $SUDO yum install -y gcc gcc-c++ make || log_warning "编译工具安装可能失败"
    
else
    log_error "未找到包管理器（apt-get 或 yum）"
    exit 1
fi

# 验证安装
log_info "验证 Python.h 头文件..."
PYTHON_INCLUDE=$(python3 -c "import sysconfig; print(sysconfig.get_path('include'))" 2>/dev/null || echo "")

if [ -n "$PYTHON_INCLUDE" ] && [ -f "$PYTHON_INCLUDE/Python.h" ]; then
    log_success "Python.h 头文件已找到: $PYTHON_INCLUDE/Python.h"
elif [ -f "/usr/include/python${PYTHON_VERSION}/Python.h" ]; then
    log_success "Python.h 头文件已找到: /usr/include/python${PYTHON_VERSION}/Python.h"
elif [ -f "/usr/include/python3/Python.h" ]; then
    log_success "Python.h 头文件已找到: /usr/include/python3/Python.h"
else
    log_warning "Python.h 头文件未找到，但可能已安装"
    log_info "尝试查找 Python.h..."
    find /usr/include -name "Python.h" 2>/dev/null | head -1 || log_warning "未找到 Python.h"
fi

echo ""
log_success "安装完成！"
echo "=========================================="
echo ""
log_info "现在可以尝试安装 scikit-surprise："
echo "  cd ~/GkSystem/backend"
echo "  source venv/bin/activate"
echo "  pip3 install scikit-surprise -i https://pypi.tuna.tsinghua.edu.cn/simple"
echo ""

