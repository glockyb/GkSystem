#!/bin/bash
# 立即修复 MySQL 认证问题

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
log_info "立即修复 MySQL 认证问题"
echo "=========================================="
echo ""

# 步骤1：修改 MySQL root 用户
log_info "步骤1: 修改 MySQL root 用户使用密码认证..."
$SUDO mysql <<'SQL'
-- 修改 root 用户使用密码认证
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';
FLUSH PRIVILEGES;

-- 验证修改
SELECT user, host, plugin FROM mysql.user WHERE user='root';
SQL

if [ $? -eq 0 ]; then
    log_success "MySQL root 用户已修改"
else
    log_error "修改失败"
    exit 1
fi
echo ""

# 步骤2：测试 MySQL 连接
log_info "步骤2: 测试 MySQL 连接..."
if mysql -u root -ppassword -e "SELECT 1;" 2>/dev/null; then
    log_success "MySQL 连接成功"
else
    log_error "MySQL 连接失败"
    exit 1
fi
echo ""

# 步骤3：检查并更新后端服务配置
log_info "步骤3: 更新后端服务配置..."
SERVICE_FILE="/etc/systemd/system/canteen-backend.service"

if [ ! -f "$SERVICE_FILE" ]; then
    log_error "服务文件不存在: $SERVICE_FILE"
    exit 1
fi

# 备份
$SUDO cp "$SERVICE_FILE" "${SERVICE_FILE}.bak.$(date +%Y%m%d_%H%M%S)"

# 检查是否已有 MySQL 环境变量
if grep -q "MYSQL_PASSWORD" "$SERVICE_FILE"; then
    log_info "服务配置已包含 MySQL 环境变量"
    log_info "确保密码正确..."
    # 更新密码（如果不同）
    $SUDO sed -i 's|Environment="MYSQL_PASSWORD=.*"|Environment="MYSQL_PASSWORD=password"|g' "$SERVICE_FILE"
    $SUDO sed -i 's|Environment="MYSQL_USER=.*"|Environment="MYSQL_USER=root"|g' "$SERVICE_FILE"
else
    log_info "添加 MySQL 环境变量到服务配置..."
    
    # 在 Environment="FLASK_DEBUG=False" 之后添加
    $SUDO sed -i '/Environment="FLASK_DEBUG=False"/a\
Environment="MYSQL_HOST=localhost"\
Environment="MYSQL_PORT=3306"\
Environment="MYSQL_USER=root"\
Environment="MYSQL_PASSWORD=password"\
Environment="MYSQL_DATABASE=canteen_recommendation"\
Environment="REDIS_HOST=localhost"\
Environment="REDIS_PORT=6379"\
Environment="REDIS_DB=0"
' "$SERVICE_FILE"
fi

log_success "服务配置已更新"
echo ""

# 步骤4：显示当前配置
log_info "步骤4: 当前服务配置（MySQL 相关）..."
$SUDO grep -E "MYSQL_|REDIS_" "$SERVICE_FILE" || log_warning "未找到数据库配置"
echo ""

# 步骤5：重新加载 systemd
log_info "步骤5: 重新加载 systemd..."
$SUDO systemctl daemon-reload
log_success "systemd 已重新加载"
echo ""

# 步骤6：重启后端服务
log_info "步骤6: 重启后端服务..."
$SUDO systemctl restart canteen-backend
sleep 5

if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务运行中"
else
    log_error "后端服务启动失败"
    log_info "查看日志..."
    $SUDO journalctl -u canteen-backend -n 30 --no-pager
    exit 1
fi
echo ""

# 步骤7：等待服务完全启动
log_info "步骤7: 等待服务完全启动..."
sleep 3
echo ""

# 步骤8：测试 API
log_info "步骤8: 测试 API..."
echo ""

echo "测试健康检查:"
HEALTH=$(curl -s http://localhost:5000/health 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    log_success "健康检查: $HEALTH"
else
    log_error "健康检查失败: $HEALTH"
fi

echo ""
echo "测试 API 端点:"
API_TEST=$(curl -s http://localhost:5000/api/v1/dishes/categories 2>&1)
if echo "$API_TEST" | grep -q "categories"; then
    log_success "✅ API 正常"
    echo "响应: $API_TEST" | head -3
elif echo "$API_TEST" | grep -q "error"; then
    log_error "❌ API 返回错误"
    echo "响应: $API_TEST"
    echo ""
    log_info "查看后端日志..."
    $SUDO journalctl -u canteen-backend -n 20 --no-pager | grep -i error | tail -5
else
    log_warning "API 响应: $API_TEST"
fi
echo ""

# 步骤9：检查日志
log_info "步骤9: 检查后端日志（最近错误）..."
RECENT_ERRORS=$($SUDO journalctl -u canteen-backend -n 50 --no-pager | grep -i "error\|denied" | tail -5)
if [ -n "$RECENT_ERRORS" ]; then
    log_warning "发现错误:"
    echo "$RECENT_ERRORS"
else
    log_success "未发现错误"
fi
echo ""

echo "=========================================="
log_success "修复完成"
echo "=========================================="
echo ""
log_info "如果问题仍然存在，请："
echo "  1. 确认 MySQL root 用户已修改: sudo mysql -e \"SELECT user, host, plugin FROM mysql.user WHERE user='root';\""
echo "  2. 确认服务配置正确: sudo cat /etc/systemd/system/canteen-backend.service | grep MYSQL"
echo "  3. 查看详细日志: sudo journalctl -u canteen-backend -f"
echo "=========================================="

