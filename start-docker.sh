#!/bin/bash
# Docker 方式启动项目的完整脚本
# 使用 Docker Compose 启动所有服务

set -e  # 遇到错误立即退出

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

echo "=========================================="
echo "校园食堂推荐系统 - Docker 启动脚本"
echo "=========================================="
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装"
    echo ""
    echo "请先安装 Docker:"
    echo "  - macOS/Windows: https://www.docker.com/products/docker-desktop"
    echo "  - Linux: 运行 ./install-docker-ubuntu.sh"
    exit 1
fi

# 检查 Docker 是否运行
if ! docker info &> /dev/null; then
    log_error "Docker 未运行"
    echo ""
    if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "请启动 Docker Desktop 应用"
    else
        echo "请启动 Docker 服务: sudo systemctl start docker"
    fi
    exit 1
fi

# 检查 docker-compose 是否安装
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "docker-compose 未安装"
    echo ""
    echo "请安装 docker-compose 或使用 'docker compose' 命令（Docker Compose V2）"
    exit 1
fi

# 检测 docker compose 版本
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
    log_success "使用 Docker Compose V2"
else
    COMPOSE_CMD="docker-compose"
    log_info "使用 Docker Compose V1"
fi

log_success "Docker 环境检查通过"
echo ""

# 进入项目目录
cd "$(dirname "$0")"

# 检查 docker-compose.yml 是否存在
if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml 文件不存在"
    echo "请确保在项目根目录运行此脚本"
    exit 1
fi

log_info "构建并启动所有服务..."
$COMPOSE_CMD up -d --build

echo ""
log_info "等待 MySQL 和 Redis 服务启动（约30秒）..."
sleep 10

# 等待 MySQL 健康检查
log_info "检查 MySQL 服务状态..."
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
log_info "检查 Redis 服务状态..."
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

echo ""
log_info "初始化数据..."
log_info "执行数据预处理..."
$COMPOSE_CMD exec -T backend python data/preprocessor.py 2>/dev/null || log_warning "数据预处理可能已有数据或遇到错误，继续..."

echo ""
log_info "训练推荐模型..."
$COMPOSE_CMD exec -T backend python train_model.py 2>/dev/null || log_warning "模型训练可能遇到错误，继续..."

echo ""
echo "=========================================="
log_success "服务启动完成！"
echo "=========================================="
echo ""
echo "📱 访问地址："
echo "  前端界面: http://localhost:8080"
echo "  后端 API: http://localhost:5000"
echo "  健康检查: http://localhost:5000/health"
echo ""
echo "📋 常用命令："
echo "  查看日志: $COMPOSE_CMD logs -f"
echo "  查看状态: $COMPOSE_CMD ps"
echo "  停止服务: $COMPOSE_CMD down"
echo "  重启服务: $COMPOSE_CMD restart"
echo "  进入容器: $COMPOSE_CMD exec backend bash"
echo ""
echo "💡 提示："
echo "  - 首次启动可能需要几分钟来构建镜像"
echo "  - 如果服务未正常启动，请查看日志: $COMPOSE_CMD logs"
echo "  - 数据库数据会持久化保存在 Docker volumes 中"
echo ""
echo "=========================================="

