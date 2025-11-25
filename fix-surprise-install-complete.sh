#!/bin/bash
# 完整修复 scikit-surprise 安装问题

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

if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================="
log_info "完整修复 scikit-surprise 安装问题"
echo "=========================================="
echo ""

# 步骤1：安装所有编译依赖
log_info "步骤1: 安装编译依赖..."
$SUDO apt-get update

# 安装基础编译工具
log_info "安装基础编译工具..."
$SUDO apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    pkg-config

# 安装 Python 开发头文件
log_info "安装 Python 开发头文件..."
$SUDO apt-get install -y \
    python3-dev \
    python3.9-dev \
    python3-pip \
    python3-setuptools \
    python3-wheel

log_success "编译依赖已安装"
echo ""

# 步骤2：进入虚拟环境并升级工具
log_info "步骤2: 准备虚拟环境..."
cd "$SCRIPT_DIR/backend"

if [ ! -d "../venv" ]; then
    log_error "虚拟环境不存在"
    exit 1
fi

source ../venv/bin/activate

# 升级 pip 和构建工具
log_info "升级 pip 和构建工具..."
pip install --upgrade pip setuptools wheel

# 安装 Cython（scikit-surprise 编译需要）
log_info "安装 Cython..."
pip install Cython -i https://pypi.tuna.tsinghua.edu.cn/simple || \
pip install Cython -i https://mirrors.aliyun.com/pypi/simple || \
pip install Cython

log_success "Cython 已安装"
echo ""

# 步骤3：确保 numpy 已安装（scikit-surprise 依赖）
log_info "步骤3: 检查 numpy..."
if ! python -c "import numpy" 2>/dev/null; then
    log_warning "numpy 未安装，安装 numpy..."
    pip install numpy==1.24.3 -i https://pypi.tuna.tsinghua.edu.cn/simple || \
    pip install numpy==1.24.3
else
    log_success "numpy 已安装"
fi
echo ""

# 步骤4：尝试安装 scikit-surprise
log_info "步骤4: 安装 scikit-surprise..."
log_warning "这可能需要几分钟，请耐心等待..."

MIRRORS=(
    "https://pypi.tuna.tsinghua.edu.cn/simple"
    "https://mirrors.aliyun.com/pypi/simple"
    "https://pypi.douban.com/simple"
    "https://pypi.org/simple"
)

INSTALLED=false
INSTALL_LOG="/tmp/surprise_install_$(date +%Y%m%d_%H%M%S).log"

for mirror in "${MIRRORS[@]}"; do
    log_info "尝试使用镜像源: $mirror"
    
    # 尝试安装，保存详细日志
    if pip install scikit-surprise -i "$mirror" --no-cache-dir 2>&1 | tee "$INSTALL_LOG"; then
        INSTALLED=true
        break
    else
        log_warning "镜像源 $mirror 安装失败，尝试下一个..."
        sleep 2
    fi
done

if [ "$INSTALLED" = false ]; then
    log_error "所有镜像源都失败"
    log_info "查看详细错误日志:"
    tail -50 "$INSTALL_LOG"
    
    # 尝试从源码安装
    log_warning "尝试从 GitHub 源码安装..."
    pip install git+https://github.com/NicolasHug/surprise.git || {
        log_error "从源码安装也失败"
        log_info "请查看错误日志: $INSTALL_LOG"
        exit 1
    }
fi

# 验证安装
log_info "验证安装..."
if python -c "import surprise; print('surprise version:', surprise.__version__)" 2>/dev/null; then
    log_success "✅ scikit-surprise 安装成功！"
    python -c "import surprise; print('版本:', surprise.__version__)"
else
    log_error "scikit-surprise 安装失败"
    log_info "查看日志: $INSTALL_LOG"
    exit 1
fi
echo ""

# 步骤5：检查其他依赖
log_info "步骤5: 检查其他依赖..."
REQUIRED_PACKAGES=("pandas" "numpy" "scikit-learn" "scipy" "joblib")
MISSING_PACKAGES=()

for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! python -c "import ${package//-/_}" 2>/dev/null; then
        MISSING_PACKAGES+=("$package")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    log_warning "缺少依赖: ${MISSING_PACKAGES[*]}"
    log_info "安装缺少的依赖..."
    pip install "${MISSING_PACKAGES[@]}" -i https://pypi.tuna.tsinghua.edu.cn/simple
else
    log_success "所有依赖已安装"
fi
echo ""

# 步骤6：测试训练模型
log_info "步骤6: 测试导入推荐模块..."
if python -c "from models.recommender import recommender; print('推荐模块导入成功')" 2>/dev/null; then
    log_success "推荐模块可以正常导入"
else
    log_warning "推荐模块导入失败（可能需要训练模型）"
fi
echo ""

echo "=========================================="
log_success "修复完成"
echo "=========================================="
echo ""
log_info "现在可以尝试训练模型:"
echo "  cd ~/gksys/GkSystem/backend"
echo "  source ../venv/bin/activate"
echo "  python train_model.py"
echo "=========================================="

