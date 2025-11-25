#!/bin/bash
# 修复推荐功能 422 错误

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
log_info "修复推荐功能 422 错误"
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

# 步骤2：检查后端日志
log_info "步骤2: 检查后端日志（最近错误）..."
RECENT_ERRORS=$($SUDO journalctl -u canteen-backend -n 50 --no-pager | grep -i "error\|exception\|traceback\|422\|recommendation" | tail -15)
if [ -n "$RECENT_ERRORS" ]; then
    log_warning "发现错误:"
    echo "$RECENT_ERRORS"
else
    log_success "未发现错误"
fi
echo ""

# 步骤3：检查推荐模型
log_info "步骤3: 检查推荐模型..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL_DIR="$SCRIPT_DIR/backend/models"

if [ -f "$MODEL_DIR/cf_model.pkl" ] || [ -f "$MODEL_DIR/cb_model.pkl" ]; then
    log_success "推荐模型文件存在"
else
    log_warning "推荐模型文件不存在"
    log_info "需要训练模型: cd backend && python train_model.py"
fi
echo ""

# 步骤4：检查评分数据
log_info "步骤4: 检查评分数据..."
DB_NAME="canteen_recommendation"
RATING_COUNT=$(mysql -u root -ppassword -e "USE $DB_NAME; SELECT COUNT(*) FROM ratings;" 2>/dev/null | tail -1)
log_info "评分记录数: $RATING_COUNT"

if [ "$RATING_COUNT" -lt 10 ]; then
    log_warning "评分数据较少，推荐功能可能无法正常工作"
    log_info "建议运行: python3 add-sample-ratings.py"
fi
echo ""

echo "=========================================="
log_success "修复完成"
echo "=========================================="
echo ""
log_info "现在请："
echo "  1. 清除浏览器缓存（Ctrl+Shift+Delete）"
echo "  2. 强制刷新（Ctrl+F5）"
echo "  3. 重新登录"
echo "  4. 测试推荐功能"
echo ""
log_info "如果仍然返回 422，请："
echo "  1. 打开浏览器开发者工具 (F12)"
echo "  2. 查看 Network 标签"
echo "  3. 点击推荐，查看请求详情"
echo "  4. 查看请求头中的 Authorization"
echo "  5. 查看响应内容"
echo "=========================================="

