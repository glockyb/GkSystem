#!/bin/bash
# 快速修复 Nginx 500 错误

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

echo "=========================================="
log_info "快速修复 Nginx 500 错误"
echo "=========================================="
echo ""

# 1. 检查前端文件
log_info "1. 检查前端文件..."
if [ ! -d "$FRONTEND_DIST" ] || [ ! -f "$FRONTEND_DIST/index.html" ]; then
    log_error "前端文件不存在，重新构建..."
    cd "$SCRIPT_DIR/frontend"
    if [ ! -d "node_modules" ]; then
        npm install --registry=https://registry.npmmirror.com || npm install
    fi
    npm run build
    cd "$SCRIPT_DIR"
fi

if [ -f "$FRONTEND_DIST/index.html" ]; then
    log_success "前端文件存在: $FRONTEND_DIST/index.html"
else
    log_error "前端文件不存在，请先构建前端"
    exit 1
fi

# 2. 检查并修复 Nginx 配置
log_info "2. 检查 Nginx 配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

# 获取实际路径（绝对路径）
REAL_PATH=$(readlink -f "$FRONTEND_DIST" 2>/dev/null || echo "$FRONTEND_DIST")

log_info "前端实际路径: $REAL_PATH"

# 检查配置中的路径
if [ -f "$NGINX_CONFIG" ]; then
    CONFIG_ROOT=$(grep -E "^\s*root" "$NGINX_CONFIG" | head -1 | awk '{print $2}' | tr -d ';')
    log_info "配置中的路径: $CONFIG_ROOT"
    
    # 检查路径是否存在
    if [ ! -d "$CONFIG_ROOT" ]; then
        log_warning "配置中的路径不存在，更新为实际路径..."
        $SUDO sed -i "s|root.*frontend/dist|root $REAL_PATH|g" "$NGINX_CONFIG"
        $SUDO sed -i "s|root.*GkSystem/frontend/dist|root $REAL_PATH|g" "$NGINX_CONFIG"
    fi
fi

# 3. 设置文件权限
log_info "3. 设置文件权限..."
$SUDO chmod -R 755 "$FRONTEND_DIST"
$SUDO chown -R www-data:www-data "$FRONTEND_DIST" 2>/dev/null || \
$SUDO chown -R nginx:nginx "$FRONTEND_DIST" 2>/dev/null || \
log_warning "无法设置文件所有者，但继续..."

# 4. 测试 Nginx 配置
log_info "4. 测试 Nginx 配置..."
if $SUDO nginx -t 2>&1; then
    log_success "配置正确"
else
    log_error "配置有错误"
    $SUDO nginx -t
    exit 1
fi

# 5. 查看错误日志
log_info "5. 查看 Nginx 错误日志（最近 5 行）..."
$SUDO tail -5 /var/log/nginx/error.log 2>/dev/null || log_warning "无法读取错误日志"

# 6. 重启 Nginx
log_info "6. 重启 Nginx..."
$SUDO systemctl restart nginx
sleep 2

# 7. 测试
log_info "7. 测试访问..."
sleep 1

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    log_success "前端访问正常 (HTTP $RESPONSE)"
elif [ "$RESPONSE" = "500" ]; then
    log_error "仍然返回 500 错误"
    log_info "查看详细错误日志..."
    $SUDO tail -20 /var/log/nginx/error.log
    echo ""
    log_info "检查配置..."
    $SUDO cat "$NGINX_CONFIG" | grep -A 5 "location /"
else
    log_warning "返回 HTTP $RESPONSE"
fi

echo ""
log_info "如果仍有问题，运行完整诊断："
echo "  sudo ./diagnose-500-error.sh"
echo "=========================================="

