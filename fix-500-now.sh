#!/bin/bash
# 立即修复 500 错误

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
log_info "立即修复 500 错误"
echo "=========================================="
echo ""

# 获取实际路径
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRONTEND_DIST="$SCRIPT_DIR/frontend/dist"
REAL_PATH=$(readlink -f "$FRONTEND_DIST" 2>/dev/null || echo "$FRONTEND_DIST")

log_info "项目路径: $SCRIPT_DIR"
log_info "前端路径: $REAL_PATH"
echo ""

# 步骤1：检查前端文件
log_info "步骤1: 检查前端文件..."
if [ ! -d "$REAL_PATH" ] || [ ! -f "$REAL_PATH/index.html" ]; then
    log_error "前端文件不存在，重新构建..."
    cd "$SCRIPT_DIR/frontend"
    
    if [ ! -d "node_modules" ]; then
        log_info "安装前端依赖..."
        npm install --registry=https://registry.npmmirror.com || npm install
    fi
    
    log_info "构建前端..."
    npm run build
    
    if [ ! -f "dist/index.html" ]; then
        log_error "前端构建失败"
        exit 1
    fi
    
    REAL_PATH=$(readlink -f "$SCRIPT_DIR/frontend/dist" 2>/dev/null || echo "$SCRIPT_DIR/frontend/dist")
    log_success "前端构建完成"
else
    log_success "前端文件存在"
fi
echo ""

# 步骤2：查看当前 Nginx 配置
log_info "步骤2: 查看当前 Nginx 配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"
if [ -f "$NGINX_CONFIG" ]; then
    log_info "当前配置中的 root 路径:"
    grep -E "^\s*root" "$NGINX_CONFIG" | head -1
else
    log_error "配置文件不存在"
fi
echo ""

# 步骤3：查看 Nginx 错误日志
log_info "步骤3: 查看 Nginx 错误日志（最近 10 行）..."
ERROR_LOG="/var/log/nginx/canteen-error.log"
if [ ! -f "$ERROR_LOG" ]; then
    ERROR_LOG="/var/log/nginx/error.log"
fi

if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
    $SUDO tail -10 "$ERROR_LOG"
else
    log_warning "错误日志为空或不存在"
fi
echo ""

# 步骤4：重新创建 Nginx 配置（使用绝对路径）
log_info "步骤4: 重新创建 Nginx 配置..."
PUBLIC_IP=$(hostname -I | awk '{print $1}')

# 备份原配置
if [ -f "$NGINX_CONFIG" ]; then
    $SUDO cp "$NGINX_CONFIG" "${NGINX_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
fi

# 创建新配置（使用绝对路径，不使用变量）
$SUDO tee "$NGINX_CONFIG" > /dev/null <<EOF
server {
    listen 80;
    server_name $PUBLIC_IP;

    access_log /var/log/nginx/canteen-access.log;
    error_log /var/log/nginx/canteen-error.log;

    location / {
        root $REAL_PATH;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:5000/api;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        proxy_set_header Host \$host;
    }
}
EOF

log_success "配置已更新"
log_info "配置中的路径: $REAL_PATH"
echo ""

# 步骤5：验证配置
log_info "步骤5: 验证 Nginx 配置..."
if $SUDO nginx -t 2>&1; then
    log_success "配置正确"
else
    log_error "配置有错误"
    $SUDO nginx -t
    exit 1
fi
echo ""

# 步骤6：设置文件权限
log_info "步骤6: 设置文件权限..."
$SUDO chmod -R 755 "$REAL_PATH"
$SUDO chown -R www-data:www-data "$REAL_PATH" 2>/dev/null || \
$SUDO chown -R nginx:nginx "$REAL_PATH" 2>/dev/null || \
log_warning "无法设置文件所有者，但继续..."

# 验证 Nginx 用户是否可以读取
NGINX_USER=$(ps aux | grep nginx | grep -v grep | head -1 | awk '{print $1}' || echo "www-data")
if [ "$NGINX_USER" = "www-data" ]; then
    if $SUDO -u www-data test -r "$REAL_PATH/index.html" 2>/dev/null; then
        log_success "www-data 可以读取文件"
    else
        log_warning "www-data 可能无法读取文件，调整权限..."
        $SUDO chmod -R 755 "$REAL_PATH"
        $SUDO chown -R www-data:www-data "$REAL_PATH" 2>/dev/null || true
    fi
fi
echo ""

# 步骤7：重启 Nginx
log_info "步骤7: 重启 Nginx..."
$SUDO systemctl restart nginx
sleep 3

if $SUDO systemctl is-active nginx >/dev/null 2>&1; then
    log_success "Nginx 已重启"
else
    log_error "Nginx 启动失败"
    $SUDO systemctl status nginx --no-pager -l | head -20
    exit 1
fi
echo ""

# 步骤8：测试访问
log_info "步骤8: 测试访问..."
sleep 2

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
CONTENT=$(curl -s http://localhost/ 2>/dev/null | head -3)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "✅ 修复成功！HTTP $HTTP_CODE"
    echo "响应内容预览:"
    echo "$CONTENT" | head -3
elif [ "$HTTP_CODE" = "500" ]; then
    log_error "仍然返回 500 错误"
    echo ""
    log_info "查看详细错误日志..."
    $SUDO tail -30 "$ERROR_LOG" 2>/dev/null || log_warning "无法读取错误日志"
    echo ""
    log_info "检查配置..."
    $SUDO cat "$NGINX_CONFIG"
    echo ""
    log_info "检查文件..."
    ls -la "$REAL_PATH/" | head -5
    echo ""
    log_warning "如果仍然失败，请手动检查："
    echo "  1. sudo tail -f /var/log/nginx/error.log"
    echo "  2. sudo cat /etc/nginx/sites-available/canteen"
    echo "  3. ls -la $REAL_PATH/"
else
    log_warning "返回 HTTP $HTTP_CODE"
    echo "响应内容: $CONTENT"
fi

echo ""
echo "=========================================="
log_info "修复完成"
echo "=========================================="

