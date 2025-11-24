#!/bin/bash
# 更新前端部署脚本（前端文件在 /var/www/canteen）

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
SOURCE_DIR="$SCRIPT_DIR/frontend/dist"
TARGET_DIR="/var/www/canteen"

echo "=========================================="
log_info "更新前端部署"
echo "=========================================="
echo ""

# 检查源文件
if [ ! -d "$SOURCE_DIR" ] || [ ! -f "$SOURCE_DIR/index.html" ]; then
    log_error "前端文件不存在，重新构建..."
    cd "$SCRIPT_DIR/frontend"
    
    if [ ! -d "node_modules" ]; then
        log_info "安装依赖..."
        npm install --registry=https://registry.npmmirror.com || npm install
    fi
    
    log_info "构建前端..."
    npm run build
    cd "$SCRIPT_DIR"
fi

# 复制文件
log_info "复制前端文件到 $TARGET_DIR..."
$SUDO rm -rf "$TARGET_DIR"/*
$SUDO cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"
$SUDO chown -R www-data:www-data "$TARGET_DIR"
$SUDO chmod -R 755 "$TARGET_DIR"

log_success "文件已更新"

# 重新加载 Nginx
log_info "重新加载 Nginx..."
$SUDO systemctl reload nginx

log_success "前端已更新！"
echo "=========================================="

