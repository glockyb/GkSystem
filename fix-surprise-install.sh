#!/bin/bash
# 修复 scikit-surprise 安装问题的脚本

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
log_info "修复 scikit-surprise 安装问题"
echo "=========================================="
echo ""

VENV_PYTHON="$SCRIPT_DIR/backend/venv/bin/python3"
VENV_PIP="$SCRIPT_DIR/backend/venv/bin/pip3"

if [ ! -f "$VENV_PYTHON" ]; then
    log_error "虚拟环境 Python 不存在: $VENV_PYTHON"
    exit 1
fi

# 检查 Python 版本
PYTHON_VERSION=$($VENV_PYTHON --version)
log_info "Python 版本: $PYTHON_VERSION"

# 方法1：先安装系统构建依赖
log_info "方法1: 安装系统构建依赖..."

# 检查并安装 Python 开发头文件
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

PYTHON_VERSION=$($VENV_PYTHON --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

log_info "检测到 Python 版本: $PYTHON_VERSION"

# 安装 Python 开发头文件
if command -v apt-get >/dev/null 2>&1; then
    log_info "安装 Python 开发头文件（Ubuntu/Debian）..."
    $SUDO apt-get update
    $SUDO apt-get install -y "python${PYTHON_MAJOR}.${PYTHON_MINOR}-dev" || \
    $SUDO apt-get install -y python3-dev || \
    $SUDO apt-get install -y python-dev
    
    # 安装编译工具
    $SUDO apt-get install -y build-essential gcc g++ || true
elif command -v yum >/dev/null 2>&1; then
    log_info "安装 Python 开发头文件（CentOS/RHEL）..."
    $SUDO yum install -y "python${PYTHON_MAJOR}${PYTHON_MINOR}-devel" || \
    $SUDO yum install -y python3-devel || \
    $SUDO yum install -y python-devel
    
    # 安装编译工具
    $SUDO yum groupinstall -y "Development Tools" || true
fi

# 安装 Python 构建依赖
log_info "安装 Python 构建依赖..."
$VENV_PIP install --upgrade pip setuptools wheel
$VENV_PIP install Cython numpy

# 方法2：尝试安装预编译的 wheel 包
log_info "方法2: 尝试安装预编译的 wheel 包..."

# 尝试多个版本
SURPRISE_VERSIONS=("1.1.3" "1.1.2" "1.1.1" "1.1.0" "latest")

INSTALLED=false
for version in "${SURPRISE_VERSIONS[@]}"; do
    if [ "$version" = "latest" ]; then
        log_info "尝试安装最新版本..."
        if $VENV_PIP install scikit-surprise --only-binary :all: -i https://pypi.tuna.tsinghua.edu.cn/simple 2>&1 | tee /tmp/surprise_install.log; then
            if $VENV_PYTHON -c "import surprise" 2>/dev/null; then
                log_success "scikit-surprise 安装成功（最新版本）"
                INSTALLED=true
                break
            fi
        fi
    else
        log_info "尝试安装版本: $version"
        if $VENV_PIP install "scikit-surprise==$version" --only-binary :all: -i https://pypi.tuna.tsinghua.edu.cn/simple 2>&1 | tee /tmp/surprise_install.log; then
            if $VENV_PYTHON -c "import surprise" 2>/dev/null; then
                log_success "scikit-surprise 安装成功（版本 $version）"
                INSTALLED=true
                break
            fi
        fi
    fi
done

# 方法3：如果预编译包失败，尝试从源码编译（使用旧版 Cython）
if [ "$INSTALLED" = false ]; then
    log_warning "预编译包安装失败，尝试从源码编译..."
    
    # 安装旧版 Cython（更兼容）
    log_info "安装兼容的 Cython 版本..."
    $VENV_PIP install "Cython<3.0" || $VENV_PIP install "Cython==0.29.36"
    
    # 尝试安装 scikit-surprise
    log_info "从源码编译 scikit-surprise..."
    if $VENV_PIP install scikit-surprise --no-binary scikit-surprise -i https://pypi.tuna.tsinghua.edu.cn/simple 2>&1 | tee /tmp/surprise_install.log; then
        if $VENV_PYTHON -c "import surprise" 2>/dev/null; then
            log_success "scikit-surprise 从源码编译成功"
            INSTALLED=true
        fi
    fi
fi

# 方法4：如果还是失败，使用替代方案
if [ "$INSTALLED" = false ]; then
    log_warning "scikit-surprise 安装失败，使用替代方案..."
    log_info "可以使用 Surprise 库的替代实现，或者跳过协同过滤功能"
    
    # 创建一个简单的替代模块
    cat > "$SCRIPT_DIR/backend/models/surprise_stub.py" <<'EOF'
"""
Surprise 库的简单替代实现（仅用于开发测试）
如果 scikit-surprise 安装失败，可以使用这个替代模块
"""
import warnings

warnings.warn("使用 Surprise 替代实现，推荐算法功能可能受限")

class SVD:
    """简单的 SVD 替代实现"""
    def __init__(self, n_factors=50, lr_all=0.005, n_epochs=100, verbose=False):
        self.n_factors = n_factors
        self.lr_all = lr_all
        self.n_epochs = n_epochs
        self.verbose = verbose
        self.trainset = None
        self.model = None
    
    def fit(self, trainset):
        """训练模型（占位符）"""
        self.trainset = trainset
        warnings.warn("SVD 模型未正确训练，使用替代实现")
        return self
    
    def predict(self, uid, iid, r_ui=None, clip=True, verbose=False):
        """预测评分（占位符）"""
        class Prediction:
            def __init__(self):
                self.est = 3.0  # 默认评分
        return Prediction()

# 导出
__all__ = ['SVD']
EOF
    
    log_warning "已创建替代模块，但推荐功能可能受限"
    log_info "建议：升级到 Python 3.9+ 以获得完整的 scikit-surprise 支持"
fi

# 验证安装
log_info "验证安装..."
if $VENV_PYTHON -c "import surprise; print('surprise OK')" 2>/dev/null; then
    log_success "surprise 模块可用"
    VERSION=$($VENV_PYTHON -c "import surprise; print(getattr(surprise, '__version__', 'unknown'))" 2>/dev/null || echo "unknown")
    log_info "版本: $VERSION"
elif [ -f "$SCRIPT_DIR/backend/models/surprise_stub.py" ]; then
    log_warning "使用替代模块，功能受限"
else
    log_error "surprise 模块不可用"
    exit 1
fi

echo ""
log_success "修复完成！"
echo "=========================================="

