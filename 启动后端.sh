#!/bin/bash
# 启动后端服务的完整脚本
# 适用于本地开发和测试环境（Ubuntu/Debian/macOS）

set -e  # 遇到错误立即退出

echo "=========================================="
echo "启动后端服务 (Ubuntu 版本)"
echo "=========================================="
echo ""

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}INFO: $1${NC}"; }
log_success() { echo -e "${GREEN}SUCCESS: $1${NC}"; }
log_warning() { echo -e "${YELLOW}WARNING: $1${NC}"; }
log_error() { echo -e "${RED}ERROR: $1${NC}"; }

# 检测操作系统类型
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS_TYPE="linux"
        # 检测 Linux 发行版
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS_DISTRO=$ID
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macos"
    else
        OS_TYPE="unknown"
    fi
}

# 检查 MySQL
check_mysql() {
    log_info "检查 MySQL..."
    
    if ! command -v mysql >/dev/null 2>&1; then
        log_error "MySQL 未安装"
        if [ "$OS_TYPE" == "macos" ]; then
            echo "请先安装 MySQL: brew install mysql"
        else
            echo "请先安装 MySQL: sudo apt install mysql-server"
        fi
        exit 1
    fi

    # 根据操作系统类型检查服务状态
    if [ "$OS_TYPE" == "macos" ]; then
        # macOS 使用 brew services
        if ! brew services list 2>/dev/null | grep -q "mysql.*started"; then
            log_warning "MySQL 服务未启动，正在启动..."
            brew services start mysql || {
                log_error "无法启动 MySQL 服务"
                echo "请手动启动: brew services start mysql"
                exit 1
            }
            log_info "等待 MySQL 启动（5秒）..."
            sleep 5
        else
            log_success "MySQL 服务运行中"
        fi
        MYSQL_PREFIX=""
    else
        # Linux 使用 systemctl
        if command -v systemctl >/dev/null 2>&1; then
            if ! sudo systemctl is-active mysql >/dev/null 2>&1 && ! sudo systemctl is-active mysqld >/dev/null 2>&1; then
                log_warning "MySQL 服务未启动，正在启动..."
                sudo systemctl start mysql 2>/dev/null || sudo systemctl start mysqld 2>/dev/null || {
                    log_error "无法启动 MySQL 服务"
                    echo "请手动启动: sudo systemctl start mysql"
                    exit 1
                }
                log_info "等待 MySQL 启动（5秒）..."
                sleep 5
            else
                log_success "MySQL 服务运行中"
            fi
        fi
        
        # 测试 MySQL 连接
        if ! mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
            log_warning "MySQL 连接测试失败，尝试使用 sudo..."
            if ! sudo mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
                log_warning "无法使用 root 连接，可能需要密码"
                MYSQL_PREFIX=""
            else
                MYSQL_PREFIX="sudo "
            fi
        else
            MYSQL_PREFIX=""
        fi
    fi
}

# 检查 Redis
check_redis() {
    log_info "检查 Redis..."
    
    if ! command -v redis-cli >/dev/null 2>&1; then
        log_warning "Redis 未安装（可选，推荐功能需要）"
        if [ "$OS_TYPE" == "macos" ]; then
            echo "安装 Redis: brew install redis"
        else
            echo "安装 Redis: sudo apt install redis-server"
        fi
        return
    fi
    
    if [ "$OS_TYPE" == "macos" ]; then
        # macOS 使用 brew services
        if ! brew services list 2>/dev/null | grep -q "redis.*started"; then
            log_warning "Redis 服务未启动，正在启动..."
            brew services start redis 2>/dev/null || log_warning "Redis 启动失败，继续..."
            sleep 2
        else
            log_success "Redis 服务运行中"
        fi
    else
        # Linux 使用 systemctl
        if command -v systemctl >/dev/null 2>&1; then
            if ! sudo systemctl is-active redis >/dev/null 2>&1 && ! sudo systemctl is-active redis-server >/dev/null 2>&1; then
                log_warning "Redis 服务未启动，正在启动..."
                sudo systemctl start redis 2>/dev/null || sudo systemctl start redis-server 2>/dev/null || log_warning "Redis 启动失败，继续..."
                sleep 2
            else
                log_success "Redis 服务运行中"
            fi
        fi
    fi
    
    # 测试 Redis 连接
    if redis-cli ping >/dev/null 2>&1; then
        log_success "Redis 连接正常"
    else
        log_warning "Redis 连接失败，但继续启动（可选服务）"
    fi
}

# 检查并初始化数据库
setup_database() {
    log_info "检查数据库..."
    
    # 检查数据库是否存在
    if ${MYSQL_PREFIX}mysql -u root -e "USE canteen_recommendation;" >/dev/null 2>&1; then
        log_success "数据库存在"
    else
        log_warning "数据库不存在，正在创建..."
        ${MYSQL_PREFIX}mysql -u root << 'EOF'
CREATE DATABASE IF NOT EXISTS canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF
        if [ $? -eq 0 ]; then
            log_success "数据库创建成功"
        else
            log_error "数据库创建失败"
            exit 1
        fi
    fi

    # 导入初始化脚本
    if [ -f "backend/database/init.sql" ]; then
        log_info "导入数据库初始化脚本..."
        if ${MYSQL_PREFIX}mysql -u root canteen_recommendation < backend/database/init.sql; then
            log_success "数据库初始化完成"
        else
            log_warning "数据库初始化失败，但继续启动"
        fi
    else
        log_warning "未找到数据库初始化脚本: backend/database/init.sql"
    fi
}

# 设置 Python 环境
setup_python_env() {
    log_info "检查 Python 环境..."
    
    # 首先检查backend目录是否存在
    if [ ! -d "backend" ]; then
        log_error "backend 目录不存在"
        log_info "当前目录内容:"
        ls -la
        log_info "请确保在项目根目录运行脚本"
        exit 1
    fi

    cd backend || {
        log_error "无法进入 backend 目录"
        exit 1
    }

    # 检查 Python
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Python 3 未安装"
        echo "安装命令: sudo apt update && sudo apt install python3 python3-pip python3-venv"
        exit 1
    fi

    log_success "Python 版本: $(python3 --version)"

    # 检查并安装 python3-venv（在Ubuntu上需要单独安装）
    if ! python3 -c "import ensurepip" &>/dev/null; then
        log_warning "python3-venv 未安装，正在安装..."
        if [ "$OS_TYPE" = "linux" ]; then
            sudo apt update && sudo apt install -y python3-venv
        fi
    fi

    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        log_info "创建 Python 虚拟环境..."
        if python3 -m venv venv; then
            log_success "虚拟环境创建成功"
            # 检查虚拟环境结构
            if [ ! -f "venv/bin/activate" ]; then
                log_warning "虚拟环境结构异常，尝试修复..."
                # 重新创建
                rm -rf venv
                python3 -m venv venv
            fi
        else
            log_error "无法创建虚拟环境"
            log_info "尝试使用 virtualenv..."
            if command -v virtualenv >/dev/null 2>&1 || pip3 install virtualenv; then
                virtualenv venv
            else
                log_error "virtualenv 也安装失败"
                log_info "请手动安装: sudo apt install python3-venv 或 pip3 install virtualenv"
                exit 1
            fi
        fi
    else
        log_success "虚拟环境已存在"
    fi

    # 检查激活脚本是否存在
    if [ ! -f "venv/bin/activate" ]; then
        log_error "虚拟环境激活脚本不存在"
        log_info "venv 目录内容:"
        ls -la venv/ 2>/dev/null || echo "venv 目录不存在"
        log_info "尝试重新创建虚拟环境..."
        rm -rf venv
        python3 -m venv venv
    fi

    # 激活虚拟环境
    log_info "激活虚拟环境..."
    source venv/bin/activate || {
        log_error "无法激活虚拟环境"
        log_info "检查虚拟环境结构:"
        find venv -name "activate" -type f 2>/dev/null
        exit 1
    }
    log_success "虚拟环境已激活"

    # 升级pip
    log_info "升级 pip..."
    pip3 install --upgrade pip

    # 检查并安装依赖
    if [ ! -f "requirements.txt" ]; then
        log_warning "requirements.txt 不存在，创建基础依赖文件..."
        cat > requirements.txt << 'EOF'
flask>=2.0.0
numpy>=1.21.0
pandas>=1.3.0
scikit-learn>=1.0.0
sqlalchemy>=1.4.0
pymysql>=1.0.0
redis>=4.0.0
EOF
    fi

    log_info "安装 Python 依赖..."
    if pip3 install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple; then
        log_success "依赖安装完成"
    else
        log_warning "使用镜像安装失败，尝试官方源..."
        pip3 install -r requirements.txt || {
            log_error "依赖安装失败"
            log_info "尝试逐个安装关键依赖..."
            pip3 install flask numpy pandas scikit-learn sqlalchemy pymysql redis || {
                log_error "关键依赖安装失败"
                exit 1
            }
        }
    fi
}
# setup_python_env() {
#     log_info "检查 Python 环境..."
    
#     cd backend

#     # 检查 Python
#     if ! command -v python3 >/dev/null 2>&1; then
#         log_error "Python 3 未安装"
#         echo "请安装 Python 3: sudo apt install python3 python3-pip python3-venv"
#         exit 1
#     fi

#     log_success "Python 版本: $(python3 --version)"

#     # 创建虚拟环境
#     if [ ! -d "venv" ]; then
#         log_info "创建 Python 虚拟环境..."
#         if ! python3 -m venv venv; then
#             log_error "无法创建虚拟环境"
#             echo "请安装 python3-venv: sudo apt install python3-venv"
#             exit 1
#         fi
#         log_success "虚拟环境创建成功"
#     else
#         log_success "虚拟环境已存在"
#     fi

#     # 激活虚拟环境
#     source venv/bin/activate
#     log_success "虚拟环境已激活"

#     # 检查并安装依赖
#     if [ ! -f "requirements.txt" ]; then
#         log_warning "requirements.txt 不存在，创建基础依赖文件..."
#         cat > requirements.txt << 'EOF'
# flask>=2.0.0
# numpy>=1.21.0
# pandas>=1.3.0
# scikit-learn>=1.0.0
# sqlalchemy>=1.4.0
# pymysql>=1.0.0
# redis>=4.0.0
# EOF
#     fi

#     # 检查关键依赖
#     if ! python3 -c "import flask" >/dev/null 2>&1; then
#         log_info "安装 Python 依赖..."
#         if pip3 install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple; then
#             log_success "依赖安装完成"
#         else
#             log_warning "使用镜像安装失败，尝试官方源..."
#             pip3 install -r requirements.txt || {
#                 log_error "依赖安装失败"
#                 exit 1
#             }
#         fi
#     else
#         log_success "Python 依赖已安装"
#     fi
# }

# 检查数据和模型
check_data_and_models() {
    log_info "检查数据和模型..."
    
    # 检查模型文件是否存在
    if [ ! -f "models/recommender_model.pkl" ] && [ -f "train_model.py" ]; then
        log_warning "模型文件不存在，训练模型..."
        if python3 train_model.py; then
            log_success "模型训练完成"
        else
            log_warning "模型训练失败，但继续启动"
        fi
    fi

    # 检查处理后的数据
    if [ ! -d "data/processed" ] && [ -f "data/preprocessor.py" ]; then
        log_warning "处理后的数据不存在，执行数据预处理..."
        if python3 data/preprocessor.py; then
            log_success "数据预处理完成"
        else
            log_warning "数据预处理失败，但继续启动"
        fi
    fi
}

# 显示启动信息
show_startup_info() {
    echo ""
    echo "=========================================="
    log_info "启动后端服务..."
    echo "=========================================="
    echo ""
    echo "后端将在 http://localhost:5000 启动"
    echo "健康检查: http://localhost:5000/health"
    echo ""
    echo "项目目录: $(pwd)"
    echo "Python 环境: $(which python3)"
    echo ""
    echo "按 Ctrl+C 停止服务"
    echo ""
}

# 主函数
main() {
    log_info "开始启动后端服务..."
    
    detect_os
    check_mysql
    check_redis
    setup_database
    setup_python_env
    check_data_and_models
    show_startup_info
    
    # 启动后端服务
    log_info "启动 Flask 应用..."
    python3 app.py
}

# 信号处理
trap 'echo ""; log_info "后端服务已停止"; exit 0' INT TERM

# 运行主函数
main "$@"