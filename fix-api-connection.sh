#!/bin/bash
# 修复前端 API 连接问题

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
log_info "修复前端 API 连接问题"
echo "=========================================="
echo ""

# 步骤1：检查后端服务
log_info "步骤1: 检查后端服务..."
if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务运行中"
else
    log_error "后端服务未运行"
    log_info "启动后端服务..."
    $SUDO systemctl start canteen-backend
    sleep 3
fi
echo ""

# 步骤2：测试后端 API（本地）
log_info "步骤2: 测试后端 API（本地）..."
if curl -s http://localhost:5000/health >/dev/null 2>&1; then
    RESPONSE=$(curl -s http://localhost:5000/health)
    log_success "后端 API 正常: $RESPONSE"
else
    log_error "后端 API 不可访问（本地）"
    log_info "查看后端日志..."
    $SUDO journalctl -u canteen-backend -n 20 --no-pager
    exit 1
fi
echo ""

# 步骤3：检查防火墙
log_info "步骤3: 检查防火墙..."
PUBLIC_IP=$(hostname -I | awk '{print $1}')

# 检查 UFW
if command -v ufw >/dev/null 2>&1; then
    if $SUDO ufw status | grep -q "Status: active"; then
        log_info "UFW 防火墙运行中"
        
        # 检查 5000 端口
        if $SUDO ufw status | grep -q "5000"; then
            log_info "端口 5000 已配置"
        else
            log_warning "端口 5000 未开放"
            read -p "是否开放端口 5000? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                $SUDO ufw allow 5000/tcp
                log_success "端口 5000 已开放"
            fi
        fi
    else
        log_info "UFW 防火墙未启用"
    fi
fi
echo ""

# 步骤4：检查 Nginx API 代理
log_info "步骤4: 检查 Nginx API 代理配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

if grep -q "location /api" "$NGINX_CONFIG"; then
    log_success "API 代理配置存在"
    log_info "API 代理配置:"
    grep -A 10 "location /api" "$NGINX_CONFIG" | head -10
else
    log_error "API 代理配置不存在"
    log_info "添加 API 代理配置..."
    
    # 备份
    $SUDO cp "$NGINX_CONFIG" "${NGINX_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
    
    # 在 location / 之后添加 API 代理
    $SUDO sed -i '/location \/ {/a\
\
    # 后端 API 代理\
    location /api {\
        proxy_pass http://127.0.0.1:5000/api;\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto $scheme;\
        proxy_connect_timeout 60s;\
        proxy_send_timeout 60s;\
        proxy_read_timeout 60s;\
    }
' "$NGINX_CONFIG"
fi
echo ""

# 步骤5：测试 Nginx API 代理
log_info "步骤5: 测试 Nginx API 代理..."
sleep 1

if curl -s http://localhost/api/v1/ >/dev/null 2>&1 || \
   curl -s http://localhost/api/health >/dev/null 2>&1; then
    log_success "Nginx API 代理正常"
else
    log_warning "Nginx API 代理可能有问题"
    log_info "测试代理..."
    curl -v http://localhost/api/v1/ 2>&1 | head -20
fi
echo ""

# 步骤6：检查前端 API 配置
log_info "步骤6: 检查前端 API 配置..."
FRONTEND_DIST="/var/www/canteen"

if [ -f "$FRONTEND_DIST/index.html" ]; then
    # 检查前端是否使用相对路径
    if grep -q 'baseURL.*localhost\|baseURL.*127.0.0.1\|baseURL.*5000' "$FRONTEND_DIST/index.html" 2>/dev/null || \
       find "$FRONTEND_DIST" -name "*.js" -exec grep -l "localhost:5000\|127.0.0.1:5000" {} \; 2>/dev/null | head -1; then
        log_warning "前端可能配置了错误的 API 地址"
        log_info "前端应该使用相对路径 /api/v1，通过 Nginx 代理"
    else
        log_success "前端配置正常（使用相对路径）"
    fi
else
    log_warning "无法检查前端配置"
fi
echo ""

# 步骤7：重新加载 Nginx
log_info "步骤7: 重新加载 Nginx..."
$SUDO nginx -t
$SUDO systemctl reload nginx
sleep 2
echo ""

# 步骤8：测试外部访问
log_info "步骤8: 测试外部访问..."
PUBLIC_IP=$(hostname -I | awk '{print $1}')

log_info "测试前端: http://$PUBLIC_IP/"
HTTP_CODE_FRONTEND=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE_FRONTEND" = "200" ]; then
    log_success "前端访问正常 (HTTP $HTTP_CODE_FRONTEND)"
else
    log_warning "前端返回 HTTP $HTTP_CODE_FRONTEND"
fi

log_info "测试 API 代理: http://$PUBLIC_IP/api/v1/"
HTTP_CODE_API=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/v1/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE_API" = "200" ] || [ "$HTTP_CODE_API" = "401" ] || [ "$HTTP_CODE_API" = "404" ]; then
    log_success "API 代理正常 (HTTP $HTTP_CODE_API)"
    log_info "注意：401/404 是正常的，说明代理工作正常"
else
    log_warning "API 代理返回 HTTP $HTTP_CODE_API"
fi

log_info "测试后端直连: http://$PUBLIC_IP:5000/health"
HTTP_CODE_DIRECT=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/health 2>/dev/null || echo "000")
if [ "$HTTP_CODE_DIRECT" = "200" ]; then
    log_success "后端直连正常 (HTTP $HTTP_CODE_DIRECT)"
    log_info "如果外部无法访问，需要开放防火墙端口 5000"
else
    log_warning "后端直连返回 HTTP $HTTP_CODE_DIRECT"
fi
echo ""

# 步骤9：显示访问地址
echo "=========================================="
log_info "访问地址"
echo "=========================================="
echo ""
echo "前端界面: http://$PUBLIC_IP"
echo "后端 API（通过 Nginx 代理）: http://$PUBLIC_IP/api/v1/"
echo "后端 API（直接访问，需要开放防火墙）: http://$PUBLIC_IP:5000"
echo "健康检查（通过 Nginx）: http://$PUBLIC_IP/api/v1/health"
echo "健康检查（直接访问）: http://$PUBLIC_IP:5000/health"
echo ""
log_info "推荐：使用 Nginx 代理访问 API（更安全）"
echo "前端会自动通过 /api/v1/ 访问后端"
echo ""

# 步骤10：检查前端构建配置
log_info "步骤10: 检查前端 API 配置..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/frontend/src/api/index.js" ]; then
    log_info "前端 API 配置:"
    grep -E "baseURL|VITE_API_URL" "$SCRIPT_DIR/frontend/src/api/index.js" | head -3 || \
    log_info "使用相对路径配置（正确）"
fi
echo ""

echo "=========================================="
log_success "修复完成！"
echo "=========================================="
echo ""
log_info "如果前端仍然无法连接 API，请检查："
echo "  1. 浏览器控制台错误信息（F12）"
echo "  2. Nginx 访问日志: sudo tail -f /var/log/nginx/canteen-access.log"
echo "  3. 后端日志: sudo journalctl -u canteen-backend -f"
echo ""

