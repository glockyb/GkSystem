#!/bin/bash
# 修复 scikit-surprise Cython 兼容性问题

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
log_info "修复 scikit-surprise Cython 兼容性问题"
echo "=========================================="
echo ""

log_info "问题：Cython 3.2.1 与 scikit-surprise 不兼容"
log_info "解决：降级 Cython 到 0.29.x 版本"
echo ""

# 步骤1：进入虚拟环境
cd "$SCRIPT_DIR/backend"

if [ ! -d "../venv" ]; then
    log_error "虚拟环境不存在"
    exit 1
fi

source ../venv/bin/activate

# 步骤2：卸载当前的 Cython
log_info "步骤1: 卸载当前 Cython..."
pip uninstall -y Cython 2>/dev/null || true
log_success "已卸载"
echo ""

# 步骤3：安装兼容的 Cython 版本
log_info "步骤2: 安装兼容的 Cython 0.29.36..."
pip install Cython==0.29.36 -i https://pypi.tuna.tsinghua.edu.cn/simple || \
pip install Cython==0.29.36 -i https://mirrors.aliyun.com/pypi/simple || \
pip install Cython==0.29.36

# 验证 Cython 版本
CYTHON_VERSION=$(python -c "import Cython; print(Cython.__version__)" 2>/dev/null)
log_success "Cython 版本: $CYTHON_VERSION"
echo ""

# 步骤4：安装 scikit-surprise
log_info "步骤3: 安装 scikit-surprise（使用兼容的 Cython）..."
log_warning "这可能需要几分钟，请耐心等待..."

MIRRORS=(
    "https://pypi.tuna.tsinghua.edu.cn/simple"
    "https://mirrors.aliyun.com/pypi/simple"
    "https://pypi.douban.com/simple"
    "https://pypi.org/simple"
)

INSTALLED=false
for mirror in "${MIRRORS[@]}"; do
    log_info "尝试使用镜像源: $mirror"
    if pip install scikit-surprise -i "$mirror" --no-cache-dir 2>&1 | tee /tmp/surprise_install.log; then
        INSTALLED=true
        break
    else
        log_warning "镜像源 $mirror 失败，尝试下一个..."
        sleep 2
    fi
done

if [ "$INSTALLED" = false ]; then
    log_error "所有镜像源都失败"
    log_info "查看错误日志:"
    tail -50 /tmp/surprise_install.log
    
    # 尝试安装旧版本
    log_warning "尝试安装旧版本 scikit-surprise 1.1.3..."
    pip install scikit-surprise==1.1.3 -i https://pypi.tuna.tsinghua.edu.cn/simple --no-cache-dir || {
        log_error "安装失败"
        exit 1
    }
fi

# 验证安装
log_info "步骤4: 验证安装..."
if python -c "import surprise; print('surprise version:', surprise.__version__)" 2>/dev/null; then
    log_success "✅ scikit-surprise 安装成功！"
    python -c "import surprise; print('版本:', surprise.__version__)"
else
    log_error "scikit-surprise 安装失败"
    exit 1
fi
echo ""

echo "=========================================="
log_success "修复完成"
echo "=========================================="
echo ""
log_info "现在可以训练模型:"
echo "  cd ~/gksys/GkSystem/backend"
echo "  source ../venv/bin/activate"
echo "  python train_model.py"
echo "=========================================="

