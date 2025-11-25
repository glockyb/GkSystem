#!/bin/bash
# 最终验证修复是否成功

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
log_info "最终验证修复是否成功"
echo "=========================================="
echo ""

# 步骤1：验证 MySQL 配置
log_info "步骤1: 验证 MySQL 配置..."
if mysql -u root -ppassword -e "SELECT 1;" 2>/dev/null; then
    log_success "MySQL 密码认证正常"
else
    log_error "MySQL 密码认证失败"
    exit 1
fi

# 检查 root 用户认证方式
MYSQL_PLUGIN=$(mysql -u root -ppassword -e "SELECT plugin FROM mysql.user WHERE user='root' AND host='localhost';" 2>/dev/null | tail -1)
if [ "$MYSQL_PLUGIN" = "mysql_native_password" ]; then
    log_success "MySQL root 用户使用密码认证"
else
    log_warning "MySQL root 用户认证方式: $MYSQL_PLUGIN"
fi
echo ""

# 步骤2：验证服务配置
log_info "步骤2: 验证服务配置..."
if grep -q "MYSQL_PASSWORD=password" /etc/systemd/system/canteen-backend.service; then
    log_success "服务配置包含 MySQL 密码"
else
    log_error "服务配置缺少 MySQL 密码"
    exit 1
fi
echo ""

# 步骤3：重启服务（确保使用新配置）
log_info "步骤3: 重启后端服务..."
$SUDO systemctl daemon-reload
$SUDO systemctl restart canteen-backend
sleep 5

if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务运行中"
else
    log_error "后端服务未运行"
    $SUDO journalctl -u canteen-backend -n 30 --no-pager
    exit 1
fi
echo ""

# 步骤4：检查数据库是否存在
log_info "步骤4: 检查数据库..."
DB_NAME="canteen_recommendation"
if mysql -u root -ppassword -e "USE $DB_NAME; SELECT 1;" 2>/dev/null; then
    log_success "数据库存在: $DB_NAME"
    
    # 检查表
    TABLE_COUNT=$(mysql -u root -ppassword -e "USE $DB_NAME; SHOW TABLES;" 2>/dev/null | wc -l)
    if [ "$TABLE_COUNT" -gt 1 ]; then
        log_success "数据库表存在 ($((TABLE_COUNT-1)) 个表)"
        
        # 检查 dishes 表
        if mysql -u root -ppassword -e "USE $DB_NAME; SELECT COUNT(*) FROM dishes;" 2>/dev/null >/dev/null; then
            DISH_COUNT=$(mysql -u root -ppassword -e "USE $DB_NAME; SELECT COUNT(*) FROM dishes;" 2>/dev/null | tail -1)
            log_info "dishes 表中有 $DISH_COUNT 条记录"
        else
            log_warning "dishes 表可能不存在或为空"
        fi
    else
        log_warning "数据库表可能未初始化"
        log_info "需要运行: mysql -u root -ppassword < backend/database/init.sql"
    fi
else
    log_warning "数据库不存在或无法访问"
    log_info "需要创建数据库"
fi
echo ""

# 步骤5：测试 API
log_info "步骤5: 测试 API..."
sleep 3

echo "测试健康检查:"
HEALTH=$(curl -s http://localhost:5000/health 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    log_success "健康检查: $HEALTH"
else
    log_error "健康检查失败: $HEALTH"
fi

echo ""
echo "测试 API 端点 /api/v1/dishes/categories:"
API_RESPONSE=$(curl -s http://localhost:5000/api/v1/dishes/categories 2>&1)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/v1/dishes/categories 2>&1)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "✅ API 正常 (HTTP $HTTP_CODE)"
    echo "响应: $API_RESPONSE" | head -5
elif echo "$API_RESPONSE" | grep -q "categories"; then
    log_success "✅ API 正常（返回数据）"
    echo "响应: $API_RESPONSE" | head -5
elif echo "$API_RESPONSE" | grep -qi "error"; then
    log_error "❌ API 返回错误"
    echo "响应: $API_RESPONSE"
    echo "HTTP 状态码: $HTTP_CODE"
else
    log_warning "API 响应异常"
    echo "响应: $API_RESPONSE"
    echo "HTTP 状态码: $HTTP_CODE"
fi
echo ""

# 步骤6：检查后端日志
log_info "步骤6: 检查后端日志（最近错误）..."
RECENT_ERRORS=$($SUDO journalctl -u canteen-backend -n 50 --no-pager | grep -i "error\|denied\|exception" | tail -10)
if [ -n "$RECENT_ERRORS" ]; then
    log_warning "发现错误日志:"
    echo "$RECENT_ERRORS"
    echo ""
    
    # 检查是否是认证错误
    if echo "$RECENT_ERRORS" | grep -qi "access denied\|1698"; then
        log_error "仍然存在 MySQL 认证错误"
        log_info "可能需要再次修改 MySQL root 用户"
    fi
else
    log_success "未发现错误日志"
fi
echo ""

# 步骤7：测试通过 Nginx 代理访问
log_info "步骤7: 测试通过 Nginx 代理访问..."
NGINX_RESPONSE=$(curl -s http://localhost/api/v1/dishes/categories 2>&1)
NGINX_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/v1/dishes/categories 2>&1)

if [ "$NGINX_CODE" = "200" ]; then
    log_success "✅ Nginx 代理正常 (HTTP $NGINX_CODE)"
    echo "响应: $NGINX_RESPONSE" | head -5
elif echo "$NGINX_RESPONSE" | grep -q "categories"; then
    log_success "✅ Nginx 代理正常（返回数据）"
    echo "响应: $NGINX_RESPONSE" | head -5
else
    log_warning "Nginx 代理返回 HTTP $NGINX_CODE"
    echo "响应: $NGINX_RESPONSE" | head -5
fi
echo ""

echo "=========================================="
log_info "验证完成"
echo "=========================================="
echo ""
log_info "总结:"
echo "  - MySQL 配置: ✅"
echo "  - 服务配置: ✅"
echo "  - 后端服务: ✅"
echo ""
log_info "如果 API 仍然返回错误，请："
echo "  1. 检查数据库是否已初始化"
echo "  2. 查看详细日志: sudo journalctl -u canteen-backend -f"
echo "  3. 在前端浏览器中测试（清除缓存）"
echo "=========================================="

