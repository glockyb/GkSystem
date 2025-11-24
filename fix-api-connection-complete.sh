#!/bin/bash
# 完整修复前端 API 连接问题

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
log_info "完整修复前端 API 连接问题"
echo "=========================================="
echo ""

# 步骤1：检查后端服务
log_info "步骤1: 检查后端服务..."
if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务运行中"
else
    log_error "后端服务未运行，启动服务..."
    $SUDO systemctl start canteen-backend
    sleep 5
    if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
        log_success "后端服务已启动"
    else
        log_error "后端服务启动失败"
        $SUDO journalctl -u canteen-backend -n 30 --no-pager
        exit 1
    fi
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
    $SUDO journalctl -u canteen-backend -n 30 --no-pager
    exit 1
fi
echo ""

# 步骤3：检查并修复 Nginx API 代理配置
log_info "步骤3: 检查 Nginx API 代理配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

# 备份
$SUDO cp "$NGINX_CONFIG" "${NGINX_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"

# 检查配置
if ! grep -q "location /api" "$NGINX_CONFIG"; then
    log_warning "API 代理配置不存在，添加配置..."
    
    # 在 location / 之后添加
    $SUDO sed -i '/location \/ {/,/}/ {
        /}/ i\
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
    }' "$NGINX_CONFIG"
else
    log_info "API 代理配置存在，检查配置..."
    API_CONFIG=$(grep -A 10 "location /api" "$NGINX_CONFIG")
    log_info "当前配置:"
    echo "$API_CONFIG" | head -10
    
    # 检查 proxy_pass 是否正确
    if ! echo "$API_CONFIG" | grep -q "proxy_pass.*127.0.0.1:5000"; then
        log_warning "proxy_pass 配置可能不正确，修复..."
        $SUDO sed -i 's|proxy_pass.*5000.*|proxy_pass http://127.0.0.1:5000/api;|g' "$NGINX_CONFIG"
    fi
fi
echo ""

# 步骤4：验证 Nginx 配置
log_info "步骤4: 验证 Nginx 配置..."
if $SUDO nginx -t 2>&1; then
    log_success "配置正确"
else
    log_error "配置有错误"
    $SUDO nginx -t
    exit 1
fi
echo ""

# 步骤5：重启 Nginx
log_info "步骤5: 重启 Nginx..."
$SUDO systemctl restart nginx
sleep 3

if $SUDO systemctl is-active nginx >/dev/null 2>&1; then
    log_success "Nginx 已重启"
else
    log_error "Nginx 启动失败"
    exit 1
fi
echo ""

# 步骤6：测试 API 代理
log_info "步骤6: 测试 API 代理..."
sleep 2

# 测试健康检查
if curl -s http://localhost/api/v1/health >/dev/null 2>&1 || \
   curl -s http://localhost/health >/dev/null 2>&1; then
    RESPONSE=$(curl -s http://localhost/api/v1/health 2>/dev/null || curl -s http://localhost/health 2>/dev/null)
    log_success "API 代理正常: $RESPONSE"
else
    log_warning "API 代理测试失败，检查配置..."
    curl -v http://localhost/api/v1/ 2>&1 | head -30
fi
echo ""

# 步骤7：检查防火墙
log_info "步骤7: 检查防火墙..."
PUBLIC_IP=$(hostname -I | awk '{print $1}')

if command -v ufw >/dev/null 2>&1; then
    if $SUDO ufw status | grep -q "Status: active"; then
        log_info "UFW 防火墙运行中"
        
        # 检查端口
        if $SUDO ufw status | grep -q "5000"; then
            log_info "端口 5000 已配置"
        else
            log_warning "端口 5000 未开放（外部无法直接访问后端）"
            log_info "注意：如果使用 Nginx 代理，不需要开放 5000 端口"
        fi
        
        # 确保 80 端口开放
        if $SUDO ufw status | grep -q "80"; then
            log_success "端口 80 已开放"
        else
            log_warning "端口 80 未开放"
            $SUDO ufw allow 80/tcp
            log_success "端口 80 已开放"
        fi
    fi
fi
echo ""

# 步骤8：测试完整流程
log_info "步骤8: 测试完整访问流程..."
sleep 2

echo "测试前端:"
HTTP_CODE_FRONTEND=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE_FRONTEND" = "200" ]; then
    log_success "前端访问正常 (HTTP $HTTP_CODE_FRONTEND)"
else
    log_warning "前端返回 HTTP $HTTP_CODE_FRONTEND"
fi

echo ""
echo "测试 API 代理:"
HTTP_CODE_API=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/v1/ 2>/dev/null || echo "000")
API_RESPONSE=$(curl -s http://localhost/api/v1/ 2>/dev/null | head -1)

if [ "$HTTP_CODE_API" = "200" ] || [ "$HTTP_CODE_API" = "404" ] || [ "$HTTP_CODE_API" = "401" ]; then
    log_success "API 代理正常 (HTTP $HTTP_CODE_API)"
    log_info "响应: $API_RESPONSE"
    log_info "注意：404/401 是正常的，说明代理工作正常"
else
    log_error "API 代理返回 HTTP $HTTP_CODE_API"
    log_info "查看 Nginx 错误日志..."
    $SUDO tail -20 /var/log/nginx/error.log 2>/dev/null || \
    $SUDO tail -20 /var/log/nginx/canteen-error.log 2>/dev/null
fi

echo ""
echo "测试后端直连（本地）:"
if curl -s http://localhost:5000/health >/dev/null 2>&1; then
    RESPONSE=$(curl -s http://localhost:5000/health)
    log_success "后端直连正常: $RESPONSE"
else
    log_error "后端直连失败"
fi
echo ""

# 步骤9：显示访问信息
echo "=========================================="
log_info "访问信息"
echo "=========================================="
echo ""
echo "✅ 前端界面: http://$PUBLIC_IP"
echo "✅ 后端 API（通过 Nginx 代理）: http://$PUBLIC_IP/api/v1/"
echo "⚠️  后端 API（直接访问）: http://$PUBLIC_IP:5000（需要开放防火墙）"
echo ""
log_info "前端会自动通过 /api/v1/ 访问后端"
log_info "无需直接访问后端端口 5000"
echo ""

# 步骤10：检查前端构建
log_info "步骤10: 检查前端构建..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRONTEND_DIST="/var/www/canteen"

if [ -f "$FRONTEND_DIST/index.html" ]; then
    log_success "前端文件存在"
    
    # 检查是否有 API 相关的 JS 文件
    if find "$FRONTEND_DIST" -name "*.js" -type f | head -1 >/dev/null; then
        log_success "前端 JS 文件存在"
        
        # 检查是否包含错误的 API 地址
        if find "$FRONTEND_DIST" -name "*.js" -exec grep -l "localhost:5000\|127.0.0.1:5000\|http://.*:5000" {} \; 2>/dev/null | head -1; then
            log_warning "前端 JS 中可能包含错误的 API 地址"
            log_info "需要重新构建前端（不使用 VITE_API_URL）"
        else
            log_success "前端使用相对路径配置（正确）"
        fi
    fi
else
    log_error "前端文件不存在"
fi
echo ""

echo "=========================================="
log_success "修复完成！"
echo "=========================================="
echo ""
log_info "如果前端仍然无法连接 API，请："
echo "  1. 打开浏览器开发者工具（F12）"
echo "  2. 查看 Console 和 Network 标签"
echo "  3. 尝试注册/登录，查看错误信息"
echo "  4. 检查请求 URL 是否正确（应该是 /api/v1/...）"
echo ""
log_info "查看实时日志："
echo "  Nginx 访问日志: sudo tail -f /var/log/nginx/canteen-access.log"
echo "  后端日志: sudo journalctl -u canteen-backend -f"
echo "=========================================="

