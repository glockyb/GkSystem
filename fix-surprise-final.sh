#!/bin/bash
# 最终修复 scikit-surprise 安装问题

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

echo "=========================================="
log_info "最终修复 scikit-surprise 安装问题"
echo "=========================================="
echo ""

cd "$SCRIPT_DIR/backend"

if [ ! -d "../venv" ]; then
    log_error "虚拟环境不存在"
    exit 1
fi

source ../venv/bin/activate

# 检查当前 Cython 版本
log_info "检查当前 Cython 版本..."
CYTHON_VERSION=$(python -c "import Cython; print(Cython.__version__)" 2>/dev/null || echo "未安装")
log_info "当前 Cython 版本: $CYTHON_VERSION"
echo ""

# 方法1：尝试安装旧版本的 scikit-surprise
log_info "方法1: 尝试安装 scikit-surprise 1.1.3（更稳定的版本）..."
if pip install scikit-surprise==1.1.3 -i https://pypi.tuna.tsinghua.edu.cn/simple --no-cache-dir 2>&1 | tee /tmp/surprise_install.log; then
    if python -c "import surprise" 2>/dev/null; then
        log_success "✅ scikit-surprise 1.1.3 安装成功！"
        python -c "import surprise; print('版本:', surprise.__version__)"
        exit 0
    fi
fi

log_warning "方法1 失败，尝试方法2..."
echo ""

# 方法2：使用预编译的 wheel（如果可用）
log_info "方法2: 尝试使用预编译的 wheel 包..."
pip uninstall -y scikit-surprise 2>/dev/null || true

# 尝试安装预编译版本
if pip install scikit-surprise --only-binary :all: -i https://pypi.tuna.tsinghua.edu.cn/simple 2>&1 | tee /tmp/surprise_wheel.log; then
    if python -c "import surprise" 2>/dev/null; then
        log_success "✅ 使用预编译 wheel 安装成功！"
        python -c "import surprise; print('版本:', surprise.__version__)"
        exit 0
    fi
fi

log_warning "方法2 失败，尝试方法3..."
echo ""

# 方法3：安装更旧的版本 1.1.2
log_info "方法3: 尝试安装 scikit-surprise 1.1.2..."
pip uninstall -y scikit-surprise 2>/dev/null || true

# 确保使用旧版 Cython
pip install Cython==0.29.36 -i https://pypi.tuna.tsinghua.edu.cn/simple --force-reinstall

if pip install scikit-surprise==1.1.2 -i https://pypi.tuna.tsinghua.edu.cn/simple --no-cache-dir 2>&1 | tee /tmp/surprise_112.log; then
    if python -c "import surprise" 2>/dev/null; then
        log_success "✅ scikit-surprise 1.1.2 安装成功！"
        python -c "import surprise; print('版本:', surprise.__version__)"
        exit 0
    fi
fi

log_warning "方法3 失败，尝试方法4..."
echo ""

# 方法4：从 conda-forge 或使用替代方案
log_info "方法4: 检查是否有其他解决方案..."
log_warning "如果所有方法都失败，可能需要："
echo "  1. 升级到 Python 3.9+"
echo "  2. 使用 conda 环境"
echo "  3. 修改代码不使用 surprise（使用 scikit-learn 的替代算法）"
echo ""

# 最后尝试：安装 1.1.1
log_info "最后尝试: scikit-surprise 1.1.1..."
pip uninstall -y scikit-surprise 2>/dev/null || true
pip install Cython==0.29.33 -i https://pypi.tuna.tsinghua.edu.cn/simple --force-reinstall

if pip install scikit-surprise==1.1.1 -i https://pypi.tuna.tsinghua.edu.cn/simple --no-cache-dir 2>&1 | tee /tmp/surprise_111.log; then
    if python -c "import surprise" 2>/dev/null; then
        log_success "✅ scikit-surprise 1.1.1 安装成功！"
        python -c "import surprise; print('版本:', surprise.__version__)"
        exit 0
    fi
fi

log_error "所有安装方法都失败了"
echo ""
log_info "建议："
echo "  1. 检查 Python 版本（建议 3.9+）"
echo "  2. 考虑使用其他推荐算法（如 scikit-learn 的 NMF）"
echo "  3. 或者暂时禁用推荐功能，只使用内容推荐"
echo ""

exit 1

