#!/bin/bash
# 一键安装所有需要的环境 (Ubuntu 优化版)

set -e

echo "=========================================="
echo "一键安装项目运行环境 (Ubuntu 版本)"
echo "=========================================="
echo ""

# 记录开始时间
START_TIME=$(date +%s)

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 检查系统
check_system() {
    log_info "检查系统环境..."
    if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null && ! grep -q "Debian" /etc/os-release 2>/dev/null; then
        log_warning "这个脚本主要为 Ubuntu/Debian 系统设计"
        read -p "是否继续？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 检查并获取 sudo 权限
check_sudo() {
    log_info "检查 sudo 权限..."
    if [ "$EUID" -ne 0 ]; then
        log_info "需要 sudo 权限来安装软件包"
        if ! sudo -v; then
            log_error "需要 sudo 权限"
            exit 1
        fi
    fi
}

# 安装基础依赖
install_basic_deps() {
    log_info "安装基础系统依赖..."
    sudo apt update
    
    # 安装必要的工具
    sudo apt install -y \
        curl wget git build-essential \
        software-properties-common \
        apt-transport-https ca-certificates \
        gnupg lsb-release
}

# 安装 MySQL
install_mysql() {
    echo ""
    log_info "步骤1: 安装 MySQL"
    
    if command -v mysql &> /dev/null; then
        log_success "MySQL 已安装"
    else
        log_info "安装 MySQL..."
        
        # 添加 MySQL APT 仓库（可选，获取最新版本）
        # wget https://dev.mysql.com/get/mysql-apt-config_0.8.24-1_all.deb
        # sudo dpkg -i mysql-apt-config_0.8.24-1_all.deb
        # sudo apt update
        
        sudo apt install -y mysql-server mysql-client
        
        if [ $? -eq 0 ]; then
            log_success "MySQL 安装完成"
        else
            log_error "MySQL 安装失败"
            return 1
        fi
    fi

    # 确保 MySQL 服务运行
    log_info "配置 MySQL 服务..."
    sudo systemctl enable mysql
    sudo systemctl start mysql
    
    # 等待 MySQL 完全启动
    for i in {1..30}; do
        if sudo systemctl is-active --quiet mysql; then
            log_success "MySQL 服务已启动"
            break
        fi
        sleep 1
        if [ $i -eq 30 ]; then
            log_warning "MySQL 启动较慢，继续执行..."
        fi
    done
    
    # 安全配置（非交互式）
    log_info "运行 MySQL 安全配置..."
    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';"
    sudo mysql -e "DELETE FROM mysql.user WHERE User='';"
    sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    sudo mysql -e "DROP DATABASE IF EXISTS test;"
    sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    sudo mysql -e "FLUSH PRIVILEGES;"
}

# 安装 Redis
install_redis() {
    echo ""
    log_info "步骤2: 安装 Redis"
    
    if command -v redis-server &> /dev/null; then
        log_success "Redis 已安装"
    else
        log_info "安装 Redis..."
        sudo apt install -y redis-server
        if [ $? -eq 0 ]; then
            log_success "Redis 安装完成"
        else
            log_warning "Redis 安装失败，跳过"
            return 1
        fi
    fi

    # 配置 Redis
    log_info "配置 Redis..."
    sudo systemctl enable redis-server
    sudo systemctl start redis-server
    sleep 2
}

# 配置数据库
setup_database() {
    echo ""
    log_info "步骤3: 配置数据库"
    
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "尝试创建数据库 (尝试 $attempt/$max_attempts)..."
        
        # 尝试无密码连接创建数据库
        if sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null; then
            log_success "数据库创建成功"
            break
        else
            log_warning "数据库创建失败 (尝试 $attempt)"
            if [ $attempt -eq $max_attempts ]; then
                log_warning "无法自动创建数据库"
                echo "请手动运行:"
                echo "  sudo mysql -u root"
                echo "  CREATE DATABASE IF NOT EXISTS canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
                echo "  exit;"
            fi
        fi
        ((attempt++))
        sleep 2
    done

    # 导入初始化脚本
    if [ -f "backend/database/init.sql" ]; then
        log_info "导入数据库初始化脚本..."
        if sudo mysql -u root canteen_recommendation < backend/database/init.sql 2>/dev/null; then
            log_success "数据库初始化完成"
        else
            log_warning "无法自动导入数据库脚本"
            echo "请手动运行:"
            echo "  sudo mysql -u root canteen_recommendation < backend/database/init.sql"
        fi
    else
        log_warning "未找到数据库初始化脚本: backend/database/init.sql"
    fi
}

# 设置 Python 环境
setup_python() {
    echo ""
    log_info "步骤4: 设置 Python 环境"
    
    # 检查 Python
    if ! command -v python3 &> /dev/null; then
        log_info "安装 Python 3..."
        sudo apt install -y python3 python3-pip python3-venv python3-dev
    fi
    
    log_success "Python 版本: $(python3 --version)"
    log_success "Pip 版本: $(pip3 --version 2>/dev/null || echo '未安装')"

    # 进入 backend 目录
    if [ ! -d "backend" ]; then
        log_error "未找到 backend 目录"
        return 1
    fi
    
    cd backend

    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        log_info "创建 Python 虚拟环境..."
        python3 -m venv venv
        if [ $? -eq 0 ]; then
            log_success "虚拟环境创建成功"
        else
            log_error "虚拟环境创建失败"
            # 尝试安装 venv 模块
            sudo apt install -y python3-venv
            python3 -m venv venv || {
                log_error "无法创建虚拟环境"
                return 1
            }
        fi
    else
        log_success "虚拟环境已存在"
    fi

    # 激活虚拟环境
    source venv/bin/activate
    log_success "虚拟环境已激活"

    # 升级 pip
    log_info "升级 pip..."
    pip3 install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple > /dev/null 2>&1 || {
        pip3 install --upgrade pip > /dev/null 2>&1 || true
    }

    # 检查 requirements.txt
    if [ ! -f "requirements.txt" ]; then
        log_warning "未找到 requirements.txt，创建基础 requirements.txt"
        cat > requirements.txt << 'EOF'
flask>=2.0.0
numpy>=1.21.0
pandas>=1.3.0
scikit-learn>=1.0.0
matplotlib>=3.5.0
seaborn>=0.11.0
sqlalchemy>=1.4.0
pymysql>=1.0.0
redis>=4.0.0
EOF
    fi

    # 安装依赖
    log_info "安装 Python 依赖..."
    local pip_attempt=1
    local max_pip_attempts=2
    
    while [ $pip_attempt -le $max_pip_attempts ]; do
        if [ $pip_attempt -eq 1 ]; then
            log_info "尝试使用国内镜像..."
            pip3 install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
        else
            log_info "尝试使用默认源..."
            pip3 install -r requirements.txt
        fi
        
        if [ $? -eq 0 ]; then
            log_success "Python 依赖安装完成"
            break
        else
            log_warning "依赖安装失败 (尝试 $pip_attempt)"
            if [ $pip_attempt -eq $max_pip_attempts ]; then
                log_warning "尝试安装核心依赖..."
                pip3 install flask numpy pandas scikit-learn pymysql redis || {
                    log_error "核心依赖安装失败"
                    return 1
                }
            fi
        fi
        ((pip_attempt++))
    done
}

# 初始化数据
initialize_data() {
    echo ""
    log_info "步骤5: 初始化数据"
    
    # 数据预处理
    if [ -f "data/preprocessor.py" ]; then
        log_info "执行数据预处理..."
        if python3 data/preprocessor.py; then
            log_success "数据预处理完成"
        else
            log_warning "数据预处理失败，继续执行"
        fi
    else
        log_warning "未找到 data/preprocessor.py，跳过数据预处理"
    fi

    # 训练模型
    if [ -f "train_model.py" ]; then
        log_info "训练推荐模型..."
        if python3 train_model.py; then
            log_success "模型训练完成"
        else
            log_warning "模型训练失败，继续执行"
        fi
    else
        log_warning "未找到 train_model.py，跳过模型训练"
    fi
}

# 显示完成信息
show_completion() {
    echo ""
    log_success "环境安装完成！"
    echo "=========================================="
    
    # 计算耗时
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    echo "总耗时: ${MINUTES}分${SECONDS}秒"
    echo ""
    
    # 显示服务状态
    log_info "服务状态检查:"
    if sudo systemctl is-active --quiet mysql; then
        log_success "MySQL: 运行中"
    else
        log_error "MySQL: 未运行"
    fi
    
    if sudo systemctl is-active --quiet redis-server; then
        log_success "Redis: 运行中"
    else
        log_error "Redis: 未运行"
    fi
    
    echo ""
    log_info "下一步操作:"
    echo "1. 启动后端服务:"
    echo "   cd backend && source venv/bin/activate && python3 app.py"
    echo ""
    echo "2. 访问地址:"
    echo "   前端: http://localhost:8080"
    echo "   后端: http://localhost:5000"
    echo ""
    echo "3. 常用命令:"
    echo "   查看 MySQL 状态: sudo systemctl status mysql"
    echo "   查看 Redis 状态: sudo systemctl status redis-server"
    echo "   重启 MySQL: sudo systemctl restart mysql"
    echo "   重启 Redis: sudo systemctl restart redis-server"
    echo ""
    echo "=========================================="
}

# 主执行流程
main() {
    log_info "开始环境安装..."
    
    check_system
    check_sudo
    install_basic_deps
    install_mysql
    install_redis
    setup_database
    setup_python
    initialize_data
    show_completion
}

# 异常处理
trap 'log_error "脚本被用户中断"; exit 1' INT
trap 'log_error "脚本执行失败"; exit 1' ERR

# 执行主函数
main "$@"