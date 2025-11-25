#!/bin/bash
# 完整修复评分功能：添加数据 + 修复代码 + 重新部署

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
log_info "完整修复评分功能"
echo "=========================================="
echo ""

# 步骤1：添加示例评分数据
log_info "步骤1: 添加示例评分数据..."
cd "$SCRIPT_DIR/backend"
source ../venv/bin/activate

if [ -f "../add-sample-ratings.py" ]; then
    log_info "运行脚本添加评分数据..."
    python3 ../add-sample-ratings.py
    log_success "示例数据添加完成"
else
    log_error "add-sample-ratings.py 不存在"
    exit 1
fi
echo ""

# 步骤2：重新构建前端
log_info "步骤2: 重新构建前端（应用评分功能修复）..."
cd "$SCRIPT_DIR/frontend"

# 确保没有设置环境变量
unset VITE_API_URL
export VITE_API_URL=""

# 清理旧构建
if [ -d "dist" ]; then
    rm -rf dist
fi

# 重新构建
log_info "构建前端..."
npm run build

if [ ! -d "dist" ]; then
    log_error "前端构建失败"
    exit 1
fi

log_success "前端构建完成"
echo ""

# 步骤3：部署前端
log_info "步骤3: 部署前端到 /var/www/canteen..."
$SUDO rm -rf /var/www/canteen/*
$SUDO cp -r dist/* /var/www/canteen/
$SUDO chown -R www-data:www-data /var/www/canteen
$SUDO chmod -R 755 /var/www/canteen
log_success "前端已部署"
echo ""

# 步骤4：重启服务
log_info "步骤4: 重启服务..."
$SUDO systemctl restart canteen-backend
$SUDO systemctl reload nginx
sleep 5

if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务运行中"
else
    log_error "后端服务启动失败"
    $SUDO journalctl -u canteen-backend -n 30 --no-pager
fi

if $SUDO systemctl is-active nginx >/dev/null 2>&1; then
    log_success "Nginx 服务运行中"
else
    log_error "Nginx 服务未运行"
fi
echo ""

# 步骤5：检查数据
log_info "步骤5: 检查数据..."
DB_NAME="canteen_recommendation"
RATING_COUNT=$(mysql -u root -ppassword -e "USE $DB_NAME; SELECT COUNT(*) FROM ratings;" 2>/dev/null | tail -1)
log_info "评分记录数: $RATING_COUNT"
echo ""

echo "=========================================="
log_success "修复完成！"
echo "=========================================="
echo ""
log_info "现在请："
echo "  1. 清除浏览器缓存（Ctrl+Shift+Delete）"
echo "  2. 强制刷新（Ctrl+F5）"
echo "  3. 重新登录"
echo "  4. 尝试评分功能"
echo ""
log_info "如果评分仍然失败，请："
echo "  1. 打开浏览器开发者工具 (F12)"
echo "  2. 查看 Network 标签"
echo "  3. 尝试评分，查看请求详情"
echo "  4. 查看 Console 标签的错误信息"
echo "=========================================="

