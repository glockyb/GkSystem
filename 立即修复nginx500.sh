#!/bin/bash
# 立即修复 Nginx 500 错误

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
log_info "立即修复 Nginx 500 错误"
echo "=========================================="
echo ""

# 获取实际路径
REAL_PATH=$(readlink -f ~/gksys/GkSystem/frontend/dist 2>/dev/null || echo "/root/gksys/GkSystem/frontend/dist")
log_info "实际前端路径: $REAL_PATH"

# 检查路径是否存在
if [ ! -d "$REAL_PATH" ] || [ ! -f "$REAL_PATH/index.html" ]; then
    log_error "前端文件不存在，重新构建..."
    cd ~/gksys/GkSystem/frontend
    npm run build
    REAL_PATH=$(readlink -f ~/gksys/GkSystem/frontend/dist 2>/dev/null || echo "/root/gksys/GkSystem/frontend/dist")
fi

# 备份配置
NGINX_CONFIG="/etc/nginx/sites-available/canteen"
$SUDO cp "$NGINX_CONFIG" "${NGINX_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"

# 重新创建配置（使用绝对路径）
log_info "重新创建 Nginx 配置..."
PUBLIC_IP=$(hostname -I | awk '{print $1}')

$SUDO tee "$NGINX_CONFIG" > /dev/null <<EOF
server {
    listen 80;
    server_name $PUBLIC_IP;

    # 日志配置
    access_log /var/log/nginx/canteen-access.log;
    error_log /var/log/nginx/canteen-error.log;

    # 前端静态文件
    location / {
        root $REAL_PATH;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    # 后端 API 代理
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

    # 健康检查
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        proxy_set_header Host \$host;
    }
}
EOF

log_success "配置已更新"
echo ""

# 验证配置
log_info "验证配置..."
if $SUDO nginx -t 2>&1; then
    log_success "配置正确"
else
    log_error "配置有错误"
    exit 1
fi
echo ""

# 设置权限
log_info "设置文件权限..."
$SUDO chmod -R 755 "$REAL_PATH"
$SUDO chown -R www-data:www-data "$REAL_PATH" 2>/dev/null || \
$SUDO chown -R nginx:nginx "$REAL_PATH" 2>/dev/null || \
log_warning "无法设置文件所有者，但继续..."
echo ""

# 重启 Nginx
log_info "重启 Nginx..."
$SUDO systemctl restart nginx
sleep 3

# 测试
log_info "测试访问..."
sleep 1

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
CONTENT=$(curl -s http://localhost/ 2>/dev/null | head -1)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "✅ 修复成功！HTTP $HTTP_CODE"
    echo "前端内容: $CONTENT"
elif echo "$CONTENT" | grep -q "500\|Internal Server Error"; then
    log_error "仍然返回 500 错误"
    echo ""
    log_info "查看详细错误日志..."
    $SUDO tail -30 /var/log/nginx/error.log 2>/dev/null || \
    $SUDO tail -30 /var/log/nginx/canteen-error.log 2>/dev/null || \
    log_warning "无法读取错误日志"
    echo ""
    log_info "检查配置..."
    $SUDO cat "$NGINX_CONFIG"
else
    log_warning "返回 HTTP $HTTP_CODE"
    echo "响应内容: $CONTENT"
fi

echo ""
log_success "修复完成！"
echo "=========================================="

