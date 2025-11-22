#!/bin/bash
# 修复部署中断和网络问题的脚本

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
log_info "修复部署问题和网络连接"
echo "=========================================="
echo ""

# 检查是否为 root
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# 进入项目目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

log_info "当前目录: $(pwd)"
echo ""

# 步骤1：清理残留容器和资源
log_info "步骤1: 清理残留容器和资源..."

# 停止所有容器
if docker-compose ps -q 2>/dev/null | grep -q .; then
    log_info "停止现有容器..."
    docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true
fi

# 停止所有相关容器（即使 docker-compose 失败）
log_info "检查并停止残留容器..."
CONTAINERS=("canteen-mysql" "canteen-redis" "canteen-backend" "canteen-frontend")
for container in "${CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        log_info "停止容器: $container"
        docker stop "$container" 2>/dev/null || true
        docker rm "$container" 2>/dev/null || true
    fi
done

# 清理网络
log_info "清理网络..."
docker network prune -f 2>/dev/null || true

log_success "清理完成"
echo ""

# 步骤2：配置 Docker 镜像加速器（中国）
log_info "步骤2: 配置 Docker 镜像加速器..."

DOCKER_DAEMON_FILE="/etc/docker/daemon.json"
REGISTRY_MIRRORS=(
    "https://docker.mirrors.ustc.edu.cn"
    "https://hub-mirror.c.163.com"
    "https://mirror.baidubce.com"
)

# 检查是否已配置镜像加速器
if [ -f "$DOCKER_DAEMON_FILE" ]; then
    if grep -q "registry-mirrors" "$DOCKER_DAEMON_FILE" 2>/dev/null; then
        log_success "Docker 镜像加速器已配置"
        cat "$DOCKER_DAEMON_FILE"
    else
        log_warning "检测到 daemon.json，但未配置镜像加速器"
        log_info "添加镜像加速器配置..."
        
        # 备份原文件
        $SUDO cp "$DOCKER_DAEMON_FILE" "${DOCKER_DAEMON_FILE}.bak"
        
        # 添加镜像加速器
        $SUDO python3 -c "
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
for mirror in ${REGISTRY_MIRRORS[@]}; do
    if mirror not in mirrors:
        mirrors.append(mirror)

with open('$DOCKER_DAEMON_FILE', 'w') as f:
    json.dump(config, f, indent=2)
" 2>/dev/null || {
            # 如果 Python 不可用，使用 sed
            log_info "使用 sed 添加镜像加速器..."
            $SUDO tee -a "$DOCKER_DAEMON_FILE" > /dev/null <<EOF

{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF
        }
        
        log_success "镜像加速器配置已添加"
    fi
else
    log_info "创建 Docker 镜像加速器配置..."
    
    # 创建目录
    $SUDO mkdir -p /etc/docker
    
    # 创建配置文件
    $SUDO tee "$DOCKER_DAEMON_FILE" > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    
    log_success "Docker 镜像加速器配置已创建"
fi

# 重启 Docker 服务
log_info "重启 Docker 服务以应用配置..."
$SUDO systemctl restart docker 2>/dev/null || $SUDO service docker restart 2>/dev/null || {
    log_warning "无法重启 Docker 服务，请手动执行: sudo systemctl restart docker"
}

# 等待 Docker 启动
sleep 3

# 验证 Docker
if docker info >/dev/null 2>&1; then
    log_success "Docker 服务运行正常"
else
    log_error "Docker 服务异常，请检查"
    exit 1
fi

echo ""

# 步骤3：检查 DNS 和网络
log_info "步骤3: 检查 DNS 和网络..."

# 测试 DNS 解析
test_dns() {
    local domain=$1
    if nslookup "$domain" >/dev/null 2>&1 || host "$domain" >/dev/null 2>&1 || dig +short "$domain" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 测试 DNS
log_info "测试 DNS 解析..."
if test_dns "baidu.com"; then
    log_success "DNS 解析正常"
else
    log_error "DNS 解析失败"
    echo ""
    log_info "修复 DNS 配置..."
    
    # 备份 DNS 配置
    if [ -f "/etc/resolv.conf" ]; then
        cp /etc/resolv.conf /etc/resolv.conf.bak.$(date +%Y%m%d_%H%M%S)
    fi
    
    # 配置公共 DNS
    tee /etc/resolv.conf > /dev/null <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 114.114.114.114
nameserver 223.5.5.5
EOF
    
    log_success "DNS 配置已更新"
    
    # 重启 DNS 服务
    if systemctl is-active systemd-resolved >/dev/null 2>&1; then
        systemctl restart systemd-resolved
        sleep 2
    fi
    
    # 再次测试
    if test_dns "baidu.com"; then
        log_success "DNS 配置成功"
    else
        log_error "DNS 配置失败，请手动检查网络设置"
        log_info "运行网络修复脚本: sudo ./fix-network-dns.sh"
        exit 1
    fi
fi

echo ""

# 步骤4：测试网络连接
log_info "步骤4: 测试镜像仓库连接..."

# 测试镜像仓库连接
test_registry() {
    local registry=$1
    local domain=$(echo "$registry" | sed -e 's|https\?://||' -e 's|/.*||')
    
    # 先测试 DNS
    if ! test_dns "$domain"; then
        return 1
    fi
    
    # 再测试 HTTP 连接
    if curl -s --connect-timeout 5 --max-time 10 "$registry" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

log_info "测试镜像仓库连接..."
AVAILABLE_REGISTRY=""
for registry in "${REGISTRY_MIRRORS[@]}"; do
    if test_registry "$registry"; then
        log_success "镜像仓库可用: $registry"
        AVAILABLE_REGISTRY="$registry"
        break
    else
        log_warning "镜像仓库不可用: $registry"
    fi
done

if [ -z "$AVAILABLE_REGISTRY" ]; then
    log_error "所有镜像仓库都不可用，请检查网络连接"
    log_info "尝试测试 Docker Hub 直连..."
    if curl -s --connect-timeout 10 "https://registry-1.docker.io" >/dev/null 2>&1; then
        log_warning "Docker Hub 可用，但可能较慢"
    else
        log_error "无法连接到 Docker Hub，请检查网络或防火墙设置"
        exit 1
    fi
fi

echo ""

# 步骤4：预拉取镜像（可选）
read -p "是否预拉取所需镜像？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "步骤4: 预拉取镜像..."
    
    log_info "拉取 MySQL 镜像..."
    docker pull mysql:8.0 || log_warning "MySQL 镜像拉取失败，将在部署时重试"
    
    log_info "拉取 Redis 镜像..."
    docker pull redis:7-alpine || log_warning "Redis 镜像拉取失败，将在部署时重试"
    
    log_info "拉取 Nginx 镜像..."
    docker pull nginx:alpine || log_warning "Nginx 镜像拉取失败，将在部署时重试"
    
    log_success "镜像预拉取完成（部分镜像可能失败，部署时会自动重试）"
    echo ""
fi

# 步骤5：显示配置信息
log_info "步骤5: 显示配置信息..."
echo ""
echo "Docker 配置:"
cat "$DOCKER_DAEMON_FILE" 2>/dev/null || log_warning "无法读取配置文件"
echo ""

# 步骤6：显示下一步操作
echo "=========================================="
log_success "修复完成！"
echo "=========================================="
echo ""
log_info "下一步操作："
echo "1. 确认 Docker 镜像加速器已配置（如上所示）"
echo "2. 如果 Docker 已重启，可以运行部署脚本："
echo "   ./deploy-remote.sh"
echo ""
log_info "如果仍然遇到网络问题："
echo "1. 检查服务器网络连接："
echo "   ping -c 3 docker.mirrors.ustc.edu.cn"
echo ""
echo "2. 检查防火墙设置："
echo "   sudo ufw status"
echo ""
echo "3. 手动拉取镜像："
echo "   docker pull mysql:8.0"
echo "   docker pull redis:7-alpine"
echo ""
echo "4. 查看 Docker 日志："
echo "   sudo journalctl -u docker.service -n 50"
echo ""
echo "=========================================="

