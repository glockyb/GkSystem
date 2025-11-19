#!/bin/bash
# Docker 方式启动项目的完整脚本

set -e  # 遇到错误立即退出

echo "=========================================="
echo "校园食堂推荐系统 - Docker 启动脚本"
echo "=========================================="
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ 错误: Docker 未安装"
    echo "请先安装 Docker Desktop: https://www.docker.com/products/docker-desktop"
    echo "或运行: bash install-docker.sh"
    exit 1
fi

# 检查 Docker 是否运行
if ! docker info &> /dev/null; then
    echo "❌ 错误: Docker 未运行"
    echo "请启动 Docker Desktop 应用"
    exit 1
fi

# 检查 docker-compose 是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "❌ 错误: docker-compose 未安装"
    echo "Docker Desktop 应该包含 docker-compose，请检查安装"
    exit 1
fi

echo "✅ Docker 环境检查通过"
echo ""

# 进入项目目录
cd "$(dirname "$0")"

echo "📦 构建并启动所有服务..."
docker-compose up -d --build

echo ""
echo "⏳ 等待 MySQL 和 Redis 服务启动（约30秒）..."
sleep 10

# 等待 MySQL 健康检查
echo "🔍 检查 MySQL 服务状态..."
for i in {1..30}; do
    if docker-compose ps mysql | grep -q "healthy"; then
        echo "✅ MySQL 已启动"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "⚠️  MySQL 启动超时，但继续执行..."
    fi
    sleep 2
done

# 等待 Redis 健康检查
echo "🔍 检查 Redis 服务状态..."
for i in {1..30}; do
    if docker-compose ps redis | grep -q "healthy"; then
        echo "✅ Redis 已启动"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "⚠️  Redis 启动超时，但继续执行..."
    fi
    sleep 2
done

echo ""
echo "📊 初始化数据..."
echo "执行数据预处理..."
docker-compose exec -T backend python data/preprocessor.py || echo "⚠️  数据预处理可能已有数据或遇到错误，继续..."

echo ""
echo "🤖 训练推荐模型..."
docker-compose exec -T backend python train_model.py || echo "⚠️  模型训练可能遇到错误，继续..."

echo ""
echo "=========================================="
echo "✅ 服务启动完成！"
echo "=========================================="
echo ""
echo "📱 访问地址："
echo "  前端界面: http://localhost:8080"
echo "  后端 API: http://localhost:5000"
echo "  健康检查: http://localhost:5000/health"
echo ""
echo "📋 常用命令："
echo "  查看日志: docker-compose logs -f"
echo "  停止服务: docker-compose down"
echo "  重启服务: docker-compose restart"
echo "  查看状态: docker-compose ps"
echo ""
echo "=========================================="

