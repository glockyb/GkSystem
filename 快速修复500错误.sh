#!/bin/bash
# 快速修复后端 500 错误

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
log_info "快速修复后端 500 错误"
echo "=========================================="
echo ""

# 步骤1：查看后端日志（最重要）
log_info "步骤1: 查看后端日志（最近 30 行）..."
echo "----------------------------------------"
$SUDO journalctl -u canteen-backend -n 30 --no-pager | tail -30
echo "----------------------------------------"
echo ""

# 步骤2：检查并启动 MySQL
log_info "步骤2: 检查 MySQL..."
if $SUDO systemctl is-active mysql >/dev/null 2>&1 || $SUDO systemctl is-active mysqld >/dev/null 2>&1; then
    log_success "MySQL 运行中"
else
    log_warning "MySQL 未运行，启动..."
    $SUDO systemctl start mysql 2>/dev/null || $SUDO systemctl start mysqld 2>/dev/null
    sleep 3
fi
echo ""

# 步骤3：检查数据库是否存在
log_info "步骤3: 检查数据库..."
cd "$SCRIPT_DIR/backend"

# 尝试读取数据库配置
DB_NAME="canteen_recommendation"
DB_USER="root"
DB_PASSWORD="password"

if [ -f "config.py" ]; then
    # 从配置文件读取（简单提取）
    DB_NAME=$(grep -E "MYSQL_DATABASE|database" config.py | head -1 | grep -oE "'[^']+'" | tr -d "'" | tail -1 || echo "canteen_recommendation")
    DB_USER=$(grep -E "MYSQL_USER|user" config.py | head -1 | grep -oE "'[^']+'" | tr -d "'" | tail -1 || echo "root")
fi

log_info "数据库: $DB_NAME, 用户: $DB_USER"

# 检查数据库是否存在
if command -v mysql >/dev/null 2>&1; then
    if mysql -u "$DB_USER" -e "USE $DB_NAME; SELECT 1;" 2>/dev/null; then
        log_success "数据库存在且可访问"
        
        # 检查表是否存在
        TABLE_COUNT=$(mysql -u "$DB_USER" -e "USE $DB_NAME; SHOW TABLES;" 2>/dev/null | wc -l)
        if [ "$TABLE_COUNT" -lt 2 ]; then
            log_warning "数据库表可能未初始化"
            log_info "需要运行数据库初始化脚本"
        else
            log_success "数据库表存在 ($TABLE_COUNT 个表)"
        fi
    else
        log_error "数据库不存在或无法访问"
        log_info "需要创建数据库并初始化"
        log_info "运行: mysql -u root -p < backend/database/init.sql"
    fi
else
    log_warning "mysql 命令不可用，跳过数据库检查"
fi
echo ""

# 步骤4：检查 Redis（可选）
log_info "步骤4: 检查 Redis（可选）..."
if $SUDO systemctl is-active redis >/dev/null 2>&1 || $SUDO systemctl is-active redis-server >/dev/null 2>&1; then
    log_success "Redis 运行中"
else
    log_warning "Redis 未运行（可能不是必需的）"
fi
echo ""

# 步骤5：重启后端服务
log_info "步骤5: 重启后端服务..."
$SUDO systemctl restart canteen-backend
sleep 5

if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务运行中"
else
    log_error "后端服务启动失败"
    log_info "查看日志..."
    $SUDO journalctl -u canteen-backend -n 50 --no-pager
    exit 1
fi
echo ""

# 步骤6：测试 API
log_info "步骤6: 测试 API..."
sleep 3

echo "健康检查:"
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
API_BODY=$(echo "$API_TEST" | grep -v "HTTP_CODE" | head -5)

if [ "$API_CODE" = "200" ]; then
    log_success "✅ API 正常 (HTTP $API_CODE)"
    echo "响应: $API_BODY"
elif [ "$API_CODE" = "500" ]; then
    log_error "❌ API 仍返回 500"
    echo "错误: $API_BODY"
    echo ""
    log_info "请查看详细错误日志:"
    echo "  sudo journalctl -u canteen-backend -n 100 | grep -i error"
else
    log_warning "API 返回 HTTP $API_CODE"
    echo "响应: $API_BODY"
fi
echo ""

echo "=========================================="
log_info "修复完成"
echo "=========================================="
echo ""
log_info "如果仍然返回 500，请："
echo "  1. 查看详细日志: sudo journalctl -u canteen-backend -n 100"
echo "  2. 检查数据库是否初始化: mysql -u root -p < backend/database/init.sql"
echo "  3. 检查数据库配置: cat backend/config.py"
echo "=========================================="

