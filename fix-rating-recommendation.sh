#!/bin/bash
# 修复评分和推荐功能

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
log_info "修复评分和推荐功能"
echo "=========================================="
echo ""

# 步骤1：检查后端日志
log_info "步骤1: 检查后端日志（最近错误）..."
RECENT_ERRORS=$($SUDO journalctl -u canteen-backend -n 100 --no-pager | grep -i "error\|exception\|traceback\|rating\|recommendation" | tail -20)
if [ -n "$RECENT_ERRORS" ]; then
    log_warning "发现相关错误:"
    echo "$RECENT_ERRORS"
else
    log_info "未发现明显错误"
fi
echo ""

# 步骤2：检查推荐模型
log_info "步骤2: 检查推荐模型..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL_DIR="$SCRIPT_DIR/backend/models"

if [ -f "$MODEL_DIR/cf_model.pkl" ] || [ -f "$MODEL_DIR/cb_model.pkl" ]; then
    log_success "推荐模型文件存在"
    ls -lh "$MODEL_DIR"/*.pkl 2>/dev/null | head -5
else
    log_error "推荐模型文件不存在"
    log_info "需要训练模型"
fi
echo ""

# 步骤3：检查数据库中的评分数据
log_info "步骤3: 检查数据库中的评分数据..."
DB_NAME="canteen_recommendation"

RATING_COUNT=$(mysql -u root -ppassword -e "USE $DB_NAME; SELECT COUNT(*) FROM ratings;" 2>/dev/null | tail -1)
log_info "评分记录数: $RATING_COUNT"

if [ "$RATING_COUNT" -eq 0 ]; then
    log_warning "没有评分数据，推荐功能可能无法正常工作"
    log_info "建议：先对菜品进行评分"
fi

USER_COUNT=$(mysql -u root -ppassword -e "USE $DB_NAME; SELECT COUNT(*) FROM users;" 2>/dev/null | tail -1)
log_info "用户数: $USER_COUNT"
echo ""

# 步骤4：检查 Redis
log_info "步骤4: 检查 Redis..."
if $SUDO systemctl is-active redis >/dev/null 2>&1 || $SUDO systemctl is-active redis-server >/dev/null 2>&1; then
    log_success "Redis 服务运行中"
    if command -v redis-cli >/dev/null 2>&1; then
        if redis-cli ping >/dev/null 2>&1; then
            log_success "Redis 连接正常"
        else
            log_error "Redis 连接失败"
            $SUDO systemctl restart redis 2>/dev/null || $SUDO systemctl restart redis-server 2>/dev/null
            sleep 2
        fi
    fi
else
    log_error "Redis 服务未运行"
    $SUDO systemctl start redis 2>/dev/null || $SUDO systemctl start redis-server 2>/dev/null
    sleep 2
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

# 步骤6：测试 API（需要 token）
log_info "步骤6: 测试 API..."
sleep 3

echo "测试健康检查:"
HEALTH=$(curl -s http://localhost:5000/health 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    log_success "健康检查: $HEALTH"
else
    log_error "健康检查失败: $HEALTH"
fi

echo ""
log_info "评分和推荐 API 需要 JWT token，请在浏览器中测试"
echo ""

echo "=========================================="
log_success "修复完成"
echo "=========================================="
echo ""
log_info "如果推荐功能仍然失败，可能的原因："
echo "  1. 推荐模型未训练 - 运行: cd backend && python train_model.py"
echo "  2. 没有足够的评分数据 - 先对菜品进行评分"
echo "  3. Redis 连接问题 - 检查 Redis 服务"
echo ""
log_info "如果评分功能仍然失败，请："
echo "  1. 打开浏览器开发者工具 (F12)"
echo "  2. 查看 Console 和 Network 标签"
echo "  3. 尝试评分，查看具体错误信息"
echo "=========================================="

