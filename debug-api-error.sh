#!/bin/bash
# 调试 API 错误

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
log_info "调试 API 错误"
echo "=========================================="
echo ""

# 步骤1：直接测试数据库查询
log_info "步骤1: 直接测试数据库查询..."
DB_NAME="canteen_recommendation"

echo "测试查询: SELECT DISTINCT category FROM dishes"
QUERY_RESULT=$(mysql -u root -ppassword -e "USE $DB_NAME; SELECT DISTINCT category FROM dishes;" 2>&1)
if [ $? -eq 0 ]; then
    log_success "查询成功"
    echo "$QUERY_RESULT"
else
    log_error "查询失败"
    echo "$QUERY_RESULT"
fi
echo ""

# 步骤2：检查 dishes 表结构
log_info "步骤2: 检查 dishes 表结构..."
TABLE_STRUCT=$(mysql -u root -ppassword -e "USE $DB_NAME; DESCRIBE dishes;" 2>&1)
log_info "表结构:"
echo "$TABLE_STRUCT"
echo ""

# 步骤3：检查 category 字段数据
log_info "步骤3: 检查 category 字段数据..."
CATEGORY_DATA=$(mysql -u root -ppassword -e "USE $DB_NAME; SELECT DISTINCT category FROM dishes LIMIT 10;" 2>&1)
log_info "分类数据:"
echo "$CATEGORY_DATA"
echo ""

# 步骤4：查看实时后端日志
log_info "步骤4: 查看实时后端日志（按 Ctrl+C 退出）..."
log_warning "现在请在新终端运行: curl http://localhost:5000/api/v1/dishes/categories"
log_warning "然后按 Ctrl+C 退出日志查看"
echo ""
$SUDO journalctl -u canteen-backend -f --no-pager

