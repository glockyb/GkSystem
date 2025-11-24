#!/bin/bash
# 修复 Nginx 前端 500 错误

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

# 检查是否为 root
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
log_info "修复 Nginx 前端 500 错误"
echo "=========================================="
echo ""

# 步骤1：检查前端文件
log_info "步骤1: 检查前端文件..."
FRONTEND_DIST="$SCRIPT_DIR/frontend/dist"

if [ ! -d "$FRONTEND_DIST" ]; then
    log_error "前端 dist 目录不存在: $FRONTEND_DIST"
    log_info "重新构建前端..."
    
    cd frontend
    
    # 检查 node_modules
    if [ ! -d "node_modules" ]; then
        log_info "安装前端依赖..."
        npm install --registry=https://registry.npmmirror.com || npm install
    fi
    
    # 构建前端
    log_info "构建前端..."
    npm run build
    
    if [ ! -d "dist" ]; then
        log_error "前端构建失败"
        exit 1
    fi
    
    log_success "前端构建完成"
    cd ..
else
    log_success "前端 dist 目录存在"
fi

# 检查 index.html
if [ ! -f "$FRONTEND_DIST/index.html" ]; then
    log_error "index.html 不存在"
    log_info "重新构建前端..."
    cd frontend
    npm run build
    cd ..
fi

log_success "前端文件检查完成"
echo ""

# 步骤2：检查文件权限
log_info "步骤2: 检查文件权限..."
ls -la "$FRONTEND_DIST" | head -5

# 确保 Nginx 可以读取文件
log_info "设置文件权限..."
$SUDO chown -R www-data:www-data "$FRONTEND_DIST" 2>/dev/null || \
$SUDO chown -R nginx:nginx "$FRONTEND_DIST" 2>/dev/null || \
$SUDO chmod -R 755 "$FRONTEND_DIST"

log_success "文件权限设置完成"
echo ""

# 步骤3：检查 Nginx 配置
log_info "步骤3: 检查 Nginx 配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

if [ ! -f "$NGINX_CONFIG" ]; then
    log_error "Nginx 配置文件不存在: $NGINX_CONFIG"
    log_info "重新创建配置..."
    
    # 获取公网 IP
    PUBLIC_IP=$(hostname -I | awk '{print $1}')
    read -p "请输入公网 IP (默认: $PUBLIC_IP): " INPUT_IP
    PUBLIC_IP=${INPUT_IP:-$PUBLIC_IP}
    
    $SUDO tee "$NGINX_CONFIG" > /dev/null <<EOF
server {
    listen 80;
    server_name $PUBLIC_IP;

    # 日志配置
    access_log /var/log/nginx/canteen-access.log;
    error_log /var/log/nginx/canteen-error.log;

    # 前端静态文件
    location / {
        root $FRONTEND_DIST;
        index index.html;
        try_files \$uri \$uri/ /index.html;
        
        # 静态资源缓存
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
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
    
    log_success "Nginx 配置已创建"
else
    log_info "检查配置中的路径..."
    CONFIG_ROOT=$(grep -E "^\s*root" "$NGINX_CONFIG" | head -1 | awk '{print $2}' | tr -d ';')
    log_info "配置中的 root 路径: $CONFIG_ROOT"
    log_info "实际前端路径: $FRONTEND_DIST"
    
    if [ "$CONFIG_ROOT" != "$FRONTEND_DIST" ]; then
        log_warning "路径不匹配，更新配置..."
        
        # 备份原配置
        $SUDO cp "$NGINX_CONFIG" "${NGINX_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
        
        # 更新配置
        $SUDO sed -i "s|root.*frontend/dist|root $FRONTEND_DIST|g" "$NGINX_CONFIG"
        log_success "配置已更新"
    fi
fi

# 测试配置
log_info "测试 Nginx 配置..."
if $SUDO nginx -t 2>&1; then
    log_success "Nginx 配置正确"
else
    log_error "Nginx 配置有错误"
    $SUDO nginx -t 2>&1
    exit 1
fi
echo ""

# 步骤4：检查 Nginx 错误日志
log_info "步骤4: 查看 Nginx 错误日志（最近 10 行）..."
if [ -f /var/log/nginx/error.log ]; then
    $SUDO tail -10 /var/log/nginx/error.log
else
    log_warning "错误日志文件不存在"
fi
echo ""

# 步骤5：重启 Nginx
log_info "步骤5: 重启 Nginx..."
$SUDO systemctl restart nginx

sleep 2

if $SUDO systemctl is-active nginx >/dev/null 2>&1; then
    log_success "Nginx 已重启"
else
    log_error "Nginx 重启失败"
    $SUDO systemctl status nginx --no-pager -l | head -20
    exit 1
fi
echo ""

# 步骤6：测试访问
log_info "步骤6: 测试访问..."
sleep 2

# 测试前端
if curl -s http://localhost/ >/dev/null 2>&1; then
    RESPONSE=$(curl -s http://localhost/ | head -1)
    if echo "$RESPONSE" | grep -q "500\|Internal Server Error"; then
        log_error "仍然返回 500 错误"
        log_info "查看详细错误日志..."
        $SUDO tail -20 /var/log/nginx/error.log
    else
        log_success "前端访问正常"
    fi
else
    log_warning "无法访问前端"
fi

# 测试后端代理
if curl -s http://localhost/api/v1/ >/dev/null 2>&1; then
    log_success "后端 API 代理正常"
else
    log_warning "后端 API 代理可能有问题"
fi

echo ""
echo "=========================================="
log_info "修复完成"
echo "=========================================="
echo ""
log_info "测试命令："
echo "  curl http://localhost/"
echo "  curl http://localhost/api/v1/"
echo "  curl http://localhost/health"
echo ""
log_info "如果仍有问题，查看日志："
echo "  sudo tail -f /var/log/nginx/error.log"
echo "=========================================="

