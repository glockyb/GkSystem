#!/bin/bash
# 防火墙配置脚本

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

echo "=========================================="
log_info "防火墙配置脚本"
echo "=========================================="
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
    log_error "请使用 sudo 运行此脚本"
    echo "使用方法: sudo ./configure-firewall.sh"
    exit 1
fi

# 检测防火墙工具
if command -v ufw &> /dev/null; then
    FIREWALL_TOOL="ufw"
    log_success "检测到 UFW 防火墙"
elif command -v firewall-cmd &> /dev/null; then
    FIREWALL_TOOL="firewalld"
    log_success "检测到 firewalld 防火墙"
else
    log_error "未找到防火墙管理工具（ufw 或 firewalld）"
    exit 1
fi

echo ""
log_info "配置防火墙规则..."
echo ""

# 配置函数
configure_ufw() {
    log_info "使用 UFW 配置防火墙..."
    
    # 允许 SSH（必需）
    ufw allow 22/tcp
    log_success "允许 SSH (22)"
    
    # 允许前端（必需）
    ufw allow 8080/tcp
    log_success "允许前端 (8080)"
    
    # 询问是否允许后端 API
    echo ""
    read -p "是否允许后端 API 端口 5000? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ufw allow 5000/tcp
        log_success "允许后端 API (5000)"
    else
        log_info "跳过后端 API 端口配置（前端会自动代理）"
    fi
    
    # 询问是否允许 HTTPS
    read -p "是否允许 HTTPS 端口 443? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ufw allow 443/tcp
        log_success "允许 HTTPS (443)"
    fi
    
    # 启用防火墙
    echo ""
    log_info "启用防火墙..."
    ufw --force enable
    
    # 显示状态
    echo ""
    log_info "当前防火墙规则："
    ufw status verbose
}

configure_firewalld() {
    log_info "使用 firewalld 配置防火墙..."
    
    # 允许 SSH（必需）
    firewall-cmd --permanent --add-service=ssh
    log_success "允许 SSH (22)"
    
    # 允许前端（必需）
    firewall-cmd --permanent --add-port=8080/tcp
    log_success "允许前端 (8080)"
    
    # 询问是否允许后端 API
    echo ""
    read -p "是否允许后端 API 端口 5000? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        firewall-cmd --permanent --add-port=5000/tcp
        log_success "允许后端 API (5000)"
    else
        log_info "跳过后端 API 端口配置（前端会自动代理）"
    fi
    
    # 询问是否允许 HTTPS
    read -p "是否允许 HTTPS 端口 443? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        firewall-cmd --permanent --add-service=https
        log_success "允许 HTTPS (443)"
    fi
    
    # 重新加载配置
    echo ""
    log_info "重新加载防火墙配置..."
    firewall-cmd --reload
    
    # 显示状态
    echo ""
    log_info "当前防火墙规则："
    firewall-cmd --list-all
}

# 执行配置
case $FIREWALL_TOOL in
    ufw)
        configure_ufw
        ;;
    firewalld)
        configure_firewalld
        ;;
esac

echo ""
echo "=========================================="
log_success "防火墙配置完成！"
echo "=========================================="
echo ""
log_info "已开放的端口："
echo "  22 (SSH) - 远程连接"
echo "  8080 (前端) - 用户访问"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  5000 (后端) - API 访问"
fi
echo ""
log_warning "重要提示："
echo "  - MySQL (3306) 和 Redis (6379) 未开放（使用内部网络）"
echo "  - 建议只开放必要的端口"
echo ""
log_info "查看防火墙状态："
if [ "$FIREWALL_TOOL" = "ufw" ]; then
    echo "  sudo ufw status verbose"
else
    echo "  sudo firewall-cmd --list-all"
fi
echo ""
echo "详细说明请查看: 防火墙端口配置指南.md"
echo "=========================================="

