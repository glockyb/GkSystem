#!/bin/bash
# 检查 Nginx 配置和路径

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
log_info "检查 Nginx 配置和路径"
echo "=========================================="
echo ""

# 1. 查看 Nginx 配置
log_info "1. Nginx 配置文件内容："
echo "----------------------------------------"
$SUDO cat /etc/nginx/sites-available/canteen
echo "----------------------------------------"
echo ""

# 2. 检查配置中的路径
log_info "2. 检查配置中的路径..."
CONFIG_ROOT=$(grep -E "^\s*root" /etc/nginx/sites-available/canteen | head -1 | awk '{print $2}' | tr -d ';')
log_info "配置中的 root 路径: $CONFIG_ROOT"

# 3. 获取实际路径
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAL_DIST="$SCRIPT_DIR/frontend/dist"
REAL_DIST_ABS=$(readlink -f "$REAL_DIST" 2>/dev/null || echo "$REAL_DIST")

log_info "实际前端路径: $REAL_DIST_ABS"
echo ""

# 4. 检查路径是否存在
log_info "3. 检查路径..."
if [ -d "$CONFIG_ROOT" ]; then
    log_success "配置路径存在: $CONFIG_ROOT"
    ls -la "$CONFIG_ROOT" | head -5
else
    log_error "配置路径不存在: $CONFIG_ROOT"
fi

if [ -d "$REAL_DIST_ABS" ]; then
    log_success "实际路径存在: $REAL_DIST_ABS"
    ls -la "$REAL_DIST_ABS" | head -5
else
    log_error "实际路径不存在: $REAL_DIST_ABS"
fi
echo ""

# 5. 检查文件权限
log_info "4. 检查文件权限..."
if [ -d "$CONFIG_ROOT" ]; then
    log_info "配置路径权限:"
    ls -ld "$CONFIG_ROOT"
    if [ -f "$CONFIG_ROOT/index.html" ]; then
        ls -l "$CONFIG_ROOT/index.html"
    fi
fi
echo ""

# 6. 检查 Nginx 用户
log_info "5. 检查 Nginx 用户..."
NGINX_USER=$(ps aux | grep nginx | grep -v grep | head -1 | awk '{print $1}')
log_info "Nginx 运行用户: $NGINX_USER"

# 检查用户是否可以访问文件
if [ -d "$CONFIG_ROOT" ]; then
    log_info "测试 Nginx 用户访问权限..."
    if [ "$NGINX_USER" = "www-data" ]; then
        sudo -u www-data test -r "$CONFIG_ROOT/index.html" && \
        log_success "www-data 可以读取文件" || \
        log_error "www-data 无法读取文件"
    elif [ "$NGINX_USER" = "nginx" ]; then
        sudo -u nginx test -r "$CONFIG_ROOT/index.html" && \
        log_success "nginx 可以读取文件" || \
        log_error "nginx 无法读取文件"
    fi
fi
echo ""

# 7. 查看访问日志
log_info "6. 查看 Nginx 访问日志（最近 10 行）..."
if [ -f /var/log/nginx/canteen-access.log ]; then
    $SUDO tail -10 /var/log/nginx/canteen-access.log
elif [ -f /var/log/nginx/access.log ]; then
    $SUDO tail -10 /var/log/nginx/access.log
else
    log_warning "访问日志文件不存在"
fi
echo ""

# 8. 查看错误日志（详细）
log_info "7. 查看 Nginx 错误日志（所有内容）..."
if [ -f /var/log/nginx/canteen-error.log ]; then
    if [ -s /var/log/nginx/canteen-error.log ]; then
        $SUDO cat /var/log/nginx/canteen-error.log
    else
        log_warning "错误日志文件为空"
    fi
elif [ -f /var/log/nginx/error.log ]; then
    if [ -s /var/log/nginx/error.log ]; then
        $SUDO tail -50 /var/log/nginx/error.log
    else
        log_warning "错误日志文件为空"
    fi
else
    log_warning "错误日志文件不存在"
fi
echo ""

# 9. 测试访问并查看实时日志
log_info "8. 测试访问..."
log_info "请在一个终端运行: sudo tail -f /var/log/nginx/error.log"
log_info "然后在另一个终端运行: curl http://localhost/"
echo ""

# 10. 检查路径是否匹配
log_info "9. 路径匹配检查..."
if [ "$CONFIG_ROOT" != "$REAL_DIST_ABS" ]; then
    log_warning "路径不匹配！"
    log_info "配置路径: $CONFIG_ROOT"
    log_info "实际路径: $REAL_DIST_ABS"
    echo ""
    log_info "修复建议："
    echo "  sudo sed -i 's|root.*frontend/dist|root $REAL_DIST_ABS|g' /etc/nginx/sites-available/canteen"
    echo "  sudo nginx -t"
    echo "  sudo systemctl restart nginx"
else
    log_success "路径匹配"
fi
echo ""

echo "=========================================="
log_info "检查完成"
echo "=========================================="

