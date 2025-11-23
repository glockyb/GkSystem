#!/bin/bash
# 修复 Node.js 安装问题的脚本
# 适用于 Ubuntu 20.04

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

# 检查是否为 root
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

echo "=========================================="
log_info "Node.js 安装修复脚本"
echo "=========================================="
echo ""

# 检查当前 Node.js 版本
if command -v node >/dev/null 2>&1; then
    CURRENT_VERSION=$(node --version)
    log_info "当前 Node.js 版本: $CURRENT_VERSION"
    
    if echo "$CURRENT_VERSION" | grep -qE "v1[6-9]|v2[0-9]"; then
        log_success "Node.js 版本已满足要求，无需安装"
        exit 0
    else
        log_warning "Node.js 版本过低，需要升级"
    fi
else
    log_info "Node.js 未安装"
fi

# 安装 curl（如果未安装）
if ! command -v curl >/dev/null 2>&1; then
    log_info "安装 curl..."
    $SUDO apt-get update
    $SUDO apt-get install -y curl
fi

# 添加 NodeSource 仓库
log_info "添加 NodeSource 仓库（Node.js 18.x）..."

if [ -n "$SUDO" ] && [ "$SUDO" != "" ]; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | $SUDO bash -
else
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
fi

# 安装 Node.js
log_info "安装 Node.js 18.x..."
$SUDO apt-get install -y nodejs

# 验证安装
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    log_success "Node.js 安装成功: $NODE_VERSION"
    log_success "npm 安装成功: $NPM_VERSION"
else
    log_error "Node.js 安装失败"
    exit 1
fi

echo ""
log_success "Node.js 安装完成！"
echo "=========================================="

