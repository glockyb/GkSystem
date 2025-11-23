#!/bin/bash
# 修复后端依赖问题的脚本

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
log_info "修复后端依赖问题"
echo "=========================================="
echo ""

# 检查虚拟环境
if [ ! -d "venv" ]; then
    log_error "虚拟环境不存在，创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
log_info "激活虚拟环境..."
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    log_success "虚拟环境已激活"
else
    log_error "虚拟环境激活文件不存在"
    exit 1
fi

# 验证虚拟环境
log_info "验证虚拟环境..."
PYTHON_PATH=$(which python3)
log_info "Python 路径: $PYTHON_PATH"
if [[ "$PYTHON_PATH" != *"venv"* ]]; then
    log_warning "可能未在虚拟环境中，强制使用 venv/bin/python3"
    export PATH="$SCRIPT_DIR/backend/venv/bin:$PATH"
    PYTHON_PATH="$SCRIPT_DIR/backend/venv/bin/python3"
fi

# 检查 Python 版本
PYTHON_VERSION=$($PYTHON_PATH --version 2>&1)
log_info "Python 版本: $PYTHON_VERSION"

# 检查 pip
PIP_PATH=$(which pip3)
log_info "pip 路径: $PIP_PATH"
if [ -z "$PIP_PATH" ]; then
    log_error "pip3 未找到"
    exit 1
fi

# 升级 pip
log_info "升级 pip..."
$PYTHON_PATH -m pip install --upgrade pip --quiet || {
    log_error "pip 升级失败"
    exit 1
}
PIP_VERSION=$($PYTHON_PATH -m pip --version)
log_success "pip 版本: $PIP_VERSION"

# 检查关键依赖
log_info "检查关键依赖..."
REQUIRED_MODULES=("pandas" "numpy" "flask" "pymysql" "redis" "sklearn" "surprise")
MISSING_MODULES=()

for module in "${REQUIRED_MODULES[@]}"; do
    # 注意：scikit-learn 导入时使用 sklearn
    if [ "$module" = "sklearn" ]; then
        TEST_MODULE="sklearn"
    else
        TEST_MODULE="$module"
    fi
    
    if ! $PYTHON_PATH -c "import $TEST_MODULE" 2>/dev/null; then
        MISSING_MODULES+=("$module")
        log_warning "缺少模块: $module"
    else
        log_success "模块已安装: $module"
    fi
done

# 如果有缺失的模块，重新安装
if [ ${#MISSING_MODULES[@]} -gt 0 ]; then
    log_info "重新安装所有依赖..."
    
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
        HOST=$(echo $mirror | sed 's|https\?://||' | sed 's|/.*||')
        
        # 使用 python -m pip 确保在正确的环境中
        if $PYTHON_PATH -m pip install -r requirements.txt -i "$mirror" --trusted-host "$HOST" 2>&1 | tee /tmp/pip_install.log; then
            # 验证安装是否真的成功
            sleep 2
            if $PYTHON_PATH -c "import pandas" 2>/dev/null; then
                log_success "依赖安装成功（使用镜像源: $mirror）"
                INSTALLED=true
                break
            else
                log_warning "安装命令成功但模块仍不可用，尝试下一个镜像源..."
            fi
        else
            log_warning "镜像源 $mirror 安装失败，尝试下一个..."
            log_info "错误信息: tail -5 /tmp/pip_install.log"
            tail -5 /tmp/pip_install.log || true
        fi
    done
    
    if [ "$INSTALLED" = false ]; then
        log_warning "所有镜像源都失败，尝试官方 PyPI 源..."
        if $PYTHON_PATH -m pip install -r requirements.txt 2>&1 | tee /tmp/pip_install.log; then
            sleep 2
            if $PYTHON_PATH -c "import pandas" 2>/dev/null; then
                log_success "依赖安装成功（使用官方源）"
                INSTALLED=true
            fi
        fi
        
        if [ "$INSTALLED" = false ]; then
            log_error "依赖安装失败"
            log_info "查看详细错误: cat /tmp/pip_install.log"
            log_info "尝试单独安装关键模块..."
            
            # 尝试单独安装关键模块
            for module in "${MISSING_MODULES[@]}"; do
                log_info "单独安装: $module"
                if [ "$module" = "scikit-learn" ]; then
                    $PYTHON_PATH -m pip install scikit-learn -i https://pypi.tuna.tsinghua.edu.cn/simple || true
                elif [ "$module" = "surprise" ]; then
                    $PYTHON_PATH -m pip install scikit-surprise -i https://pypi.tuna.tsinghua.edu.cn/simple || true
                else
                    $PYTHON_PATH -m pip install "$module" -i https://pypi.tuna.tsinghua.edu.cn/simple || true
                fi
            done
        fi
    fi
else
    log_success "所有依赖已安装"
fi

# 再次验证
log_info "验证依赖安装..."
ALL_OK=true
for module in "${REQUIRED_MODULES[@]}"; do
    # 注意：scikit-learn 导入时使用 sklearn
    if [ "$module" = "sklearn" ]; then
        TEST_MODULE="sklearn"
    else
        TEST_MODULE="$module"
    fi
    
    if ! $PYTHON_PATH -c "import $TEST_MODULE" 2>/dev/null; then
        log_error "模块仍然缺失: $module"
        ALL_OK=false
        # 尝试查看安装位置
        log_info "检查模块安装位置..."
        $PYTHON_PATH -m pip show "$module" 2>/dev/null || log_warning "模块 $module 未找到"
    else
        log_success "模块验证通过: $module"
        # 显示模块版本
        VERSION=$($PYTHON_PATH -c "import $TEST_MODULE; print(getattr($TEST_MODULE, '__version__', 'unknown'))" 2>/dev/null || echo "unknown")
        log_info "  版本: $VERSION"
    fi
done

if [ "$ALL_OK" = true ]; then
    log_success "所有依赖验证通过！"
else
    log_error "仍有依赖缺失，请检查 requirements.txt"
    exit 1
fi

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

echo ""
log_success "修复完成！"
echo "=========================================="

