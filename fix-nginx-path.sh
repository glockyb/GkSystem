#!/bin/bash
# 修复 Nginx 路径问题

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
FRONTEND_DIST="$SCRIPT_DIR/frontend/dist"
REAL_PATH=$(readlink -f "$FRONTEND_DIST" 2>/dev/null || echo "$FRONTEND_DIST")

echo "=========================================="
log_info "修复 Nginx 路径问题"
echo "=========================================="
echo ""

log_info "实际前端路径: $REAL_PATH"

# 检查路径是否存在
if [ ! -d "$REAL_PATH" ] || [ ! -f "$REAL_PATH/index.html" ]; then
    log_error "前端文件不存在: $REAL_PATH"
    exit 1
fi

# 备份配置
NGINX_CONFIG="/etc/nginx/sites-available/canteen"
$SUDO cp "$NGINX_CONFIG" "${NGINX_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"

# 更新配置
log_info "更新 Nginx 配置..."
$SUDO sed -i "s|root.*frontend/dist|root $REAL_PATH|g" "$NGINX_CONFIG"
$SUDO sed -i "s|root.*GkSystem/frontend/dist|root $REAL_PATH|g" "$NGINX_CONFIG"

# 验证配置
log_info "验证配置..."
CONFIG_ROOT=$(grep -E "^\s*root" "$NGINX_CONFIG" | head -1 | awk '{print $2}' | tr -d ';')
log_info "更新后的路径: $CONFIG_ROOT"

# 测试配置
if $SUDO nginx -t 2>&1; then
    log_success "配置正确"
else
    log_error "配置有错误"
    exit 1
fi

# 设置权限
log_info "设置文件权限..."
$SUDO chmod -R 755 "$REAL_PATH"
$SUDO chown -R www-data:www-data "$REAL_PATH" 2>/dev/null || \
$SUDO chown -R nginx:nginx "$REAL_PATH" 2>/dev/null || \
log_warning "无法设置文件所有者"

# 重启 Nginx
log_info "重启 Nginx..."
$SUDO systemctl restart nginx
sleep 2

# 测试
log_info "测试访问..."
sleep 1
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")

if [ "$RESPONSE" = "200" ]; then
    log_success "修复成功！HTTP $RESPONSE"
elif [ "$RESPONSE" = "500" ]; then
    log_error "仍然返回 500"
    log_info "查看错误日志..."
    $SUDO tail -20 /var/log/nginx/error.log 2>/dev/null || \
    $SUDO tail -20 /var/log/nginx/canteen-error.log 2>/dev/null
else
    log_warning "返回 HTTP $RESPONSE"
fi

echo ""
log_success "修复完成！"
echo "=========================================="

