#!/bin/bash
# 云主机非 Docker 部署脚本
# 适用于 Ubuntu 20.04 系统
# 直接在云主机上安装和运行前后端服务

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
log_info "云主机非 Docker 部署脚本"
echo "=========================================="
echo ""

# 检查是否为 root
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
    log_warning "建议使用 sudo 运行此脚本"
fi

# 获取服务器信息
SERVER_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=""

# 询问公网 IP
echo "检测到服务器内网 IP: $SERVER_IP"
read -p "请输入服务器的公网 IP（用于前端访问后端）: " PUBLIC_IP
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$SERVER_IP
    log_warning "未输入公网 IP，使用内网 IP: $PUBLIC_IP"
fi

echo ""
echo "配置信息:"
echo "  服务器内网 IP: $SERVER_IP"
echo "  服务器公网 IP: $PUBLIC_IP"
echo "  前端访问地址: http://$PUBLIC_IP (通过 Nginx)"
echo "  后端 API 地址: http://$PUBLIC_IP:5000 (直接访问，可选)"
echo ""

read -p "是否继续部署? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# 进入项目目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 步骤1：检查系统版本
log_info "步骤1: 检查系统版本..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    log_info "检测到系统: $NAME $VERSION"
    if [[ "$ID" != "ubuntu" ]] || [[ "$VERSION_ID" != "20.04" ]]; then
        log_warning "此脚本主要针对 Ubuntu 20.04 优化，当前系统: $ID $VERSION_ID"
        read -p "是否继续? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    log_warning "无法检测系统版本，继续执行..."
fi

# 步骤2：安装系统依赖
log_info "步骤2: 安装系统依赖（Ubuntu 20.04）..."

if command -v apt-get >/dev/null 2>&1; then
    log_info "使用 apt-get 安装依赖..."
    $SUDO apt-get update
    
    # Ubuntu 20.04 默认 Node.js 版本可能较旧，需要添加 NodeSource 仓库
    log_info "配置 Node.js 仓库..."
    if ! command -v node >/dev/null 2>&1 || ! node --version 2>/dev/null | grep -q "v1[6-9]\|v2[0-9]"; then
        log_info "安装 Node.js 18.x..."
        # 检查是否已安装 Node.js 18+
        NEED_NODEJS=true
        if command -v node >/dev/null 2>&1; then
            NODE_VERSION=$(node --version 2>/dev/null || echo "")
            if echo "$NODE_VERSION" | grep -q "v1[6-9]\|v2[0-9]"; then
                log_info "Node.js 版本已满足要求: $NODE_VERSION"
                NEED_NODEJS=false
            fi
        fi
        
        if [ "$NEED_NODEJS" = true ]; then
            log_info "添加 NodeSource 仓库..."
            if [ -n "$SUDO" ]; then
                curl -fsSL https://deb.nodesource.com/setup_18.x | $SUDO bash -
            else
                curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
            fi
        fi
    else
        log_info "Node.js 已安装且版本满足要求"
    fi
    
    # 先安装基础工具（包括 curl，用于下载 Node.js 仓库脚本）
    $SUDO apt-get install -y curl git build-essential
    
    # 如果 Node.js 需要安装，先配置仓库
    if [ "$NEED_NODEJS" = true ] 2>/dev/null; then
        log_info "安装 Node.js 18.x..."
        $SUDO apt-get install -y nodejs
    fi
    
    # 安装其他依赖
    $SUDO apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        mysql-server \
        redis-server \
        nginx \
        nodejs \
        build-essential \
        gcc \
        g++
elif command -v yum >/dev/null 2>&1; then
    log_info "使用 yum 安装依赖（CentOS/RHEL）..."
    $SUDO yum install -y \
        python3 \
        python3-pip \
        mysql-server \
        redis \
        nginx \
        nodejs \
        npm \
        curl \
        git
else
    log_error "未找到包管理器（apt-get 或 yum）"
    log_error "此脚本主要支持 Ubuntu 20.04 系统"
    exit 1
fi

log_success "系统依赖安装完成"
echo ""

# 步骤3：配置 MySQL
log_info "步骤3: 配置 MySQL..."

# 启动 MySQL
if command -v systemctl >/dev/null 2>&1; then
    $SUDO systemctl start mysql 2>/dev/null || $SUDO systemctl start mysqld 2>/dev/null || true
    $SUDO systemctl enable mysql 2>/dev/null || $SUDO systemctl enable mysqld 2>/dev/null || true
fi

# 等待 MySQL 启动
sleep 3

# 创建数据库
log_info "创建数据库..."
$SUDO mysql -u root <<EOF 2>/dev/null || true
CREATE DATABASE IF NOT EXISTS canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
EOF

# 导入初始化脚本
if [ -f "backend/database/init.sql" ]; then
    log_info "导入数据库初始化脚本..."
    $SUDO mysql -u root canteen_recommendation < backend/database/init.sql 2>/dev/null || log_warning "数据库初始化可能失败，继续..."
fi

log_success "MySQL 配置完成"
echo ""

# 步骤4：配置 Redis
log_info "步骤4: 配置 Redis..."

if command -v systemctl >/dev/null 2>&1; then
    $SUDO systemctl start redis-server 2>/dev/null || $SUDO systemctl start redis 2>/dev/null || true
    $SUDO systemctl enable redis-server 2>/dev/null || $SUDO systemctl enable redis 2>/dev/null || true
fi

log_success "Redis 配置完成"
echo ""

# 步骤5：配置后端
log_info "步骤5: 配置后端..."

cd backend

# 检查 Python 版本
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
log_info "检测到 Python 版本: $PYTHON_VERSION"

# 检查是否有 Python 3.9+
if command -v python3.9 >/dev/null 2>&1; then
    PYTHON_CMD="python3.9"
    log_info "使用 Python 3.9"
elif command -v python3.10 >/dev/null 2>&1; then
    PYTHON_CMD="python3.10"
    log_info "使用 Python 3.10"
else
    PYTHON_CMD="python3"
    log_warning "使用默认 Python 3，建议使用 Python 3.9+"
fi

# 创建虚拟环境
if [ ! -d "venv" ]; then
    log_info "创建 Python 虚拟环境（使用 $PYTHON_CMD）..."
    $PYTHON_CMD -m venv venv
else
    log_info "虚拟环境已存在，检查 Python 版本..."
    VENV_PYTHON_VERSION=$(venv/bin/python3 --version 2>&1 | awk '{print $2}')
    log_info "虚拟环境 Python 版本: $VENV_PYTHON_VERSION"
    
    # 如果虚拟环境使用的是 Python 3.8，且系统有 Python 3.9+，重新创建
    if echo "$VENV_PYTHON_VERSION" | grep -q "^3\.8" && command -v python3.9 >/dev/null 2>&1; then
        log_warning "虚拟环境使用 Python 3.8，重新创建使用 Python 3.9..."
        rm -rf venv
        python3.9 -m venv venv
    fi
fi

# 激活虚拟环境并安装依赖
log_info "安装 Python 依赖..."
source venv/bin/activate
pip3 install --upgrade pip

# 尝试多个镜像源安装依赖
log_info "尝试从多个镜像源安装依赖..."
MIRRORS=(
    "https://pypi.tuna.tsinghua.edu.cn/simple"
    "https://mirrors.aliyun.com/pypi/simple"
    "https://pypi.douban.com/simple"
    "https://pypi.org/simple"
)

INSTALLED=false
for mirror in "${MIRRORS[@]}"; do
    log_info "尝试使用镜像源: $mirror"
    if pip3 install -r requirements.txt -i "$mirror" --trusted-host "$(echo $mirror | sed 's|https\?://||' | sed 's|/.*||')" 2>&1 | tee /tmp/pip_install.log; then
        log_success "依赖安装成功（使用镜像源: $mirror）"
        INSTALLED=true
        break
    else
        log_warning "镜像源 $mirror 安装失败，尝试下一个..."
    fi
done

# 如果所有镜像源都失败，尝试官方源
if [ "$INSTALLED" = false ]; then
    log_warning "所有镜像源都失败，尝试官方 PyPI 源..."
    pip3 install -r requirements.txt || {
        log_error "依赖安装失败，请检查网络连接和 requirements.txt"
        log_info "查看详细错误信息: cat /tmp/pip_install.log"
        exit 1
    }
fi

# 创建 .env 文件
log_info "创建后端环境变量文件..."
cat > .env <<EOF
# 数据库配置
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=password
MYSQL_DATABASE=canteen_recommendation

# Redis 配置
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0

# 服务器配置
SERVER_IP=$PUBLIC_IP
EOF

log_success "后端配置完成"
cd ..
echo ""

# 步骤6：配置前端
log_info "步骤6: 配置前端..."

cd frontend

# 检查并清理 node_modules（如果是从其他平台复制的）
if [ -d "node_modules" ]; then
    log_warning "检测到 node_modules 目录，可能是从其他平台复制的"
    log_info "清理 node_modules 以确保平台兼容性..."
    rm -rf node_modules
    rm -f package-lock.json
    log_success "已清理 node_modules"
fi

# 安装依赖（在 Linux 平台上）
log_info "在 Linux 平台上安装前端依赖..."
npm install --registry=https://registry.npmmirror.com || npm install

# 验证安装
if [ ! -d "node_modules" ]; then
    log_error "前端依赖安装失败"
    exit 1
fi

log_success "前端依赖安装完成"

# 构建前端
log_info "构建前端生产版本..."
npm run build

if [ ! -d "dist" ]; then
    log_error "前端构建失败"
    exit 1
fi

log_success "前端构建完成"

# 将前端文件复制到标准位置（避免 /root 目录权限问题）
log_info "将前端文件部署到标准位置..."
$SUDO mkdir -p /var/www/canteen
$SUDO cp -r dist/* /var/www/canteen/
$SUDO chown -R www-data:www-data /var/www/canteen
$SUDO chmod -R 755 /var/www/canteen
log_success "前端文件已部署到 /var/www/canteen"

# 创建前端环境变量文件（用于构建时）
log_info "创建前端环境变量文件..."
cat > .env.production <<EOF
VITE_API_URL=http://$PUBLIC_IP:5000
EOF

# 注意：如果使用 Nginx 代理，前端使用相对路径即可
# 这里设置的是直接访问后端的情况

log_success "前端配置完成"
cd ..
echo ""

# 步骤7：配置 Nginx
log_info "步骤7: 配置 Nginx 反向代理..."

NGINX_CONFIG="/etc/nginx/sites-available/canteen"
PROJECT_PATH="$SCRIPT_DIR"
FRONTEND_DIST="$PROJECT_PATH/frontend/dist"
TARGET_DIR="/var/www/canteen"

# 将前端文件复制到标准位置（避免 /root 目录权限问题）
log_info "将前端文件复制到标准位置..."
$SUDO mkdir -p "$TARGET_DIR"
if [ -d "$FRONTEND_DIST" ] && [ -f "$FRONTEND_DIST/index.html" ]; then
    $SUDO cp -r "$FRONTEND_DIST"/* "$TARGET_DIR/" 2>/dev/null || true
    $SUDO chown -R www-data:www-data "$TARGET_DIR"
    $SUDO chmod -R 755 "$TARGET_DIR"
    log_success "前端文件已复制到 $TARGET_DIR"
else
    log_warning "前端文件不存在，稍后需要构建"
fi

# 使用标准位置创建 Nginx 配置
$SUDO tee "$NGINX_CONFIG" > /dev/null <<EOF
server {
    listen 80;
    server_name $PUBLIC_IP;

    # 日志配置
    access_log /var/log/nginx/canteen-access.log;
    error_log /var/log/nginx/canteen-error.log;

    # 前端静态文件（使用标准位置）
    location / {
        root $TARGET_DIR;
        index index.html;
        try_files \$uri \$uri/ /index.html;
        
        # 静态资源缓存
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # 后端 API 代理
    location /api {
        proxy_pass http://127.0.0.1:5000/api;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # 健康检查
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        proxy_set_header Host \$host;
    }
}
EOF

# 启用配置
$SUDO ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/canteen
$SUDO rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# 测试配置
$SUDO nginx -t

# 重启 Nginx
$SUDO systemctl restart nginx
$SUDO systemctl enable nginx

log_success "Nginx 配置完成"
echo ""

# 步骤8：创建 systemd 服务
log_info "步骤8: 创建 systemd 服务..."

# 后端服务
BACKEND_PATH="$SCRIPT_DIR/backend"
$SUDO tee /etc/systemd/system/canteen-backend.service > /dev/null <<EOF
[Unit]
Description=Canteen Recommendation Backend Service
After=network.target mysql.service redis.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$BACKEND_PATH
Environment="PATH=$BACKEND_PATH/venv/bin"
Environment="FLASK_HOST=127.0.0.1"
Environment="FLASK_PORT=5000"
Environment="FLASK_DEBUG=False"
ExecStart=$BACKEND_PATH/venv/bin/python3 app.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 前端服务（使用 Nginx，不需要单独服务）
log_info "前端使用 Nginx 提供服务，无需单独服务"

# 重新加载 systemd
$SUDO systemctl daemon-reload

# 启动后端服务
log_info "启动后端服务..."
$SUDO systemctl enable canteen-backend
$SUDO systemctl start canteen-backend

log_success "服务配置完成"
echo ""

# 步骤9：验证 Python 依赖安装
log_info "步骤9: 验证 Python 依赖安装..."

cd backend
source venv/bin/activate

# 检查关键依赖
log_info "检查关键依赖..."
if ! python3 -c "import pandas" 2>/dev/null; then
    log_error "pandas 未安装，重新安装依赖..."
    pip3 install --upgrade pip
    
    # 注意：版本号需要用引号包裹，避免 shell 解释 < 为重定向
    pip3 install "pandas>=2.0.0,<2.1.0" -i https://pypi.tuna.tsinghua.edu.cn/simple || \
    pip3 install "pandas>=2.0.0,<2.1.0" -i https://mirrors.aliyun.com/pypi/simple || \
    pip3 install "pandas>=2.0.0,<2.1.0"
    
    # 重新安装所有依赖
    pip3 install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple || \
    pip3 install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple || \
    pip3 install -r requirements.txt
fi

# 验证关键依赖
REQUIRED_MODULES=("pandas" "numpy" "flask" "pymysql" "redis")
MISSING_MODULES=()

for module in "${REQUIRED_MODULES[@]}"; do
    if ! python3 -c "import $module" 2>/dev/null; then
        MISSING_MODULES+=("$module")
        log_warning "缺少模块: $module"
    else
        log_success "模块已安装: $module"
    fi
done

if [ ${#MISSING_MODULES[@]} -gt 0 ]; then
    log_error "缺少以下模块: ${MISSING_MODULES[*]}"
    log_info "重新安装所有依赖..."
    python3 -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple || \
    python3 -m pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple || \
    python3 -m pip install -r requirements.txt
    
    # 再次验证
    sleep 2
    ALL_OK=true
    for module in "${REQUIRED_MODULES[@]}"; do
        if ! python3 -c "import $module" 2>/dev/null; then
            log_error "模块仍然缺失: $module"
            ALL_OK=false
        fi
    done
    
    if [ "$ALL_OK" = false ]; then
        log_error "依赖安装失败，请手动检查"
        log_info "运行修复脚本: ./fix-backend-deps-manual.sh"
        exit 1
    fi
else
    log_success "所有关键依赖已安装"
fi

cd ..
echo ""

# 步骤10：初始化数据
log_info "步骤10: 初始化数据..."

sleep 5  # 等待后端启动

log_info "执行数据预处理..."
cd backend
source venv/bin/activate

if python3 data/preprocessor.py 2>&1; then
    log_success "数据预处理完成"
else
    log_warning "数据预处理可能已有数据或遇到错误，继续..."
fi

echo ""
log_info "训练推荐模型..."
if python3 train_model.py 2>&1; then
    log_success "模型训练完成"
else
    log_warning "模型训练可能遇到错误，继续..."
fi

cd ..
echo ""

# 步骤11：配置防火墙
log_info "步骤11: 配置防火墙..."

if command -v ufw >/dev/null 2>&1; then
    log_info "配置 UFW 防火墙..."
    $SUDO ufw allow 22/tcp
    $SUDO ufw allow 80/tcp
    $SUDO ufw allow 5000/tcp  # 如果需要直接访问后端
    $SUDO ufw --force enable
elif command -v firewall-cmd >/dev/null 2>&1; then
    log_info "配置 firewalld 防火墙..."
    $SUDO firewall-cmd --permanent --add-service=ssh
    $SUDO firewall-cmd --permanent --add-service=http
    $SUDO firewall-cmd --permanent --add-port=5000/tcp
    $SUDO firewall-cmd --reload
fi

log_success "防火墙配置完成"
echo ""

# 步骤12：验证服务
log_info "步骤12: 验证服务状态..."

sleep 3

# 检查后端服务
if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
    log_success "后端服务运行中"
else
    log_warning "后端服务可能未正常启动，请检查日志"
fi

# 检查 Nginx
if $SUDO systemctl is-active nginx >/dev/null 2>&1; then
    log_success "Nginx 服务运行中"
else
    log_warning "Nginx 服务可能未正常启动"
fi

# 测试后端
if curl -s http://localhost:5000/health >/dev/null 2>&1; then
    log_success "后端 API 正常响应"
else
    log_warning "后端 API 可能未正常响应"
fi

# 测试前端
if curl -s http://localhost:80 >/dev/null 2>&1; then
    log_success "前端服务正常响应"
else
    log_warning "前端服务可能未正常响应"
fi

echo ""
echo "=========================================="
log_success "部署完成！"
echo "=========================================="
echo ""
echo "📱 访问地址："
echo -e "  前端界面: ${GREEN}http://$PUBLIC_IP${NC}"
echo -e "  后端 API: ${GREEN}http://$PUBLIC_IP:5000${NC}"
echo -e "  健康检查: ${GREEN}http://$PUBLIC_IP:5000/health${NC}"
echo ""
echo "📋 常用命令："
echo "  查看后端日志: sudo journalctl -u canteen-backend -f"
echo "  查看 Nginx 日志: sudo tail -f /var/log/nginx/error.log"
echo "  重启后端: sudo systemctl restart canteen-backend"
echo "  重启 Nginx: sudo systemctl restart nginx"
echo "  查看服务状态: sudo systemctl status canteen-backend"
echo ""
echo "🎮 服务管理："
echo "  使用管理脚本: sudo ./manage-services.sh"
echo "  或直接使用 systemctl 命令管理服务"
echo ""
log_info "重要提示："
echo "  ✅ 部署脚本只需运行一次"
echo "  ✅ 所有服务已设置为开机自启"
echo "  ✅ 后续通过 systemctl 命令管理服务"
echo "  ✅ 无需再次运行部署脚本"
echo ""
echo "🔒 安全提示："
echo "  1. 请修改 MySQL root 密码"
echo "  2. 建议配置 HTTPS（使用 Let's Encrypt）"
echo "  3. 定期更新系统和依赖"
echo ""
echo "📖 详细文档请查看: 云主机非Docker部署指南.md"
echo "=========================================="

