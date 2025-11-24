#!/bin/bash
# 修复 Nginx 权限问题（/root 目录访问问题）

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
log_info "修复 Nginx 权限问题"
echo "=========================================="
echo ""

# 问题：文件在 /root 目录下，www-data 无法访问
# 解决方案：将前端文件复制到标准位置

SOURCE_DIR="/root/gksys/GkSystem/frontend/dist"
TARGET_DIR="/var/www/canteen"

log_info "问题：前端文件在 /root 目录下，www-data 无法访问"
log_info "解决方案：将前端文件复制到 /var/www/canteen"
echo ""

# 步骤1：创建目标目录
log_info "步骤1: 创建目标目录..."
$SUDO mkdir -p "$TARGET_DIR"
$SUDO chown -R www-data:www-data "$TARGET_DIR"
log_success "目标目录已创建: $TARGET_DIR"
echo ""

# 步骤2：复制前端文件
log_info "步骤2: 复制前端文件..."
if [ -d "$SOURCE_DIR" ] && [ -f "$SOURCE_DIR/index.html" ]; then
    $SUDO cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"
    $SUDO chown -R www-data:www-data "$TARGET_DIR"
    $SUDO chmod -R 755 "$TARGET_DIR"
    log_success "文件已复制"
else
    log_error "源文件不存在: $SOURCE_DIR"
    exit 1
fi
echo ""

# 步骤3：验证文件
log_info "步骤3: 验证文件..."
if [ -f "$TARGET_DIR/index.html" ]; then
    log_success "index.html 存在"
    ls -la "$TARGET_DIR/index.html"
else
    log_error "index.html 不存在"
    exit 1
fi

# 测试 www-data 是否可以读取
if $SUDO -u www-data test -r "$TARGET_DIR/index.html" 2>/dev/null; then
    log_success "www-data 可以读取文件"
else
    log_error "www-data 仍然无法读取文件"
    $SUDO chmod -R 755 "$TARGET_DIR"
    $SUDO chown -R www-data:www-data "$TARGET_DIR"
fi
echo ""

# 步骤4：更新 Nginx 配置
log_info "步骤4: 更新 Nginx 配置..."
NGINX_CONFIG="/etc/nginx/sites-available/canteen"

# 备份
$SUDO cp "$NGINX_CONFIG" "${NGINX_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"

# 更新配置
$SUDO sed -i "s|root.*frontend/dist|root $TARGET_DIR|g" "$NGINX_CONFIG"
$SUDO sed -i "s|root /root/gksys/GkSystem/frontend/dist|root $TARGET_DIR|g" "$NGINX_CONFIG"

log_info "配置已更新"
log_info "新路径: $TARGET_DIR"
echo ""

# 步骤5：验证配置
log_info "步骤5: 验证配置..."
if $SUDO nginx -t 2>&1; then
    log_success "配置正确"
else
    log_error "配置有错误"
    exit 1
fi
echo ""

# 步骤6：重启 Nginx
log_info "步骤6: 重启 Nginx..."
$SUDO systemctl restart nginx
sleep 3

if $SUDO systemctl is-active nginx >/dev/null 2>&1; then
    log_success "Nginx 已重启"
else
    log_error "Nginx 启动失败"
    exit 1
fi
echo ""

# 步骤7：测试访问
log_info "步骤7: 测试访问..."
sleep 2

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
CONTENT=$(curl -s http://localhost/ 2>/dev/null | head -3)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "✅ 修复成功！HTTP $HTTP_CODE"
    echo "响应内容预览:"
    echo "$CONTENT"
elif [ "$HTTP_CODE" = "500" ]; then
    log_error "仍然返回 500 错误"
    echo ""
    log_info "查看错误日志..."
    $SUDO tail -20 /var/log/nginx/error.log 2>/dev/null || \
    $SUDO tail -20 /var/log/nginx/canteen-error.log 2>/dev/null
else
    log_warning "返回 HTTP $HTTP_CODE"
    echo "响应: $CONTENT"
fi

echo ""
echo "=========================================="
log_success "修复完成！"
echo "=========================================="
echo ""
log_info "前端文件已移动到: $TARGET_DIR"
log_info "以后更新前端时，需要重新复制文件："
echo "  sudo cp -r ~/gksys/GkSystem/frontend/dist/* /var/www/canteen/"
echo "  sudo chown -R www-data:www-data /var/www/canteen"
echo "  sudo systemctl reload nginx"
echo "=========================================="

