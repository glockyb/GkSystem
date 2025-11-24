#!/bin/bash
# 手动修复后端依赖（更详细的方法）

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
log_info "手动修复后端依赖（详细模式）"
echo "=========================================="
echo ""

# 检查虚拟环境
if [ ! -d "venv" ]; then
    log_error "虚拟环境不存在，创建虚拟环境..."
    python3 -m venv venv
    log_success "虚拟环境已创建"
fi

# 使用绝对路径的 Python
VENV_PYTHON="$SCRIPT_DIR/backend/venv/bin/python3"
VENV_PIP="$SCRIPT_DIR/backend/venv/bin/pip3"

if [ ! -f "$VENV_PYTHON" ]; then
    log_error "虚拟环境 Python 不存在: $VENV_PYTHON"
    exit 1
fi

log_info "使用 Python: $VENV_PYTHON"
log_info "使用 pip: $VENV_PIP"

# 检查 Python 版本
PYTHON_VERSION=$($VENV_PYTHON --version)
log_info "Python 版本: $PYTHON_VERSION"

# 升级 pip
log_info "升级 pip..."
$VENV_PYTHON -m pip install --upgrade pip

# 显示 pip 版本
PIP_VERSION=$($VENV_PIP --version)
log_success "pip 版本: $PIP_VERSION"

# 清理旧的安装
log_info "清理可能损坏的安装..."
$VENV_PIP uninstall -y pandas numpy flask pymysql redis scikit-learn surprise 2>/dev/null || true

# 逐个安装关键模块
log_info "逐个安装关键模块..."

# 0. 检查并安装系统依赖（Python 开发头文件）
log_info "0. 检查系统依赖..."
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# 检查 Python.h
if ! python3 -c "import sysconfig; import os; assert os.path.exists(os.path.join(sysconfig.get_path('include'), 'Python.h'))" 2>/dev/null; then
    log_warning "Python 开发头文件未找到，尝试安装..."
    if command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get update
        $SUDO apt-get install -y python3-dev build-essential gcc g++ || log_warning "系统依赖安装可能失败"
    elif command -v yum >/dev/null 2>&1; then
        $SUDO yum install -y python3-devel gcc gcc-c++ make || log_warning "系统依赖安装可能失败"
    fi
fi

# 1. 安装基础依赖
log_info "1. 安装 setuptools 和 wheel..."
$VENV_PIP install --upgrade setuptools wheel -i https://pypi.tuna.tsinghua.edu.cn/simple || \
$VENV_PIP install --upgrade setuptools wheel

# 2. 安装 numpy（pandas 的依赖）
log_info "2. 安装 numpy..."
$VENV_PIP install "numpy==1.24.3" -i https://pypi.tuna.tsinghua.edu.cn/simple || \
$VENV_PIP install "numpy>=1.24.0" -i https://pypi.tuna.tsinghua.edu.cn/simple || \
$VENV_PIP install numpy

# 验证 numpy
if $VENV_PYTHON -c "import numpy; print('numpy OK:', numpy.__version__)" 2>/dev/null; then
    log_success "numpy 安装成功"
else
    log_error "numpy 安装失败"
    exit 1
fi

# 3. 安装 pandas
log_info "3. 安装 pandas..."
$VENV_PIP install "pandas>=2.0.0,<2.1.0" -i https://pypi.tuna.tsinghua.edu.cn/simple || \
$VENV_PIP install "pandas>=2.0.0" -i https://mirrors.aliyun.com/pypi/simple || \
$VENV_PIP install pandas

# 验证 pandas
if $VENV_PYTHON -c "import pandas; print('pandas OK:', pandas.__version__)" 2>/dev/null; then
    log_success "pandas 安装成功"
else
    log_error "pandas 安装失败"
    exit 1
fi

# 4. 安装 Flask 相关
log_info "4. 安装 Flask 相关..."
$VENV_PIP install "Flask==2.3.3" "Flask-CORS==4.0.0" "Flask-JWT-Extended==4.5.3" \
    -i https://pypi.tuna.tsinghua.edu.cn/simple || \
$VENV_PIP install Flask Flask-CORS Flask-JWT-Extended

# 验证 Flask
if $VENV_PYTHON -c "import flask; print('flask OK:', flask.__version__)" 2>/dev/null; then
    log_success "Flask 安装成功"
else
    log_error "Flask 安装失败"
    exit 1
fi

# 5. 安装数据库相关
log_info "5. 安装数据库相关..."
$VENV_PIP install "pymysql==1.1.0" "redis==5.0.1" \
    -i https://pypi.tuna.tsinghua.edu.cn/simple || \
$VENV_PIP install pymysql redis

# 验证
if $VENV_PYTHON -c "import pymysql; import redis; print('数据库模块 OK')" 2>/dev/null; then
    log_success "数据库模块安装成功"
else
    log_error "数据库模块安装失败"
    exit 1
fi

# 6. 安装 scikit-learn
log_info "6. 安装 scikit-learn..."
$VENV_PIP install "scikit-learn==1.3.0" -i https://pypi.tuna.tsinghua.edu.cn/simple || \
$VENV_PIP install scikit-learn

# 验证（注意导入名是 sklearn）
if $VENV_PYTHON -c "import sklearn; print('scikit-learn OK:', sklearn.__version__)" 2>/dev/null; then
    log_success "scikit-learn 安装成功"
else
    log_error "scikit-learn 安装失败"
    exit 1
fi

# 7. 安装 surprise（注意包名是 scikit-surprise）
log_info "7. 安装 surprise..."
log_warning "surprise 可能需要特殊处理，先安装构建依赖..."

# 先安装构建依赖
$VENV_PIP install Cython numpy

# 尝试安装预编译包
if $VENV_PIP install scikit-surprise --only-binary :all: -i https://pypi.tuna.tsinghua.edu.cn/simple 2>/dev/null; then
    if $VENV_PYTHON -c "import surprise" 2>/dev/null; then
        log_success "surprise 安装成功（预编译包）"
    else
        log_warning "预编译包安装失败，尝试其他方法..."
        # 运行专门的修复脚本
        if [ -f "$SCRIPT_DIR/fix-surprise-install.sh" ]; then
            log_info "运行 surprise 安装修复脚本..."
            bash "$SCRIPT_DIR/fix-surprise-install.sh"
        else
            log_warning "跳过 surprise，使用替代实现"
        fi
    fi
else
    log_warning "预编译包不可用，运行修复脚本..."
    if [ -f "$SCRIPT_DIR/fix-surprise-install.sh" ]; then
        bash "$SCRIPT_DIR/fix-surprise-install.sh"
    else
        log_warning "跳过 surprise，使用替代实现"
    fi
fi

# 验证
if $VENV_PYTHON -c "import surprise" 2>/dev/null; then
    log_success "surprise 可用"
else
    log_warning "surprise 不可用，但继续（推荐功能可能受限）"
fi

# 8. 安装其他依赖
log_info "8. 安装其他依赖..."
$VENV_PIP install scipy joblib nltk python-dotenv werkzeug bcrypt \
    -i https://pypi.tuna.tsinghua.edu.cn/simple || \
$VENV_PIP install scipy joblib nltk python-dotenv werkzeug bcrypt

# 最终验证
log_info "最终验证所有模块..."
ALL_OK=true
MODULES=("pandas" "numpy" "flask" "pymysql" "redis" "sklearn" "surprise")

for module in "${MODULES[@]}"; do
    if $VENV_PYTHON -c "import $module" 2>/dev/null; then
        log_success "✓ $module"
    else
        log_error "✗ $module"
        ALL_OK=false
    fi
done

if [ "$ALL_OK" = true ]; then
    log_success "所有依赖安装成功！"
    
    echo ""
    log_info "重启后端服务..."
    sudo systemctl restart canteen-backend
    sleep 3
    
    if sudo systemctl is-active canteen-backend >/dev/null 2>&1; then
        log_success "后端服务已重启"
    else
        log_warning "后端服务可能未正常启动"
        log_info "查看日志: sudo journalctl -u canteen-backend -n 50"
    fi
else
    log_error "仍有依赖缺失"
    exit 1
fi

echo ""
log_success "修复完成！"
echo "=========================================="

