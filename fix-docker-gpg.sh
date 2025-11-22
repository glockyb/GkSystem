#!/bin/bash
# 修复 Docker GPG 密钥问题的脚本

set -e

echo "=========================================="
echo "修复 Docker GPG 密钥问题"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}请使用 sudo 运行此脚本${NC}"
   exit 1
fi

echo "步骤 1: 清理旧的 GPG 密钥和仓库配置..."

# 删除旧的 Docker 仓库配置
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/keyrings/docker.gpg
rm -f /usr/share/keyrings/docker-archive-keyring.gpg

# 删除 apt-key 中的旧密钥（如果存在）
apt-key del 7EA0A9C3F273FCD8 2>/dev/null || true

echo -e "${GREEN}✅ 已清理旧配置${NC}"
echo ""

echo "步骤 2: 安装必要的工具..."
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

echo ""
echo "步骤 3: 添加 Docker GPG 密钥（方法 1 - 推荐）..."

# 创建密钥目录
mkdir -p /etc/apt/keyrings

# 下载并添加 GPG 密钥
if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo -e "${GREEN}✅ GPG 密钥已添加${NC}"
else
    echo -e "${YELLOW}⚠️  方法 1 失败，尝试方法 2...${NC}"
    
    # 方法 2: 使用 apt-key（传统方法）
    if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -; then
        echo -e "${GREEN}✅ GPG 密钥已添加（传统方法）${NC}"
    else
        echo -e "${YELLOW}⚠️  方法 2 失败，尝试方法 3...${NC}"
        
        # 方法 3: 从密钥服务器导入
        if apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7EA0A9C3F273FCD8; then
            echo -e "${GREEN}✅ GPG 密钥已添加（密钥服务器）${NC}"
        else
            echo -e "${RED}❌ 所有方法都失败了${NC}"
            exit 1
        fi
    fi
fi

echo ""
echo "步骤 4: 配置 Docker 仓库..."

ARCH=$(dpkg --print-architecture)
DISTRO=$(lsb_release -cs)

# 如果新方法成功，使用新格式
if [ -f /etc/apt/keyrings/docker.gpg ]; then
    echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $DISTRO stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    echo -e "${GREEN}✅ 仓库已配置（新格式）${NC}"
else
    # 否则使用传统格式
    echo "deb [arch=$ARCH] https://download.docker.com/linux/ubuntu $DISTRO stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    echo -e "${GREEN}✅ 仓库已配置（传统格式）${NC}"
fi

echo ""
echo "步骤 5: 验证仓库配置..."

# 更新包列表
if apt-get update; then
    echo -e "${GREEN}✅ 仓库验证成功！${NC}"
else
    echo -e "${RED}❌ 仓库验证失败${NC}"
    echo ""
    echo "故障排查："
    echo "1. 检查网络连接"
    echo "2. 检查 /etc/apt/sources.list.d/docker.list 文件内容"
    echo "3. 检查 GPG 密钥是否正确添加"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ GPG 密钥问题已修复！${NC}"
echo "=========================================="
echo ""
echo "现在可以继续安装 Docker："
echo "  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
echo ""
echo "或重新运行安装脚本："
echo "  ./install-docker-ubuntu.sh"
echo "=========================================="

