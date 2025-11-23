#!/bin/bash
# 更新前端 API 地址脚本
# 用于修改前端构建后的 API 地址

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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/frontend"

# 获取公网 IP
echo "检测服务器 IP..."
SERVER_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=""

read -p "请输入后端 API 地址 (默认: http://$SERVER_IP:5000): " PUBLIC_IP
PUBLIC_IP=${PUBLIC_IP:-http://$SERVER_IP:5000}

log_info "设置 API 地址为: $PUBLIC_IP"

# 创建生产环境变量文件
cat > .env.production <<EOF
VITE_API_URL=$PUBLIC_IP
EOF

log_success "环境变量文件已创建"

# 如果已构建，需要重新构建
if [ -d "dist" ]; then
    log_info "检测到已构建的前端，需要重新构建..."
    read -p "是否重新构建前端? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "重新构建前端..."
        npm run build
        log_success "前端重新构建完成"
    fi
else
    log_info "前端尚未构建，构建时请使用: npm run build"
fi

echo ""
log_success "配置完成！"
echo "API 地址: $PUBLIC_IP"
echo ""

