#!/bin/bash
# 修复评分功能并添加示例数据

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
log_info "修复评分功能并添加示例数据"
echo "=========================================="
echo ""

# 步骤1：检查数据库
log_info "步骤1: 检查数据库..."
DB_NAME="canteen_recommendation"

USER_COUNT=$(mysql -u root -ppassword -e "USE $DB_NAME; SELECT COUNT(*) FROM users;" 2>/dev/null | tail -1)
DISH_COUNT=$(mysql -u root -ppassword -e "USE $DB_NAME; SELECT COUNT(*) FROM dishes;" 2>/dev/null | tail -1)
RATING_COUNT=$(mysql -u root -ppassword -e "USE $DB_NAME; SELECT COUNT(*) FROM ratings;" 2>/dev/null | tail -1)

log_info "用户数: $USER_COUNT"
log_info "菜品数: $DISH_COUNT"
log_info "评分数: $RATING_COUNT"
echo ""

# 步骤2：添加示例评分数据
log_info "步骤2: 添加示例评分数据..."
cd "$SCRIPT_DIR"

if [ -f "add-sample-ratings.py" ]; then
    cd backend
    source ../venv/bin/activate
    
    log_info "运行脚本添加评分数据..."
    python3 ../add-sample-ratings.py
    
    if [ $? -eq 0 ]; then
        log_success "示例数据添加完成"
    else
        log_error "添加数据失败"
    fi
else
    log_error "add-sample-ratings.py 不存在"
fi
echo ""

# 步骤3：检查评分表结构
log_info "步骤3: 检查评分表结构..."
TABLE_STRUCT=$(mysql -u root -ppassword -e "USE $DB_NAME; DESCRIBE ratings;" 2>/dev/null)
log_info "评分表结构:"
echo "$TABLE_STRUCT" | head -10
echo ""

# 步骤4：检查是否有唯一索引
log_info "步骤4: 检查评分表索引..."
INDEXES=$(mysql -u root -ppassword -e "USE $DB_NAME; SHOW INDEXES FROM ratings;" 2>/dev/null)
if echo "$INDEXES" | grep -q "user_id.*dish_id\|PRIMARY"; then
    log_success "评分表索引正常"
else
    log_warning "可能需要添加唯一索引"
    log_info "检查表结构..."
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
fi
echo ""

# 步骤6：查看后端日志
log_info "步骤6: 查看后端日志（最近错误）..."
RECENT_ERRORS=$($SUDO journalctl -u canteen-backend -n 50 --no-pager | grep -i "error\|exception\|traceback\|rating" | tail -10)
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
echo "  1. 清除浏览器缓存"
echo "  2. 重新登录"
echo "  3. 尝试评分功能"
echo ""
log_info "如果评分仍然失败，请："
echo "  1. 打开浏览器开发者工具 (F12)"
echo "  2. 查看 Network 标签"
echo "  3. 尝试评分，查看请求和响应"
echo "  4. 查看 Console 标签的错误信息"
echo "=========================================="

