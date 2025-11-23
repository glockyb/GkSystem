#!/bin/bash
# 修复前端构建问题的脚本
# 解决跨平台 node_modules 问题

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

echo "=========================================="
log_info "修复前端构建问题"
echo "=========================================="
echo ""

# 检查是否在正确的目录
if [ ! -f "package.json" ]; then
    log_error "未找到 package.json，请确保在项目根目录运行此脚本"
    exit 1
fi

# 清理 node_modules
log_info "清理 node_modules 和 package-lock.json..."
rm -rf node_modules
rm -f package-lock.json
log_success "清理完成"

# 检查 Node.js 和 npm
log_info "检查 Node.js 和 npm..."
if ! command -v node >/dev/null 2>&1; then
    log_error "Node.js 未安装"
    exit 1
fi

NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)
log_success "Node.js: $NODE_VERSION"
log_success "npm: $NPM_VERSION"

# 安装依赖
log_info "重新安装前端依赖（Linux 平台）..."
npm install --registry=https://registry.npmmirror.com || npm install

if [ ! -d "node_modules" ]; then
    log_error "依赖安装失败"
    exit 1
fi

log_success "依赖安装完成"

# 验证 esbuild
log_info "验证 esbuild 平台..."
if [ -d "node_modules/@esbuild" ]; then
    PLATFORM=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    log_info "当前平台: $OS-$PLATFORM"
    
    if [ "$OS" = "linux" ]; then
        if [ -d "node_modules/@esbuild/linux-x64" ] || [ -d "node_modules/@esbuild/linux-arm64" ]; then
            log_success "esbuild 平台正确"
        else
            log_warning "esbuild 平台可能不正确，尝试重新安装..."
            npm uninstall esbuild
            npm install esbuild
        fi
    fi
fi

# 构建前端
log_info "构建前端生产版本..."
npm run build

if [ ! -d "dist" ]; then
    log_error "前端构建失败"
    exit 1
fi

log_success "前端构建完成！"
echo ""
log_info "构建输出目录: $SCRIPT_DIR/frontend/dist"
echo "=========================================="

