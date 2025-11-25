#!/bin/bash
# 修复推荐和评分问题

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
log_info "修复推荐和评分问题"
echo "=========================================="
echo ""

# 步骤1：检查并安装 Python 开发头文件
log_info "步骤1: 检查 Python 开发头文件..."
if ! dpkg -l | grep -q python3-dev; then
    log_warning "缺少 python3-dev，安装..."
    $SUDO apt-get update
    $SUDO apt-get install -y python3-dev python3.9-dev build-essential
    log_success "已安装"
else
    log_success "Python 开发头文件已安装"
fi
echo ""

# 步骤2：安装 scikit-surprise
log_info "步骤2: 安装 scikit-surprise..."
cd "$SCRIPT_DIR/backend"

if [ -d "../venv" ]; then
    log_info "使用虚拟环境..."
    source ../venv/bin/activate
    
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
        if pip install scikit-surprise -i "$mirror" 2>&1 | tee /tmp/surprise_install.log; then
            INSTALLED=true
            break
        fi
    done
    
    if [ "$INSTALLED" = false ]; then
        log_error "安装失败，查看日志..."
        tail -20 /tmp/surprise_install.log
        exit 1
    fi
    
    # 验证安装
    if python -c "import surprise" 2>/dev/null; then
        log_success "scikit-surprise 安装成功"
    else
        log_error "scikit-surprise 安装失败"
        exit 1
    fi
else
    log_error "虚拟环境不存在"
    exit 1
fi
echo ""

# 步骤3：检查 Redis
log_info "步骤3: 检查 Redis 服务..."
if $SUDO systemctl is-active redis >/dev/null 2>&1 || $SUDO systemctl is-active redis-server >/dev/null 2>&1; then
    log_success "Redis 服务运行中"
    if command -v redis-cli >/dev/null 2>&1; then
        if redis-cli ping >/dev/null 2>&1; then
            log_success "Redis 连接正常"
        else
            log_warning "Redis 连接失败"
            $SUDO systemctl restart redis 2>/dev/null || $SUDO systemctl restart redis-server 2>/dev/null
        fi
    fi
else
    log_warning "Redis 服务未运行，启动..."
    $SUDO systemctl start redis 2>/dev/null || $SUDO systemctl start redis-server 2>/dev/null
    sleep 2
    if $SUDO systemctl is-active redis >/dev/null 2>&1 || $SUDO systemctl is-active redis-server >/dev/null 2>&1; then
        log_success "Redis 已启动"
    else
        log_warning "Redis 启动失败（推荐功能可能受影响）"
    fi
fi
echo ""

# 步骤4：训练推荐模型
log_info "步骤4: 训练推荐模型..."
cd "$SCRIPT_DIR/backend"

if [ -d "../venv" ]; then
    source ../venv/bin/activate
    
    log_info "开始训练模型（可能需要几分钟）..."
    if python train_model.py 2>&1 | tee /tmp/train_model.log; then
        log_success "模型训练完成"
        
        # 检查模型文件
        if [ -f "models/cf_model.pkl" ] || [ -f "models/cb_model.pkl" ]; then
            log_success "模型文件已生成"
            ls -lh models/*.pkl 2>/dev/null || log_warning "模型文件位置可能不同"
        else
            log_warning "未找到模型文件，但训练可能已成功"
        fi
    else
        log_error "模型训练失败"
        log_info "查看日志..."
        tail -30 /tmp/train_model.log
        exit 1
    fi
else
    log_error "虚拟环境不存在"
    exit 1
fi
echo ""

# 步骤5：重启后端服务
log_info "步骤5: 重启后端服务..."
$SUDO systemctl restart canteen-backend
sleep 5

if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务运行中"
else
    log_error "后端服务启动失败"
    $SUDO journalctl -u canteen-backend -n 30 --no-pager
    exit 1
fi
echo ""

# 步骤6：检查后端日志中的错误
log_info "步骤6: 检查后端日志（最近错误）..."
RECENT_ERRORS=$($SUDO journalctl -u canteen-backend -n 50 --no-pager | grep -i "error\|exception\|traceback" | tail -10)
if [ -n "$RECENT_ERRORS" ]; then
    log_warning "发现错误:"
    echo "$RECENT_ERRORS"
else
    log_success "未发现错误"
fi
echo ""

# 步骤7：测试 API（需要先登录获取 token）
log_info "步骤7: 测试 API..."
sleep 3

echo "测试分类 API:"
CATEGORIES=$(curl -s http://localhost:5000/api/v1/dishes/categories 2>&1)
if echo "$CATEGORIES" | grep -q "categories"; then
    log_success "分类 API 正常"
else
    log_error "分类 API 失败: $CATEGORIES"
fi

echo ""
log_info "推荐和评分 API 需要 JWT token，请在浏览器中测试"
echo ""

echo "=========================================="
log_success "修复完成"
echo "=========================================="
echo ""
log_info "现在请："
echo "  1. 清除浏览器缓存"
echo "  2. 重新登录"
echo "  3. 测试推荐功能"
echo "  4. 测试评分功能"
echo ""
log_info "如果仍然失败，请："
echo "  1. 打开浏览器开发者工具 (F12)"
echo "  2. 查看 Console 和 Network 标签"
echo "  3. 查看具体错误信息"
echo "=========================================="

