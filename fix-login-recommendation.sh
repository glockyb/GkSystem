#!/bin/bash
# 修复登录和推荐功能

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

echo "=========================================="
log_info "修复登录和推荐功能"
echo "=========================================="
echo ""

# 步骤1：重启后端服务（应用代码修复）
log_info "步骤1: 重启后端服务..."
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

# 步骤2：检查 Redis
log_info "步骤2: 检查 Redis..."
if $SUDO systemctl is-active redis >/dev/null 2>&1 || $SUDO systemctl is-active redis-server >/dev/null 2>&1; then
    log_success "Redis 服务运行中"
    if command -v redis-cli >/dev/null 2>&1; then
        if redis-cli ping >/dev/null 2>&1; then
            log_success "Redis 连接正常"
        else
            log_warning "Redis 连接失败，重启..."
            $SUDO systemctl restart redis 2>/dev/null || $SUDO systemctl restart redis-server 2>/dev/null
            sleep 2
        fi
    fi
else
    log_warning "Redis 服务未运行，启动..."
    $SUDO systemctl start redis 2>/dev/null || $SUDO systemctl start redis-server 2>/dev/null
    sleep 2
fi
echo ""

# 步骤3：检查推荐模型
log_info "步骤3: 检查推荐模型..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL_DIR="$SCRIPT_DIR/backend/models"

if [ -f "$MODEL_DIR/cf_model.pkl" ] || [ -f "$MODEL_DIR/cb_model.pkl" ]; then
    log_success "推荐模型文件存在"
    ls -lh "$MODEL_DIR"/*.pkl 2>/dev/null | head -5
else
    log_warning "推荐模型文件不存在"
    log_info "需要训练模型: cd backend && python train_model.py"
fi
echo ""

# 步骤4：测试 API
log_info "步骤4: 测试 API..."
sleep 3

echo "测试健康检查:"
HEALTH=$(curl -s http://localhost:5000/health 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    log_success "健康检查: $HEALTH"
else
    log_error "健康检查失败: $HEALTH"
fi

echo ""
log_info "测试分类 API:"
CATEGORIES=$(curl -s http://localhost:5000/api/v1/dishes/categories 2>&1)
if echo "$CATEGORIES" | grep -q "categories"; then
    log_success "分类 API 正常"
else
    log_error "分类 API 失败: $CATEGORIES"
fi
echo ""

# 步骤5：检查后端日志
log_info "步骤5: 检查后端日志（最近错误）..."
RECENT_ERRORS=$($SUDO journalctl -u canteen-backend -n 50 --no-pager | grep -i "error\|exception\|traceback" | tail -10)
if [ -n "$RECENT_ERRORS" ]; then
    log_warning "发现错误:"
    echo "$RECENT_ERRORS"
else
    log_success "未发现错误"
fi
echo ""

echo "=========================================="
log_success "修复完成"
echo "=========================================="
echo ""
log_info "现在请："
echo "  1. 清除浏览器缓存（Ctrl+Shift+Delete）"
echo "  2. 强制刷新（Ctrl+F5）"
echo "  3. 尝试登录（如果失败，可能需要重新注册）"
echo "  4. 测试推荐功能"
echo ""
log_info "如果登录仍然失败，可能需要："
echo "  1. 重置旧用户的密码（在数据库中）"
echo "  2. 或者删除旧用户，重新注册"
echo "=========================================="

