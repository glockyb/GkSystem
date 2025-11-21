#!/bin/bash
# Ubuntu Docker 安装脚本

set -e

echo "=========================================="
echo "Ubuntu Docker 安装脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为 root
if [ "$EUID" -eq 0 ]; then 
   echo -e "${YELLOW}警告: 不建议使用 root 用户运行${NC}"
   echo "请使用普通用户运行，脚本会在需要时使用 sudo"
fi

# 检查 Ubuntu 版本
if [ ! -f /etc/os-release ]; then
    echo -e "${RED}❌ 无法检测操作系统版本${NC}"
    exit 1
fi

. /etc/os-release
if [ "$ID" != "ubuntu" ]; then
    echo -e "${YELLOW}⚠️  此脚本专为 Ubuntu 设计，当前系统: $ID${NC}"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "检测到系统: $PRETTY_NAME"
echo ""

# 检查 Docker 是否已安装
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✅ Docker 已安装: $DOCKER_VERSION${NC}"
    read -p "是否重新安装? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "跳过 Docker 安装"
    else
        echo "卸载旧版本 Docker..."
        sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    fi
else
    echo "开始安装 Docker..."
fi

# 更新系统包
echo ""
echo "📦 更新系统包..."
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 添加 Docker 官方 GPG 密钥
echo ""
echo "🔑 添加 Docker GPG 密钥..."
sudo mkdir -p /etc/apt/keyrings
if [ -f /etc/apt/keyrings/docker.gpg ]; then
    echo "GPG 密钥已存在，跳过..."
else
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

# 设置 Docker 仓库
echo ""
echo "📝 设置 Docker 仓库..."
ARCH=$(dpkg --print-architecture)
DISTRO=$(lsb_release -cs)
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $DISTRO stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装 Docker Engine
echo ""
echo "🐳 安装 Docker Engine..."
sudo apt-get update
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# 验证 Docker 安装
echo ""
echo "✅ 验证 Docker 安装..."
sudo docker --version
sudo docker compose version

# 启动 Docker 服务
echo ""
echo "🚀 启动 Docker 服务..."
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker --no-pager

# 将当前用户添加到 docker 组
echo ""
echo "👤 配置用户权限..."
if ! groups $USER | grep -q docker; then
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✅ 已将用户 $USER 添加到 docker 组${NC}"
    echo -e "${YELLOW}⚠️  请重新登录或运行 'newgrp docker' 使更改生效${NC}"
else
    echo -e "${GREEN}✅ 用户已在 docker 组中${NC}"
fi

# 测试 Docker（需要新组权限）
echo ""
echo "🧪 测试 Docker..."
if sudo docker ps &> /dev/null; then
    echo -e "${GREEN}✅ Docker 运行正常${NC}"
else
    echo -e "${YELLOW}⚠️  Docker 测试失败，可能需要重新登录${NC}"
fi

# 安装 Docker Compose（独立版本，如果需要）
if ! command -v docker-compose &> /dev/null; then
    echo ""
    echo "📦 安装 Docker Compose (独立版本)..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker-compose --version
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Docker 安装完成！${NC}"
echo "=========================================="
echo ""
echo "📋 下一步："
echo "  1. 如果提示需要重新登录，请执行: newgrp docker"
echo "  2. 验证安装: docker ps"
echo "  3. 上传项目文件到服务器"
echo "  4. 运行部署脚本: ./deploy-remote.sh"
echo ""
echo "📖 详细文档请查看: UBUNTU_DOCKER_SETUP.md"
echo "=========================================="

