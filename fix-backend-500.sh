#!/bin/bash
# 修复后端 500 错误

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

echo "=========================================="
log_info "修复后端 500 错误"
echo "=========================================="
echo ""

# 步骤1：检查并启动 MySQL
log_info "步骤1: 检查 MySQL 服务..."
if $SUDO systemctl is-active mysql >/dev/null 2>&1 || $SUDO systemctl is-active mysqld >/dev/null 2>&1; then
    log_success "MySQL 服务运行中"
else
    log_warning "MySQL 服务未运行，启动..."
    $SUDO systemctl start mysql 2>/dev/null || $SUDO systemctl start mysqld 2>/dev/null
    sleep 3
    if $SUDO systemctl is-active mysql >/dev/null 2>&1 || $SUDO systemctl is-active mysqld >/dev/null 2>&1; then
        log_success "MySQL 服务已启动"
    else
        log_error "MySQL 服务启动失败"
    fi
fi
echo ""

# 步骤2：检查并启动 Redis
log_info "步骤2: 检查 Redis 服务..."
if $SUDO systemctl is-active redis >/dev/null 2>&1 || $SUDO systemctl is-active redis-server >/dev/null 2>&1; then
    log_success "Redis 服务运行中"
else
    log_warning "Redis 服务未运行，启动..."
    $SUDO systemctl start redis 2>/dev/null || $SUDO systemctl start redis-server 2>/dev/null
    sleep 2
    if $SUDO systemctl is-active redis >/dev/null 2>&1 || $SUDO systemctl is-active redis-server >/dev/null 2>&1; then
        log_success "Redis 服务已启动"
    else
        log_warning "Redis 服务启动失败（可能不是必需的）"
    fi
fi
echo ""

# 步骤3：检查后端服务
log_info "步骤3: 检查后端服务..."
if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_info "后端服务运行中，重启以应用修复..."
    $SUDO systemctl restart canteen-backend
    sleep 5
else
    log_warning "后端服务未运行，启动..."
    $SUDO systemctl start canteen-backend
    sleep 5
fi

if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务运行中"
else
    log_error "后端服务启动失败"
    log_info "查看日志..."
    $SUDO journalctl -u canteen-backend -n 30 --no-pager
    exit 1
fi
echo ""

# 步骤4：检查后端日志中的错误
log_info "步骤4: 检查后端日志（最近错误）..."
RECENT_ERRORS=$($SUDO journalctl -u canteen-backend -n 50 --no-pager | grep -i "error\|exception\|traceback\|failed" | head -10)
if [ -n "$RECENT_ERRORS" ]; then
    log_warning "发现错误日志:"
    echo "$RECENT_ERRORS"
    echo ""
    
    # 检查常见错误
    if echo "$RECENT_ERRORS" | grep -qi "database\|mysql\|connection"; then
        log_warning "可能是数据库连接问题"
        log_info "检查数据库配置和连接..."
    fi
    
    if echo "$RECENT_ERRORS" | grep -qi "module\|import"; then
        log_warning "可能是 Python 模块缺失"
        log_info "检查 Python 依赖..."
    fi
else
    log_info "未发现明显错误"
fi
echo ""

# 步骤5：测试后端 API
log_info "步骤5: 测试后端 API..."
sleep 2

HEALTH_RESPONSE=$(curl -s http://localhost:5000/health 2>&1 || echo "ERROR")
if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    log_success "健康检查正常: $HEALTH_RESPONSE"
else
    log_error "健康检查失败: $HEALTH_RESPONSE"
    log_info "查看详细日志..."
    $SUDO journalctl -u canteen-backend -n 50 --no-pager
    exit 1
fi

echo ""
log_info "测试 API 端点..."
API_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:5000/api/v1/dishes/categories 2>&1 || echo "ERROR")
HTTP_CODE=$(echo "$API_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$API_RESPONSE" | grep -v "HTTP_CODE" | head -5)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "API 端点正常 (HTTP $HTTP_CODE)"
elif [ "$HTTP_CODE" = "500" ]; then
    log_error "API 端点返回 500"
    echo "错误响应: $BODY"
    echo ""
    log_info "查看后端详细日志..."
    $SUDO journalctl -u canteen-backend -n 100 --no-pager | tail -50
else
    log_warning "API 端点返回 HTTP $HTTP_CODE"
    echo "响应: $BODY"
fi
echo ""

# 步骤6：检查数据库初始化
log_info "步骤6: 检查数据库初始化..."
cd "$SCRIPT_DIR/backend"

if [ -f "database/init.sql" ]; then
    log_info "数据库初始化脚本存在"
    log_info "如果数据库未初始化，请运行:"
    echo "  cd backend"
    echo "  mysql -u root -p < database/init.sql"
else
    log_warning "数据库初始化脚本不存在"
fi
echo ""

# 步骤7：检查 Python 依赖
log_info "步骤7: 检查 Python 依赖..."
if [ -d "../venv" ] && [ -f "../venv/bin/python3" ]; then
    log_info "检查关键依赖..."
    
    MISSING_DEPS=()
    
    for dep in flask pandas pymysql redis flask-cors flask-jwt-extended scikit-learn numpy scikit-surprise; do
        if ! "../venv/bin/python3" -c "import ${dep//-/_}" 2>/dev/null; then
            MISSING_DEPS+=("$dep")
        fi
    done
    
    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        log_success "所有关键依赖已安装"
    else
        log_error "缺少依赖: ${MISSING_DEPS[*]}"
        log_info "重新安装依赖..."
        cd "$SCRIPT_DIR/backend"
        if [ -f "requirements.txt" ]; then
            ../venv/bin/pip3 install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple || \
            ../venv/bin/pip3 install -r requirements.txt
            log_success "依赖安装完成"
        fi
    fi
else
    log_warning "虚拟环境不存在或 Python 不可用"
fi
echo ""

# 步骤8：重新启动后端服务
log_info "步骤8: 重新启动后端服务..."
$SUDO systemctl restart canteen-backend
sleep 5

if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务已重启"
else
    log_error "后端服务重启失败"
    $SUDO journalctl -u canteen-backend -n 50 --no-pager
    exit 1
fi
echo ""

# 步骤9：最终测试
log_info "步骤9: 最终测试..."
sleep 3

echo "测试健康检查:"
HEALTH=$(curl -s http://localhost:5000/health 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    log_success "健康检查: $HEALTH"
else
    log_error "健康检查失败: $HEALTH"
fi

echo ""
echo "测试 API 端点:"
API_TEST=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:5000/api/v1/dishes/categories 2>&1)
API_CODE=$(echo "$API_TEST" | grep "HTTP_CODE" | cut -d: -f2)
API_BODY=$(echo "$API_TEST" | grep -v "HTTP_CODE" | head -3)

if [ "$API_CODE" = "200" ]; then
    log_success "API 端点正常 (HTTP $API_CODE)"
    echo "响应预览: $API_BODY"
elif [ "$API_CODE" = "500" ]; then
    log_error "API 端点仍返回 500"
    echo "错误响应: $API_BODY"
    echo ""
    log_info "请查看详细日志:"
    echo "  sudo journalctl -u canteen-backend -n 100"
else
    log_warning "API 端点返回 HTTP $API_CODE"
    echo "响应: $API_BODY"
fi
echo ""

echo "=========================================="
log_info "修复完成"
echo "=========================================="
echo ""
log_info "如果问题仍然存在，请运行诊断脚本:"
echo "  sudo ./diagnose-backend-500.sh"
echo ""
log_info "查看实时日志:"
echo "  sudo journalctl -u canteen-backend -f"
echo "=========================================="

