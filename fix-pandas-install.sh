#!/bin/bash
# 快速修复 pandas 安装问题

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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/backend"

echo "=========================================="
log_info "修复 pandas 安装问题"
echo "=========================================="
echo ""

# 检查虚拟环境
if [ ! -d "venv" ]; then
    log_error "虚拟环境不存在"
    exit 1
fi

# 使用虚拟环境的 Python
VENV_PYTHON="$SCRIPT_DIR/backend/venv/bin/python3"
VENV_PIP="$SCRIPT_DIR/backend/venv/bin/pip3"

# 检查 Python 版本
PYTHON_VERSION=$($VENV_PYTHON --version 2>&1)
log_info "Python 版本: $PYTHON_VERSION"

# 升级 pip
log_info "升级 pip..."
$VENV_PIP install --upgrade pip

# 安装 pandas（注意：版本号必须用引号包裹）
log_info "安装 pandas（版本 >=2.0.0,<2.1.0）..."
log_warning "注意：版本号必须用引号包裹，避免 shell 解释 < 为重定向"

# 尝试多个镜像源
MIRRORS=(
    "https://pypi.tuna.tsinghua.edu.cn/simple"
    "https://mirrors.aliyun.com/pypi/simple"
    "https://pypi.douban.com/simple"
    "https://pypi.org/simple"
)

INSTALLED=false
for mirror in "${MIRRORS[@]}"; do
    log_info "尝试使用镜像源: $mirror"
    HOST=$(echo "$mirror" | sed 's|https\?://||' | sed 's|/.*||')
    
    # 关键：版本号必须用引号包裹
    if $VENV_PIP install "pandas>=2.0.0,<2.1.0" -i "$mirror" --trusted-host "$HOST" 2>&1 | tee /tmp/pandas_install.log; then
        sleep 2
        if $VENV_PYTHON -c "import pandas; print('pandas OK:', pandas.__version__)" 2>/dev/null; then
            log_success "pandas 安装成功（使用镜像源: $mirror）"
            INSTALLED=true
            break
        else
            log_warning "安装命令成功但模块不可用，尝试下一个..."
        fi
    else
        log_warning "镜像源 $mirror 安装失败，尝试下一个..."
    fi
done

if [ "$INSTALLED" = false ]; then
    log_warning "所有镜像源都失败，尝试官方源..."
    if $VENV_PIP install "pandas>=2.0.0,<2.1.0" 2>&1 | tee /tmp/pandas_install.log; then
        sleep 2
        if $VENV_PYTHON -c "import pandas" 2>/dev/null; then
            log_success "pandas 安装成功（使用官方源）"
            INSTALLED=true
        fi
    fi
fi

# 验证
if [ "$INSTALLED" = true ]; then
    log_success "pandas 安装成功！"
    $VENV_PYTHON -c "import pandas; print('版本:', pandas.__version__)"
else
    log_error "pandas 安装失败"
    log_info "查看错误日志: cat /tmp/pandas_install.log"
    exit 1
fi

echo ""
log_success "修复完成！"
echo "=========================================="

