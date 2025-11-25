#!/bin/bash
# 诊断登录和推荐功能问题

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
log_info "诊断登录和推荐功能问题"
echo "=========================================="
echo ""

# 步骤1：检查数据库中的用户数据
log_info "步骤1: 检查数据库中的用户数据..."
DB_NAME="canteen_recommendation"

echo "查看用户表结构:"
mysql -u root -ppassword -e "USE $DB_NAME; DESCRIBE users;" 2>/dev/null | head -10

echo ""
echo "查看用户数据（前5个）:"
mysql -u root -ppassword -e "USE $DB_NAME; SELECT id, username, LENGTH(password_hash) as hash_length, created_at FROM users LIMIT 5;" 2>/dev/null

echo ""
log_info "检查密码哈希格式..."
USER_COUNT=$(mysql -u root -ppassword -e "USE $DB_NAME; SELECT COUNT(*) FROM users;" 2>/dev/null | tail -1)
log_info "用户总数: $USER_COUNT"
echo ""

# 步骤2：检查后端日志
log_info "步骤2: 检查后端日志（最近错误）..."
RECENT_ERRORS=$($SUDO journalctl -u canteen-backend -n 100 --no-pager | grep -i "error\|exception\|traceback\|login\|register" | tail -20)
if [ -n "$RECENT_ERRORS" ]; then
    log_warning "发现相关错误:"
    echo "$RECENT_ERRORS"
else
    log_success "未发现明显错误"
fi
echo ""

# 步骤3：测试登录 API
log_info "步骤3: 测试登录 API..."
log_warning "需要先注册一个测试用户"
echo ""

# 步骤4：检查推荐模型
log_info "步骤4: 检查推荐模型..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL_DIR="$SCRIPT_DIR/backend/models"

if [ -f "$MODEL_DIR/cf_model.pkl" ] || [ -f "$MODEL_DIR/cb_model.pkl" ]; then
    log_success "推荐模型文件存在"
    ls -lh "$MODEL_DIR"/*.pkl 2>/dev/null || log_warning "模型文件位置可能不同"
else
    log_error "推荐模型文件不存在"
    log_info "需要训练模型: cd backend && python train_model.py"
fi
echo ""

# 步骤5：检查 Redis
log_info "步骤5: 检查 Redis..."
if $SUDO systemctl is-active redis >/dev/null 2>&1 || $SUDO systemctl is-active redis-server >/dev/null 2>&1; then
    log_success "Redis 服务运行中"
    if command -v redis-cli >/dev/null 2>&1; then
        if redis-cli ping >/dev/null 2>&1; then
            log_success "Redis 连接正常"
            
            # 检查推荐缓存
            CACHE_COUNT=$(redis-cli KEYS "recommendations:*" 2>/dev/null | wc -l)
            log_info "推荐缓存数量: $CACHE_COUNT"
        else
            log_error "Redis 连接失败"
        fi
    fi
else
    log_error "Redis 服务未运行"
fi
echo ""

# 步骤6：测试 API
log_info "步骤6: 测试 API..."
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

echo "=========================================="
log_info "诊断完成"
echo "=========================================="
echo ""
log_info "建议："
echo "  1. 检查用户密码哈希格式是否正确"
echo "  2. 查看后端日志: sudo journalctl -u canteen-backend -f"
echo "  3. 测试注册新用户并登录"
echo "  4. 检查推荐模型是否已训练"
echo "=========================================="

