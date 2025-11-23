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
source venv/bin/activate

# 升级 pip
log_info "升级 pip..."
pip3 install --upgrade pip

# 检查关键依赖
log_info "检查关键依赖..."
REQUIRED_MODULES=("pandas" "numpy" "flask" "pymysql" "redis" "scikit-learn" "surprise")
MISSING_MODULES=()

for module in "${REQUIRED_MODULES[@]}"; do
    if ! python3 -c "import $module" 2>/dev/null; then
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
        if pip3 install -r requirements.txt -i "$mirror" --trusted-host "$HOST" 2>&1 | tee /tmp/pip_install.log; then
            log_success "依赖安装成功（使用镜像源: $mirror）"
            INSTALLED=true
            break
        else
            log_warning "镜像源 $mirror 安装失败，尝试下一个..."
        fi
    done
    
    if [ "$INSTALLED" = false ]; then
        log_warning "所有镜像源都失败，尝试官方 PyPI 源..."
        pip3 install -r requirements.txt || {
            log_error "依赖安装失败"
            log_info "查看详细错误: cat /tmp/pip_install.log"
            exit 1
        }
    fi
else
    log_success "所有依赖已安装"
fi

# 再次验证
log_info "验证依赖安装..."
ALL_OK=true
for module in "${REQUIRED_MODULES[@]}"; do
    if ! python3 -c "import $module" 2>/dev/null; then
        log_error "模块仍然缺失: $module"
        ALL_OK=false
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

