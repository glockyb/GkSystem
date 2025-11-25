#!/bin/bash
# 修复 MySQL root 用户认证问题

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
log_info "修复 MySQL root 用户认证问题"
echo "=========================================="
echo ""

log_info "问题：MySQL 8.0+ 默认使用 auth_socket 插件"
log_info "解决：修改 root 用户使用密码认证"
echo ""

# 步骤1：检查 MySQL 服务
log_info "步骤1: 检查 MySQL 服务..."
if $SUDO systemctl is-active mysql >/dev/null 2>&1 || $SUDO systemctl is-active mysqld >/dev/null 2>&1; then
    log_success "MySQL 服务运行中"
else
    log_error "MySQL 服务未运行"
    exit 1
fi
echo ""

# 步骤2：尝试使用 sudo 登录 MySQL
log_info "步骤2: 使用 sudo 登录 MySQL..."
log_warning "需要输入 MySQL root 密码（如果已设置）"
echo ""

# 方法1：使用 sudo mysql（推荐）
log_info "方法1: 使用 sudo mysql 登录（无需密码）..."
$SUDO mysql <<'EOF'
-- 检查当前 root 用户认证方式
SELECT user, host, plugin, authentication_string FROM mysql.user WHERE user='root';

-- 修改 root 用户使用密码认证
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';
FLUSH PRIVILEGES;

-- 验证修改
SELECT user, host, plugin FROM mysql.user WHERE user='root';
EOF

if [ $? -eq 0 ]; then
    log_success "root 用户已修改为密码认证"
else
    log_warning "方法1 失败，尝试方法2..."
    
    # 方法2：创建新用户
    log_info "方法2: 创建新的 MySQL 用户..."
    $SUDO mysql <<'EOF'
-- 创建新用户
CREATE USER IF NOT EXISTS 'canteen'@'localhost' IDENTIFIED BY 'canteen123';
GRANT ALL PRIVILEGES ON *.* TO 'canteen'@'localhost';
FLUSH PRIVILEGES;
SELECT user, host FROM mysql.user WHERE user='canteen';
EOF
    
    if [ $? -eq 0 ]; then
        log_success "新用户 'canteen' 已创建"
        log_info "需要修改后端配置使用新用户"
    else
        log_error "创建新用户失败"
        exit 1
    fi
fi
echo ""

# 步骤3：测试连接
log_info "步骤3: 测试 MySQL 连接..."
if mysql -u root -ppassword -e "SELECT 1;" 2>/dev/null; then
    log_success "使用密码连接成功"
    USE_PASSWORD="password"
    USE_USER="root"
elif mysql -u canteen -pcanteen123 -e "SELECT 1;" 2>/dev/null; then
    log_success "使用新用户连接成功"
    USE_PASSWORD="canteen123"
    USE_USER="canteen"
else
    log_warning "密码连接失败，但 sudo mysql 应该可以工作"
    USE_PASSWORD=""
    USE_USER="root"
fi
echo ""

# 步骤4：检查数据库是否存在
log_info "步骤4: 检查数据库..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_NAME="canteen_recommendation"

if [ -f "$SCRIPT_DIR/backend/config.py" ]; then
    DB_NAME=$(grep -E "MYSQL_DATABASE|database" "$SCRIPT_DIR/backend/config.py" | head -1 | grep -oE "'[^']+'" | tr -d "'" | tail -1 || echo "canteen_recommendation")
fi

log_info "数据库名: $DB_NAME"

if [ -n "$USE_PASSWORD" ]; then
    if mysql -u "$USE_USER" -p"$USE_PASSWORD" -e "USE $DB_NAME; SELECT 1;" 2>/dev/null; then
        log_success "数据库存在且可访问"
        
        # 检查表
        TABLE_COUNT=$(mysql -u "$USE_USER" -p"$USE_PASSWORD" -e "USE $DB_NAME; SHOW TABLES;" 2>/dev/null | wc -l)
        if [ "$TABLE_COUNT" -lt 2 ]; then
            log_warning "数据库表可能未初始化"
            log_info "需要初始化数据库"
        else
            log_success "数据库表存在"
        fi
    else
        log_warning "数据库不存在或无法访问"
        log_info "需要创建数据库"
    fi
else
    # 使用 sudo mysql
    if $SUDO mysql -e "USE $DB_NAME; SELECT 1;" 2>/dev/null; then
        log_success "数据库存在"
    else
        log_warning "数据库不存在"
    fi
fi
echo ""

# 步骤5：更新后端配置
log_info "步骤5: 更新后端配置..."
cd "$SCRIPT_DIR/backend"

if [ -f "config.py" ]; then
    # 备份配置
    cp config.py config.py.bak.$(date +%Y%m%d_%H%M%S)
    
    # 更新配置
    if [ "$USE_USER" = "canteen" ]; then
        log_info "更新配置使用新用户 'canteen'..."
        # 这里可以修改 config.py，但通常使用环境变量更好
        log_info "建议使用环境变量或修改 config.py 中的 MYSQL_USER 和 MYSQL_PASSWORD"
    else
        log_info "确保 config.py 中的 MYSQL_PASSWORD 设置为 'password'"
    fi
    
    # 显示当前配置
    log_info "当前数据库配置:"
    grep -E "MYSQL_USER|MYSQL_PASSWORD|MYSQL_DATABASE" config.py | head -3
else
    log_warning "config.py 不存在"
fi
echo ""

# 步骤6：创建环境变量文件（推荐方式）
log_info "步骤6: 创建环境变量文件..."
ENV_FILE="$SCRIPT_DIR/backend/.env"
if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" <<EOF
# MySQL 配置
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=$USE_USER
MYSQL_PASSWORD=$USE_PASSWORD
MYSQL_DATABASE=$DB_NAME

# Redis 配置
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0

# JWT 配置
SECRET_KEY=$(openssl rand -hex 32)
JWT_SECRET_KEY=$(openssl rand -hex 32)
EOF
    log_success "环境变量文件已创建: $ENV_FILE"
    log_info "注意：需要修改后端服务以读取此文件"
else
    log_info "环境变量文件已存在"
fi
echo ""

# 步骤7：修改后端服务配置（如果使用 systemd）
log_info "步骤7: 检查后端服务配置..."
SERVICE_FILE="/etc/systemd/system/canteen-backend.service"

if [ -f "$SERVICE_FILE" ]; then
    log_info "服务文件存在，检查环境变量配置..."
    
    # 检查是否已设置环境变量
    if grep -q "MYSQL_PASSWORD" "$SERVICE_FILE"; then
        log_info "服务文件已包含数据库配置"
    else
        log_warning "服务文件未包含数据库配置"
        log_info "需要手动添加环境变量到服务文件"
        log_info "编辑: sudo nano $SERVICE_FILE"
        log_info "添加:"
        echo "  Environment=\"MYSQL_USER=$USE_USER\""
        echo "  Environment=\"MYSQL_PASSWORD=$USE_PASSWORD\""
    fi
else
    log_warning "服务文件不存在"
fi
echo ""

# 步骤8：重启后端服务
log_info "步骤8: 重启后端服务..."
$SUDO systemctl daemon-reload
$SUDO systemctl restart canteen-backend
sleep 5

if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务运行中"
else
    log_error "后端服务启动失败"
    log_info "查看日志..."
    $SUDO journalctl -u canteen-backend -n 30 --no-pager
fi
echo ""

# 步骤9：测试 API
log_info "步骤9: 测试 API..."
sleep 3

HEALTH=$(curl -s http://localhost:5000/health 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    log_success "健康检查: $HEALTH"
else
    log_error "健康检查失败: $HEALTH"
fi

echo ""
API_TEST=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:5000/api/v1/dishes/categories 2>&1)
API_CODE=$(echo "$API_TEST" | grep "HTTP_CODE" | cut -d: -f2)
API_BODY=$(echo "$API_TEST" | grep -v "HTTP_CODE" | head -3)

if [ "$API_CODE" = "200" ]; then
    log_success "✅ API 正常 (HTTP $API_CODE)"
    echo "响应: $API_BODY"
elif [ "$API_CODE" = "500" ]; then
    log_error "❌ API 仍返回 500"
    echo "错误: $API_BODY"
    log_info "查看日志: sudo journalctl -u canteen-backend -n 50"
else
    log_warning "API 返回 HTTP $API_CODE"
fi
echo ""

echo "=========================================="
log_success "修复完成"
echo "=========================================="
echo ""
log_info "如果问题仍然存在，请："
echo "  1. 检查后端服务配置中的环境变量"
echo "  2. 确保 MySQL 密码正确"
echo "  3. 查看日志: sudo journalctl -u canteen-backend -f"
echo ""
log_info "MySQL 用户信息:"
echo "  用户: $USE_USER"
echo "  密码: $USE_PASSWORD"
echo "  数据库: $DB_NAME"
echo "=========================================="

