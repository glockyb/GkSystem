#!/bin/bash
# 诊断 500 错误的脚本

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

echo "=========================================="
log_info "500 错误诊断脚本"
echo "=========================================="
echo ""

# 检查是否为 root
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# 步骤1：检查后端服务状态
log_info "步骤1: 检查后端服务状态..."
if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务运行中"
    $SUDO systemctl status canteen-backend --no-pager -l | head -20
else
    log_error "后端服务未运行"
    log_info "查看服务状态..."
    $SUDO systemctl status canteen-backend --no-pager -l | head -30
fi
echo ""

# 步骤2：查看后端日志
log_info "步骤2: 查看后端最近日志..."
$SUDO journalctl -u canteen-backend -n 50 --no-pager | tail -30
echo ""

# 步骤3：测试后端 API
log_info "步骤3: 测试后端 API..."
if curl -s http://localhost:5000/health >/dev/null 2>&1; then
    log_success "后端 API 可访问（localhost:5000）"
    curl -s http://localhost:5000/health | head -5
else
    log_error "后端 API 不可访问（localhost:5000）"
    log_info "尝试手动测试..."
    curl -v http://localhost:5000/health 2>&1 | head -20
fi
echo ""

# 步骤4：检查 Nginx 状态
log_info "步骤4: 检查 Nginx 状态..."
if $SUDO systemctl is-active nginx >/dev/null 2>&1; then
    log_success "Nginx 运行中"
else
    log_error "Nginx 未运行"
fi
echo ""

# 步骤5：查看 Nginx 错误日志
log_info "步骤5: 查看 Nginx 错误日志（最近 20 行）..."
if [ -f /var/log/nginx/error.log ]; then
    $SUDO tail -20 /var/log/nginx/error.log
else
    log_warning "Nginx 错误日志文件不存在"
fi
echo ""

# 步骤6：检查 Nginx 配置
log_info "步骤6: 检查 Nginx 配置..."
if $SUDO nginx -t 2>&1; then
    log_success "Nginx 配置正确"
else
    log_error "Nginx 配置有错误"
fi
echo ""

# 步骤7：检查前端文件
log_info "步骤7: 检查前端文件..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRONTEND_DIST="$SCRIPT_DIR/frontend/dist"

if [ -d "$FRONTEND_DIST" ]; then
    log_success "前端 dist 目录存在"
    if [ -f "$FRONTEND_DIST/index.html" ]; then
        log_success "index.html 存在"
        ls -lh "$FRONTEND_DIST" | head -10
    else
        log_error "index.html 不存在"
    fi
else
    log_error "前端 dist 目录不存在"
    log_info "需要重新构建前端"
fi
echo ""

# 步骤8：检查后端依赖
log_info "步骤8: 检查后端依赖..."
cd "$SCRIPT_DIR/backend"

if [ -d "venv" ]; then
    source venv/bin/activate
    
    REQUIRED_MODULES=("pandas" "numpy" "flask" "pymysql" "redis")
    ALL_OK=true
    
    for module in "${REQUIRED_MODULES[@]}"; do
        if python3 -c "import $module" 2>/dev/null; then
            log_success "模块已安装: $module"
        else
            log_error "模块缺失: $module"
            ALL_OK=false
        fi
    done
    
    if [ "$ALL_OK" = false ]; then
        log_error "有依赖缺失，需要重新安装"
    fi
else
    log_error "虚拟环境不存在"
fi
echo ""

# 步骤9：检查数据库连接
log_info "步骤9: 检查数据库连接..."
if $SUDO systemctl is-active mysql >/dev/null 2>&1 || $SUDO systemctl is-active mysqld >/dev/null 2>&1; then
    log_success "MySQL 服务运行中"
    
    # 测试数据库连接
    if mysql -u root -e "USE canteen_recommendation; SELECT 1;" >/dev/null 2>&1 || \
       $SUDO mysql -u root -e "USE canteen_recommendation; SELECT 1;" >/dev/null 2>&1; then
        log_success "数据库连接正常"
    else
        log_warning "数据库连接可能有问题"
    fi
else
    log_error "MySQL 服务未运行"
fi
echo ""

# 步骤10：检查 Redis 连接
log_info "步骤10: 检查 Redis 连接..."
if $SUDO systemctl is-active redis-server >/dev/null 2>&1 || $SUDO systemctl is-active redis >/dev/null 2>&1; then
    log_success "Redis 服务运行中"
    
    if redis-cli ping >/dev/null 2>&1; then
        log_success "Redis 连接正常"
    else
        log_warning "Redis 连接可能有问题"
    fi
else
    log_warning "Redis 服务未运行（可选）"
fi
echo ""

# 步骤11：检查端口占用
log_info "步骤11: 检查端口占用..."
if netstat -tuln 2>/dev/null | grep -q ":5000 " || ss -tuln 2>/dev/null | grep -q ":5000 "; then
    log_success "端口 5000 正在监听"
    $SUDO netstat -tulpn 2>/dev/null | grep ":5000 " || $SUDO ss -tulpn 2>/dev/null | grep ":5000 "
else
    log_error "端口 5000 未监听"
fi
echo ""

# 步骤12：手动测试后端启动
log_info "步骤12: 尝试手动启动后端（测试）..."
cd "$SCRIPT_DIR/backend"

if [ -d "venv" ]; then
    source venv/bin/activate
    
    log_info "测试后端导入..."
    if timeout 5 python3 -c "from app import app; print('后端导入成功')" 2>&1; then
        log_success "后端代码可以正常导入"
    else
        log_error "后端代码导入失败"
        python3 -c "from app import app" 2>&1 | head -20
    fi
else
    log_warning "虚拟环境不存在，跳过测试"
fi
echo ""

# 总结
echo "=========================================="
log_info "诊断完成"
echo "=========================================="
echo ""
log_info "常见问题和解决方案："
echo ""
echo "1. 如果后端服务未运行："
echo "   sudo systemctl start canteen-backend"
echo "   sudo systemctl status canteen-backend"
echo ""
echo "2. 如果后端 API 不可访问："
echo "   查看日志: sudo journalctl -u canteen-backend -n 50"
echo "   检查依赖: cd backend && source venv/bin/activate && python3 -c 'import flask'"
echo ""
echo "3. 如果 Nginx 配置错误："
echo "   sudo nginx -t"
echo "   sudo nano /etc/nginx/sites-available/canteen"
echo ""
echo "4. 如果前端文件不存在："
echo "   cd frontend && npm run build"
echo ""
echo "5. 如果数据库连接失败："
echo "   sudo systemctl start mysql"
echo "   mysql -u root -e 'SHOW DATABASES;'"
echo ""
echo "=========================================="

