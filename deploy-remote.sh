#!/bin/bash
# 远端服务器快速部署脚本

set -e

echo "=========================================="
echo "校园食堂推荐系统 - 远端服务器部署脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为 root 用户
if [ "$EUID" -eq 0 ]; then 
   echo -e "${YELLOW}警告: 不建议使用 root 用户运行，建议使用普通用户 + sudo${NC}"
   read -p "是否继续? (y/n) " -n 1 -r
   echo
   if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
   fi
fi

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker 未安装${NC}"
    echo "正在安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✅ Docker 安装完成，请重新登录以应用用户组更改${NC}"
    exit 0
fi

# 检查 Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}⚠️  Docker Compose 未安装，正在安装...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

echo -e "${GREEN}✅ Docker 环境检查通过${NC}"
echo ""

# 获取服务器 IP
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "检测到服务器 IP: $SERVER_IP"
read -p "请输入前端访问的 API 地址 (默认: http://$SERVER_IP:5000): " API_URL
API_URL=${API_URL:-http://$SERVER_IP:5000}

echo ""
echo "配置信息:"
echo "  前端地址: http://$SERVER_IP:8080"
echo "  后端 API: $API_URL"
echo ""

read -p "是否继续部署? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
   exit 1
fi

# 进入项目目录
cd "$(dirname "$0")"

# 创建 .env 文件（如果不存在）
if [ ! -f .env ]; then
    echo "创建 .env 文件..."
    cat > .env << EOF
# 前端 API 地址
VITE_API_URL=$API_URL

# MySQL 配置（生产环境请修改密码）
MYSQL_ROOT_PASSWORD=password
MYSQL_DATABASE=canteen_recommendation

# 服务器 IP
SERVER_IP=$SERVER_IP
EOF
    echo -e "${GREEN}✅ .env 文件已创建${NC}"
fi

# 构建并启动服务
echo ""
echo "📦 构建并启动所有服务..."
docker-compose up -d --build

echo ""
echo "⏳ 等待服务启动（约30秒）..."
sleep 30

# 检查服务状态
echo ""
echo "🔍 检查服务状态..."
docker-compose ps

# 等待 MySQL 健康检查
echo ""
echo "🔍 等待 MySQL 服务就绪..."
for i in {1..30}; do
    if docker-compose ps mysql | grep -q "healthy"; then
        echo -e "${GREEN}✅ MySQL 已启动${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${YELLOW}⚠️  MySQL 启动超时，但继续执行...${NC}"
    fi
    sleep 2
done

# 等待 Redis 健康检查
echo "🔍 等待 Redis 服务就绪..."
for i in {1..30}; do
    if docker-compose ps redis | grep -q "healthy"; then
        echo -e "${GREEN}✅ Redis 已启动${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${YELLOW}⚠️  Redis 启动超时，但继续执行...${NC}"
    fi
    sleep 2
done

# 初始化数据
echo ""
echo "📊 初始化数据..."
echo "执行数据预处理..."
docker-compose exec -T backend python data/preprocessor.py || echo -e "${YELLOW}⚠️  数据预处理可能已有数据或遇到错误，继续...${NC}"

echo ""
echo "🤖 训练推荐模型..."
docker-compose exec -T backend python train_model.py || echo -e "${YELLOW}⚠️  模型训练可能遇到错误，继续...${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}✅ 部署完成！${NC}"
echo "=========================================="
echo ""
echo "📱 访问地址："
echo -e "  前端界面: ${GREEN}http://$SERVER_IP:8080${NC}"
echo -e "  后端 API: ${GREEN}$API_URL${NC}"
echo -e "  健康检查: ${GREEN}http://$SERVER_IP:5000/health${NC}"
echo ""
echo "📋 常用命令："
echo "  查看日志: docker-compose logs -f"
echo "  停止服务: docker-compose down"
echo "  重启服务: docker-compose restart"
echo "  查看状态: docker-compose ps"
echo ""
echo "🔒 安全提示："
echo "  1. 请修改 docker-compose.yml 中的 MySQL 密码"
echo "  2. 配置防火墙规则限制端口访问"
echo "  3. 建议使用 Nginx 反向代理和 HTTPS"
echo ""
echo "📖 详细文档请查看: DOCKER_DEPLOY.md"
echo "=========================================="

