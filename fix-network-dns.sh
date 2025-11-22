#!/bin/bash
# 修复网络和 DNS 问题的脚本

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
log_info "网络和 DNS 问题修复脚本"
echo "=========================================="
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
    log_error "请使用 sudo 运行此脚本"
    echo "使用方法: sudo ./fix-network-dns.sh"
    exit 1
fi

# 步骤1：检查网络连接
log_info "步骤1: 检查网络连接..."

# 测试基本网络连接
test_ping() {
    if ping -c 2 -W 3 "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

log_info "测试基本网络连接..."
if test_ping "8.8.8.8"; then
    log_success "网络连接正常（可以 ping 8.8.8.8）"
else
    log_error "无法连接到互联网（无法 ping 8.8.8.8）"
    echo "请检查："
    echo "  1. 云主机的网络配置"
    echo "  2. 安全组是否允许出站流量"
    echo "  3. 路由配置是否正确"
    exit 1
fi

# 步骤2：检查 DNS 配置
log_info "步骤2: 检查 DNS 配置..."

DNS_CONFIG_FILE="/etc/resolv.conf"

log_info "当前 DNS 配置："
cat "$DNS_CONFIG_FILE" || log_warning "无法读取 DNS 配置文件"

# 测试 DNS 解析
test_dns() {
    if nslookup "$1" >/dev/null 2>&1 || host "$1" >/dev/null 2>&1 || dig +short "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

echo ""
log_info "测试 DNS 解析..."
DNS_WORKING=false

# 测试公共 DNS
TEST_DOMAINS=("baidu.com" "google.com" "docker.io" "docker.mirrors.ustc.edu.cn")

for domain in "${TEST_DOMAINS[@]}"; do
    if test_dns "$domain"; then
        log_success "DNS 解析正常: $domain"
        DNS_WORKING=true
        break
    else
        log_warning "DNS 解析失败: $domain"
    fi
done

if [ "$DNS_WORKING" = false ]; then
    log_error "DNS 解析失败"
    echo ""
    log_info "修复 DNS 配置..."
    
    # 备份原配置
    if [ -f "$DNS_CONFIG_FILE" ]; then
        cp "$DNS_CONFIG_FILE" "${DNS_CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        log_success "已备份原 DNS 配置"
    fi
    
    # 配置公共 DNS
    log_info "配置公共 DNS 服务器..."
    cat > "$DNS_CONFIG_FILE" <<EOF
# DNS 配置 - 由 fix-network-dns.sh 自动生成
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 114.114.114.114
nameserver 223.5.5.5
EOF
    
    log_success "DNS 配置已更新"
    
    # 刷新 DNS 缓存
    if systemctl is-active systemd-resolved >/dev/null 2>&1; then
        systemctl restart systemd-resolved
        log_info "已重启 systemd-resolved"
    fi
    
    # 等待 DNS 生效
    sleep 3
    
    # 再次测试 DNS
    log_info "验证 DNS 配置..."
    if test_dns "baidu.com"; then
        log_success "DNS 配置成功"
        DNS_WORKING=true
    else
        log_error "DNS 配置失败，可能需要检查网络设置"
    fi
fi

echo ""

# 步骤3：检查防火墙是否阻止 DNS
log_info "步骤3: 检查防火墙设置..."

# 检查 UFW
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "Status: active"; then
        log_info "检测到 UFW 防火墙运行中"
        # UFW 通常不阻止出站流量，但检查一下
        log_info "UFW 默认允许出站流量，检查出站规则..."
    fi
fi

# 检查 firewalld
if command -v firewall-cmd >/dev/null 2>&1; then
    if systemctl is-active firewalld >/dev/null 2>&1; then
        log_info "检测到 firewalld 运行中"
        # 检查是否允许 DNS
        if firewall-cmd --query-service=dns >/dev/null 2>&1; then
            log_success "防火墙已允许 DNS"
        else
            log_warning "防火墙可能阻止 DNS，尝试添加 DNS 服务..."
            firewall-cmd --permanent --add-service=dns 2>/dev/null || true
            firewall-cmd --reload 2>/dev/null || true
        fi
    fi
fi

echo ""

# 步骤4：测试镜像仓库连接
log_info "步骤4: 测试镜像仓库连接..."

REGISTRY_MIRRORS=(
    "https://docker.mirrors.ustc.edu.cn"
    "https://hub-mirror.c.163.com"
    "https://mirror.baidubce.com"
    "https://registry-1.docker.io"
)

AVAILABLE_REGISTRY=""
WORKING_MIRROR=""

for mirror in "${REGISTRY_MIRRORS[@]}"; do
    domain=$(echo "$mirror" | sed -e 's|https\?://||' -e 's|/.*||')
    
    log_info "测试镜像仓库: $domain"
    
    # 测试域名解析
    if test_dns "$domain"; then
        log_success "DNS 解析成功: $domain"
        
        # 测试 HTTP 连接
        if curl -s --connect-timeout 5 --max-time 10 "$mirror" >/dev/null 2>&1; then
            log_success "镜像仓库可用: $mirror"
            AVAILABLE_REGISTRY="$mirror"
            WORKING_MIRROR="$mirror"
            break
        else
            log_warning "镜像仓库不可用: $mirror（DNS 正常但连接失败）"
        fi
    else
        log_warning "DNS 解析失败: $domain"
    fi
done

if [ -z "$WORKING_MIRROR" ]; then
    log_error "所有镜像仓库都不可用"
    echo ""
    log_info "故障排查："
    echo "1. 检查云主机安全组设置（允许 HTTPS 出站流量）"
    echo "2. 检查云主机的网络配置"
    echo "3. 检查是否使用代理（某些云主机需要配置代理）"
    echo "4. 尝试手动测试连接："
    echo "   curl -I https://www.baidu.com"
    echo "   curl -I https://docker.io"
    echo ""
    
    # 检查是否需要代理
    if [ -n "$http_proxy" ] || [ -n "$HTTP_PROXY" ] || [ -n "$https_proxy" ] || [ -n "$HTTPS_PROXY" ]; then
        log_info "检测到代理配置："
        echo "  http_proxy: ${http_proxy:-${HTTP_PROXY:-未设置}}"
        echo "  https_proxy: ${https_proxy:-${HTTPS_PROXY:-未设置}}"
        echo ""
        log_info "如果使用代理，需要配置 Docker 使用代理"
        echo "创建 Docker 代理配置..."
        
        mkdir -p /etc/systemd/system/docker.service.d
        cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=${http_proxy:-${HTTP_PROXY}}"
Environment="HTTPS_PROXY=${https_proxy:-${HTTPS_PROXY}}"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF
        
        systemctl daemon-reload
        systemctl restart docker
        log_success "Docker 代理配置已更新，请重试"
    else
        log_warning "未检测到代理配置"
    fi
    
    exit 1
fi

echo ""

# 步骤5：配置 Docker 镜像加速器
log_info "步骤5: 配置 Docker 镜像加速器..."

DOCKER_DAEMON_FILE="/etc/docker/daemon.json"
mkdir -p /etc/docker

# 如果已配置，检查是否包含可用的镜像源
if [ -f "$DOCKER_DAEMON_FILE" ]; then
    if grep -q "$WORKING_MIRROR" "$DOCKER_DAEMON_FILE" 2>/dev/null; then
        log_success "Docker 镜像加速器已配置可用源"
    else
        log_info "更新 Docker 镜像加速器配置..."
        
        # 备份原配置
        cp "$DOCKER_DAEMON_FILE" "${DOCKER_DAEMON_FILE}.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        
        # 使用 Python 或手动更新配置
        if command -v python3 >/dev/null 2>&1; then
            python3 <<EOF
import json
import sys

try:
    with open('$DOCKER_DAEMON_FILE', 'r') as f:
        config = json.load(f)
except:
    config = {}

if 'registry-mirrors' not in config:
    config['registry-mirrors'] = []

mirrors = config['registry-mirrors']
if '$WORKING_MIRROR' not in mirrors:
    mirrors.insert(0, '$WORKING_MIRROR')

with open('$DOCKER_DAEMON_FILE', 'w') as f:
    json.dump(config, f, indent=2)
EOF
        else
            log_warning "Python 不可用，手动创建配置..."
            cat > "$DOCKER_DAEMON_FILE" <<EOF
{
  "registry-mirrors": [
    "$WORKING_MIRROR",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF
        fi
        
        log_success "Docker 镜像加速器配置已更新"
    fi
else
    log_info "创建 Docker 镜像加速器配置..."
    cat > "$DOCKER_DAEMON_FILE" <<EOF
{
  "registry-mirrors": [
    "$WORKING_MIRROR",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    log_success "Docker 镜像加速器配置已创建"
fi

# 重启 Docker
log_info "重启 Docker 服务..."
systemctl daemon-reload
systemctl restart docker

# 等待 Docker 启动
sleep 5

# 验证 Docker
if docker info >/dev/null 2>&1; then
    log_success "Docker 服务运行正常"
else
    log_error "Docker 服务异常"
    exit 1
fi

echo ""

# 步骤6：测试镜像拉取
log_info "步骤6: 测试镜像拉取..."

log_info "尝试拉取测试镜像（busybox）..."
if docker pull busybox:latest 2>&1 | head -20; then
    log_success "镜像拉取成功！网络和 DNS 配置正常"
else
    log_warning "镜像拉取可能失败，但这可能是因为网络较慢"
    log_info "请尝试手动拉取：docker pull busybox:latest"
fi

echo ""

# 步骤7：显示配置信息
log_info "步骤7: 显示配置信息..."
echo ""
echo "DNS 配置："
cat "$DNS_CONFIG_FILE"
echo ""
echo "Docker 镜像加速器配置："
cat "$DOCKER_DAEMON_FILE"
echo ""

# 步骤8：显示下一步操作
echo "=========================================="
log_success "网络和 DNS 修复完成！"
echo "=========================================="
echo ""
log_info "下一步操作："
echo "1. 如果 DNS 已修复，可以重新运行部署脚本："
echo "   ./deploy-remote.sh"
echo ""
log_info "如果仍然遇到问题："
echo "1. 检查云主机安全组设置（允许 HTTPS 出站）"
echo "2. 检查云主机的网络代理设置"
echo "3. 联系云服务提供商检查网络配置"
echo "4. 查看 Docker 日志："
echo "   sudo journalctl -u docker.service -n 50"
echo ""
echo "=========================================="

