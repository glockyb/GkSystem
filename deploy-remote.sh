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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 检查是否为 root 用户
if [ "$EUID" -eq 0 ]; then 
   log_warning "不建议使用 root 用户运行，建议使用普通用户 + sudo"
   read -p "是否继续? (y/n) " -n 1 -r
   echo
   if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
   fi
fi

# 检查 Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装"
    echo "正在安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    log_success "Docker 安装完成，请重新登录以应用用户组更改"
    exit 0
fi

# 检查 Docker 是否运行
if ! docker info &> /dev/null; then
    log_error "Docker 未运行"
    echo "正在启动 Docker..."
    sudo systemctl start docker || sudo service docker start
    sleep 2
    if ! docker info &> /dev/null; then
        log_error "无法启动 Docker 服务"
        echo "请手动启动: sudo systemctl start docker"
        exit 1
    fi
fi

# 检查 Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}⚠️  Docker Compose 未安装，正在安装...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# 检测 docker compose 版本
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
    log_info "使用 Docker Compose V2"
else
    COMPOSE_CMD="docker-compose"
    log_info "使用 Docker Compose V1"
fi

# 检查 Docker 镜像加速器（可选）并测试常用镜像仓库的连通性（但不在失败时退出脚本）
if [ -f "/etc/docker/daemon.json" ] && grep -q "registry-mirrors" /etc/docker/daemon.json 2>/dev/null; then
    log_success "Docker 镜像加速器已配置"
else
    log_warning "未检测到 Docker 镜像加速器配置"
    echo "  如果遇到镜像拉取超时，请运行: ./fix-deploy-issue.sh"
    echo "  或手动配置镜像加速器（参考 DOCKER_DEPLOY.md）"
fi

# 测试镜像仓库连通性（非致命，脚本继续执行）
REG_MIRRORS=("https://docker.mirrors.ustc.edu.cn" "https://hub-mirror.c.163.com" "https://mirror.baidubce.com")
MIRROR_OK=false
for url in "${REG_MIRRORS[@]}"; do
    log_info "测试镜像仓库连接: $url"
    if curl -sSf --max-time 5 "$url" >/dev/null 2>&1; then
        log_success "镜像仓库可用: $url"
        MIRROR_OK=true
        break
    else
        log_warning "镜像仓库不可用: $url"
    fi
done

if ! $MIRROR_OK; then
    log_warning "未检测到可用第三方镜像加速器，尝试连接 Docker Hub 直连..."
    if curl -sSf --max-time 5 https://registry-1.docker.io/v2/ >/dev/null 2>&1; then
        log_success "已能访问 Docker Hub（直连），将使用官方注册表"
    else
        log_error "无法连接到任何镜像仓库或 Docker Hub，网络或防火墙可能阻止访问"
        echo "  建议:"
        echo "    1) 检查云主机出站规则/防火墙，确保允许 HTTPS(443) 访问外网"
        echo "    2) 若使用公司/校园网络，请配置 HTTP(S) 代理或联系网络管理员"
        echo "    3) 可在可访问网络的机器上预先拉取镜像并导出为 tar，再导入到目标主机"
        echo "  脚本将继续执行，但镜像拉取步骤可能失败，若失败请按上面建议排查网络问题。"
    fi
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

# 清理残留容器（如果存在）
echo ""
log_info "清理残留容器和资源..."

# 检测 docker compose 版本（如果还没检测）
if [ -z "$COMPOSE_CMD" ]; then
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
fi

if $COMPOSE_CMD ps -q 2>/dev/null | grep -q .; then
    log_info "停止现有容器..."
    $COMPOSE_CMD down 2>/dev/null || true
fi

# 检查并停止残留容器
CONTAINERS=("canteen-mysql" "canteen-redis" "canteen-backend" "canteen-frontend")
for container in "${CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        log_info "清理容器: $container"
        docker stop "$container" 2>/dev/null || true
        docker rm "$container" 2>/dev/null || true
    fi
done

# 构建并启动服务
echo ""
log_info "构建并启动所有服务..."

# 尝试构建和启动，如果失败则提供详细错误信息
if ! $COMPOSE_CMD up -d --build 2>&1; then
    log_error "构建或启动服务失败"
    echo ""
    log_info "常见问题和解决方案："
    echo "1. 网络超时 - 请运行修复脚本：./fix-deploy-issue.sh"
    echo "2. 端口被占用 - 检查端口占用：sudo netstat -tulpn | grep -E '8080|5000|3306|6379'"
    echo "3. Docker 未运行 - 启动 Docker：sudo systemctl start docker"
    echo ""
    log_info "尝试重新运行部署..."
    echo "如果问题持续，请运行：./fix-deploy-issue.sh"
    exit 1
fi

log_success "服务构建和启动完成"

echo ""
echo "⏳ 等待服务启动（约30秒）..."
sleep 30

# 检查服务状态
echo ""
log_info "检查服务状态..."
$COMPOSE_CMD ps

# 等待 MySQL 健康检查
echo ""
log_info "等待 MySQL 服务就绪..."
MYSQL_READY=false
for i in {1..30}; do
    if $COMPOSE_CMD ps mysql 2>/dev/null | grep -q "healthy"; then
        log_success "MySQL 已启动"
        MYSQL_READY=true
        break
    fi
    sleep 2
done

if [ "$MYSQL_READY" = false ]; then
    log_warning "MySQL 启动超时，但继续执行..."
fi

# 等待 Redis 健康检查
log_info "等待 Redis 服务就绪..."
REDIS_READY=false
for i in {1..30}; do
    if $COMPOSE_CMD ps redis 2>/dev/null | grep -q "healthy"; then
        log_success "Redis 已启动"
        REDIS_READY=true
        break
    fi
    sleep 2
done

if [ "$REDIS_READY" = false ]; then
    log_warning "Redis 启动超时，但继续执行..."
fi

# 初始化数据
echo ""
log_info "初始化数据..."
log_info "执行数据预处理..."
$COMPOSE_CMD exec -T backend python data/preprocessor.py 2>/dev/null || log_warning "数据预处理可能已有数据或遇到错误，继续..."

echo ""
log_info "训练推荐模型..."
$COMPOSE_CMD exec -T backend python train_model.py 2>/dev/null || log_warning "模型训练可能遇到错误，继续..."

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
echo "  查看日志: $COMPOSE_CMD logs -f"
echo "  停止服务: $COMPOSE_CMD down"
echo "  重启服务: $COMPOSE_CMD restart"
echo "  查看状态: $COMPOSE_CMD ps"
echo ""
echo "🔒 安全提示："
echo "  1. 请修改 docker-compose.yml 中的 MySQL 密码"
echo "  2. 配置防火墙规则限制端口访问"
echo "  3. 建议使用 Nginx 反向代理和 HTTPS"
echo ""
echo "📖 详细文档请查看:"
echo "  - DOCKER_DEPLOY.md - Docker 部署指南"
echo "  - 云主机部署快速修复.md - **网络问题快速修复** ⭐"
echo "  - 部署故障处理指南.md - 部署故障处理"
echo ""
log_warning "如果遇到网络或 DNS 问题："
echo "  1. 先运行: sudo ./fix-network-dns.sh"
echo "  2. 检查云主机安全组（允许 HTTPS 和 DNS 出站）"
echo "  3. 再运行: ./deploy-remote.sh"
echo "=========================================="

