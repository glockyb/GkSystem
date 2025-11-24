#!/bin/bash
# 修复前端 API URL 配置问题

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
    SUDO="sudo"
else
    SUDO=""
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
TARGET_DIR="/var/www/canteen"

echo "=========================================="
log_info "修复前端 API URL 配置"
echo "=========================================="
echo ""

log_info "问题：前端使用了绝对 URL (http://119.3.232.65:5000)"
log_info "解决：重新构建前端，使用相对路径 (/api/v1)"
echo ""

# 步骤1：进入前端目录
log_info "步骤1: 进入前端目录..."
cd "$FRONTEND_DIR"

# 步骤2：清除环境变量
log_info "步骤2: 清除 VITE_API_URL 环境变量..."
unset VITE_API_URL
export VITE_API_URL=""
log_success "环境变量已清除"
echo ""

# 步骤3：清理旧的构建
log_info "步骤3: 清理旧的构建..."
if [ -d "dist" ]; then
    rm -rf dist
    log_success "已清理旧构建"
fi
echo ""

# 步骤4：重新构建前端
log_info "步骤4: 重新构建前端（不使用环境变量）..."
log_info "这将确保前端使用相对路径 /api/v1"

# 确保没有设置环境变量
VITE_API_URL="" npm run build

if [ ! -d "dist" ]; then
    log_error "前端构建失败"
    exit 1
fi

log_success "前端构建完成"
echo ""

# 步骤5：验证构建结果
log_info "步骤5: 验证构建结果..."
if find dist -name "*.js" -exec grep -l "119.3.232.65:5000\|localhost:5000\|127.0.0.1:5000" {} \; 2>/dev/null | head -1; then
    log_warning "构建结果中仍包含绝对 URL"
    log_info "检查具体文件..."
    find dist -name "*.js" -exec grep -l "119.3.232.65:5000" {} \; 2>/dev/null | head -3
else
    log_success "构建结果正确（使用相对路径）"
fi
echo ""

# 步骤6：部署前端文件
log_info "步骤6: 部署前端文件到 /var/www/canteen..."
$SUDO rm -rf "$TARGET_DIR"/*
$SUDO cp -r dist/* "$TARGET_DIR/"
$SUDO chown -R www-data:www-data "$TARGET_DIR"
$SUDO chmod -R 755 "$TARGET_DIR"
log_success "前端文件已部署"
echo ""

# 步骤7：重新加载 Nginx
log_info "步骤7: 重新加载 Nginx..."
$SUDO systemctl reload nginx
sleep 2
log_success "Nginx 已重新加载"
echo ""

# 步骤8：测试
log_info "步骤8: 测试访问..."
sleep 2

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    log_success "前端访问正常 (HTTP $HTTP_CODE)"
else
    log_warning "前端返回 HTTP $HTTP_CODE"
fi
echo ""

echo "=========================================="
log_success "修复完成！"
echo "=========================================="
echo ""
log_info "现在前端应该使用相对路径 /api/v1 访问后端"
log_info "请清除浏览器缓存后重新访问"
echo ""
log_info "清除浏览器缓存方法："
echo "  1. 按 Ctrl+Shift+Delete (Windows/Linux)"
echo "  2. 或按 Cmd+Shift+Delete (Mac)"
echo "  3. 选择'缓存的图片和文件'"
echo "  4. 或按 Ctrl+F5 / Cmd+Shift+R 强制刷新"
echo ""
log_info "如果问题仍然存在，请："
echo "  1. 打开浏览器开发者工具 (F12)"
echo "  2. 查看 Network 标签"
echo "  3. 尝试注册/登录"
echo "  4. 查看请求 URL（应该是 /api/v1/register）"
echo "=========================================="

