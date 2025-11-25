#!/bin/bash
# 诊断后端 500 错误

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
log_info "诊断后端 500 错误"
echo "=========================================="
echo ""

# 步骤1：检查后端服务状态
log_info "步骤1: 检查后端服务状态..."
if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务运行中"
    $SUDO systemctl status canteen-backend --no-pager -l | head -15
else
    log_error "后端服务未运行"
    log_info "尝试启动..."
    $SUDO systemctl start canteen-backend
    sleep 3
    if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
        log_success "后端服务已启动"
    else
        log_error "后端服务启动失败"
    fi
fi
echo ""

# 步骤2：查看后端日志（最近的错误）
log_info "步骤2: 查看后端日志（最近 50 行）..."
echo "----------------------------------------"
$SUDO journalctl -u canteen-backend -n 50 --no-pager | tail -30
echo "----------------------------------------"
echo ""

# 步骤3：测试后端 API（本地）
log_info "步骤3: 测试后端 API（本地）..."
echo "测试健康检查:"
HEALTH_RESPONSE=$(curl -s http://localhost:5000/health 2>&1 || echo "ERROR")
if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    log_success "健康检查正常: $HEALTH_RESPONSE"
else
    log_error "健康检查失败: $HEALTH_RESPONSE"
fi

echo ""
echo "测试 API 端点:"
API_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:5000/api/v1/dishes/categories 2>&1 || echo "ERROR")
HTTP_CODE=$(echo "$API_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$API_RESPONSE" | grep -v "HTTP_CODE")

if [ "$HTTP_CODE" = "200" ]; then
    log_success "API 端点正常 (HTTP $HTTP_CODE)"
    echo "响应: $BODY" | head -3
else
    log_error "API 端点返回 HTTP $HTTP_CODE"
    echo "响应: $BODY" | head -10
fi
echo ""

# 步骤4：检查数据库连接
log_info "步骤4: 检查数据库连接..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/backend"

# 检查 MySQL 服务
if $SUDO systemctl is-active mysql >/dev/null 2>&1 || $SUDO systemctl is-active mysqld >/dev/null 2>&1; then
    log_success "MySQL 服务运行中"
else
    log_error "MySQL 服务未运行"
fi

# 尝试连接数据库
if command -v mysql >/dev/null 2>&1; then
    if [ -f "config.py" ]; then
        # 尝试读取数据库配置
        DB_HOST=$(grep -E "MYSQL_HOST|host" config.py | head -1 | grep -oE "'[^']+'" | tr -d "'" || echo "localhost")
        DB_USER=$(grep -E "MYSQL_USER|user" config.py | head -1 | grep -oE "'[^']+'" | tr -d "'" || echo "root")
        DB_NAME=$(grep -E "MYSQL_DB|database" config.py | head -1 | grep -oE "'[^']+'" | tr -d "'" || echo "canteen")
        
        log_info "尝试连接数据库: $DB_USER@$DB_HOST/$DB_NAME"
        if mysql -h "$DB_HOST" -u "$DB_USER" -e "USE $DB_NAME; SELECT 1;" 2>/dev/null; then
            log_success "数据库连接正常"
        else
            log_warning "数据库连接失败（可能需要密码）"
        fi
    fi
fi
echo ""

# 步骤5：检查 Redis 连接
log_info "步骤5: 检查 Redis 连接..."
if $SUDO systemctl is-active redis >/dev/null 2>&1 || $SUDO systemctl is-active redis-server >/dev/null 2>&1; then
    log_success "Redis 服务运行中"
    if command -v redis-cli >/dev/null 2>&1; then
        if redis-cli ping >/dev/null 2>&1; then
            log_success "Redis 连接正常"
        else
            log_warning "Redis 连接失败"
        fi
    fi
else
    log_warning "Redis 服务未运行（可能不是必需的）"
fi
echo ""

# 步骤6：检查 Python 环境和依赖
log_info "步骤6: 检查 Python 环境..."
if [ -d "../venv" ]; then
    log_info "虚拟环境存在"
    if [ -f "../venv/bin/python3" ]; then
        PYTHON_VERSION=$("../venv/bin/python3" --version 2>&1)
        log_info "Python 版本: $PYTHON_VERSION"
        
        # 检查关键依赖
        log_info "检查关键依赖..."
        if "../venv/bin/python3" -c "import flask" 2>/dev/null; then
            log_success "Flask 已安装"
        else
            log_error "Flask 未安装"
        fi
        
        if "../venv/bin/python3" -c "import pandas" 2>/dev/null; then
            log_success "pandas 已安装"
        else
            log_error "pandas 未安装"
        fi
        
        if "../venv/bin/python3" -c "import pymysql" 2>/dev/null; then
            log_success "pymysql 已安装"
        else
            log_error "pymysql 未安装"
        fi
    fi
else
    log_warning "虚拟环境不存在"
fi
echo ""

# 步骤7：检查后端配置文件
log_info "步骤7: 检查后端配置..."
if [ -f "config.py" ]; then
    log_success "配置文件存在"
    log_info "配置内容:"
    grep -E "MYSQL_|REDIS_|SECRET" config.py | head -5
else
    log_error "配置文件不存在"
fi
echo ""

# 步骤8：测试 Nginx 代理
log_info "步骤8: 测试 Nginx 代理..."
PROXY_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost/api/v1/dishes/categories 2>&1 || echo "ERROR")
PROXY_HTTP_CODE=$(echo "$PROXY_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
PROXY_BODY=$(echo "$PROXY_RESPONSE" | grep -v "HTTP_CODE")

if [ "$PROXY_HTTP_CODE" = "200" ]; then
    log_success "Nginx 代理正常 (HTTP $PROXY_HTTP_CODE)"
elif [ "$PROXY_HTTP_CODE" = "500" ]; then
    log_error "Nginx 代理返回 500（后端错误）"
    echo "响应: $PROXY_BODY" | head -10
else
    log_warning "Nginx 代理返回 HTTP $PROXY_HTTP_CODE"
    echo "响应: $PROXY_BODY" | head -10
fi
echo ""

# 步骤9：查看 Nginx 错误日志
log_info "步骤9: 查看 Nginx 错误日志（最近 20 行）..."
if [ -f "/var/log/nginx/canteen-error.log" ]; then
    echo "----------------------------------------"
    $SUDO tail -20 /var/log/nginx/canteen-error.log
    echo "----------------------------------------"
elif [ -f "/var/log/nginx/error.log" ]; then
    echo "----------------------------------------"
    $SUDO tail -20 /var/log/nginx/error.log | grep -i "canteen\|500" || $SUDO tail -20 /var/log/nginx/error.log
    echo "----------------------------------------"
else
    log_warning "Nginx 错误日志文件不存在"
fi
echo ""

# 步骤10：实时查看后端日志
log_info "步骤10: 实时查看后端日志（按 Ctrl+C 退出）..."
echo ""
log_warning "按 Ctrl+C 退出实时日志查看"
echo "----------------------------------------"
$SUDO journalctl -u canteen-backend -f --no-pager

