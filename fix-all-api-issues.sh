#!/bin/bash
# 修复所有 API 问题（推荐、评分、图片）

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
log_info "修复所有 API 问题"
echo "=========================================="
echo ""

# 步骤1：检查 Redis
log_info "步骤1: 检查 Redis 服务..."
if $SUDO systemctl is-active redis >/dev/null 2>&1 || $SUDO systemctl is-active redis-server >/dev/null 2>&1; then
    log_success "Redis 服务运行中"
    if command -v redis-cli >/dev/null 2>&1; then
        if redis-cli ping >/dev/null 2>&1; then
            log_success "Redis 连接正常"
        else
            log_warning "Redis 连接失败（推荐功能可能受影响）"
        fi
    fi
else
    log_warning "Redis 服务未运行（推荐功能可能受影响）"
    log_info "启动 Redis..."
    $SUDO systemctl start redis 2>/dev/null || $SUDO systemctl start redis-server 2>/dev/null
    sleep 2
fi
echo ""

# 步骤2：检查推荐模型
log_info "步骤2: 检查推荐模型..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL_DIR="$SCRIPT_DIR/backend/models"

if [ -f "$MODEL_DIR/cf_model.pkl" ] || [ -f "$MODEL_DIR/cb_model.pkl" ]; then
    log_success "推荐模型文件存在"
else
    log_warning "推荐模型文件不存在"
    log_info "需要训练模型: cd backend && python train_model.py"
fi
echo ""

# 步骤3：重启后端服务
log_info "步骤3: 重启后端服务（应用代码修复）..."
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

# 步骤4：测试 API
log_info "步骤4: 测试 API..."
sleep 3

echo "测试分类 API:"
CATEGORIES=$(curl -s http://localhost:5000/api/v1/dishes/categories 2>&1)
if echo "$CATEGORIES" | grep -q "categories"; then
    log_success "分类 API 正常"
else
    log_error "分类 API 失败: $CATEGORIES"
fi

echo ""
echo "测试菜品列表 API:"
DISHES=$(curl -s "http://localhost:5000/api/v1/dishes?page=1&per_page=5" 2>&1)
if echo "$DISHES" | grep -q "dishes"; then
    log_success "菜品列表 API 正常"
    # 检查图片 URL
    IMAGE_COUNT=$(echo "$DISHES" | grep -o "image_url" | wc -l || echo "0")
    log_info "包含 $IMAGE_COUNT 个图片字段"
else
    log_error "菜品列表 API 失败: $DISHES"
fi
echo ""

# 步骤5：检查数据库中的图片 URL
log_info "步骤5: 检查数据库中的图片数据..."
DB_NAME="canteen_recommendation"
IMAGE_CHECK=$(mysql -u root -ppassword -e "USE $DB_NAME; SELECT COUNT(*) as total, COUNT(image_url) as with_image FROM dishes;" 2>/dev/null | tail -1)
if [ -n "$IMAGE_CHECK" ]; then
    log_info "图片数据: $IMAGE_CHECK"
    # 解析结果（格式：total  with_image）
    TOTAL=$(echo "$IMAGE_CHECK" | awk '{print $1}')
    WITH_IMAGE=$(echo "$IMAGE_CHECK" | awk '{print $2}')
    if [ "$WITH_IMAGE" -lt "$TOTAL" ]; then
        log_warning "部分菜品缺少图片 URL ($WITH_IMAGE/$TOTAL)"
    else
        log_success "所有菜品都有图片 URL"
    fi
fi
echo ""

echo "=========================================="
log_success "修复完成"
echo "=========================================="
echo ""
log_info "现在请："
echo "  1. 清除浏览器缓存"
echo "  2. 重新登录"
echo "  3. 测试推荐和评分功能"
echo ""
log_info "如果推荐仍然失败，可能需要："
echo "  1. 训练推荐模型: cd backend && python train_model.py"
echo "  2. 确保 Redis 正常运行"
echo "=========================================="

