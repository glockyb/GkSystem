#!/bin/bash
# 服务管理脚本

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

if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

show_menu() {
    echo "=========================================="
    echo "服务管理菜单"
    echo "=========================================="
    echo ""
    echo "1. 查看所有服务状态"
    echo "2. 启动所有服务"
    echo "3. 停止所有服务"
    echo "4. 重启所有服务"
    echo "5. 查看后端日志"
    echo "6. 查看 Nginx 日志"
    echo "7. 重启后端服务"
    echo "8. 重启 Nginx"
    echo "9. 测试服务"
    echo "0. 退出"
    echo ""
}

check_status() {
    echo "=========================================="
    log_info "服务状态"
    echo "=========================================="
    echo ""
    
    SERVICES=("canteen-backend" "nginx" "mysql" "redis-server")
    ALL_OK=true
    
    for service in "${SERVICES[@]}"; do
        if $SUDO systemctl is-active "$service" >/dev/null 2>&1; then
            log_success "$service: 运行中"
        else
            log_error "$service: 未运行"
            ALL_OK=false
        fi
    done
    
    echo ""
    echo "端口监听："
    netstat -tuln 2>/dev/null | grep -E ':80|:5000|:3306|:6379' || \
    ss -tuln 2>/dev/null | grep -E ':80|:5000|:3306|:6379' || \
    log_warning "无法检查端口"
    
    echo ""
    if [ "$ALL_OK" = true ]; then
        log_success "所有服务运行正常"
    else
        log_warning "有服务未运行"
    fi
    echo ""
}

start_all() {
    log_info "启动所有服务..."
    $SUDO systemctl start mysql
    $SUDO systemctl start redis-server
    $SUDO systemctl start canteen-backend
    $SUDO systemctl start nginx
    sleep 2
    check_status
}

stop_all() {
    log_warning "停止所有服务..."
    read -p "确认停止所有服务? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        $SUDO systemctl stop canteen-backend
        $SUDO systemctl stop nginx
        log_success "服务已停止（MySQL 和 Redis 未停止）"
    fi
}

restart_all() {
    log_info "重启所有服务..."
    $SUDO systemctl restart mysql
    $SUDO systemctl restart redis-server
    $SUDO systemctl restart canteen-backend
    $SUDO systemctl restart nginx
    sleep 2
    check_status
}

view_backend_logs() {
    log_info "查看后端日志（按 Ctrl+C 退出）..."
    $SUDO journalctl -u canteen-backend -f
}

view_nginx_logs() {
    log_info "查看 Nginx 错误日志（按 Ctrl+C 退出）..."
    $SUDO tail -f /var/log/nginx/error.log
}

restart_backend() {
    log_info "重启后端服务..."
    $SUDO systemctl restart canteen-backend
    sleep 2
    if $SUDO systemctl is-active canteen-backend >/dev/null 2>&1; then
        log_success "后端服务已重启"
    else
        log_error "后端服务启动失败"
        $SUDO journalctl -u canteen-backend -n 20 --no-pager
    fi
}

restart_nginx() {
    log_info "重启 Nginx..."
    $SUDO systemctl restart nginx
    sleep 1
    if $SUDO systemctl is-active nginx >/dev/null 2>&1; then
        log_success "Nginx 已重启"
    else
        log_error "Nginx 启动失败"
        $SUDO systemctl status nginx --no-pager -l | head -20
    fi
}

test_services() {
    log_info "测试服务..."
    echo ""
    
    # 测试后端
    log_info "测试后端 API..."
    if curl -s http://localhost:5000/health >/dev/null 2>&1; then
        RESPONSE=$(curl -s http://localhost:5000/health)
        log_success "后端 API 正常: $RESPONSE"
    else
        log_error "后端 API 不可访问"
    fi
    
    echo ""
    
    # 测试前端
    log_info "测试前端..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        log_success "前端访问正常 (HTTP $HTTP_CODE)"
    else
        log_warning "前端返回 HTTP $HTTP_CODE"
    fi
    
    echo ""
}

# 主循环
while true; do
    show_menu
    read -p "请选择操作 [0-9]: " choice
    echo ""
    
    case $choice in
        1)
            check_status
            ;;
        2)
            start_all
            ;;
        3)
            stop_all
            ;;
        4)
            restart_all
            ;;
        5)
            view_backend_logs
            ;;
        6)
            view_nginx_logs
            ;;
        7)
            restart_backend
            ;;
        8)
            restart_nginx
            ;;
        9)
            test_services
            ;;
        0)
            log_info "退出"
            exit 0
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
    
    echo ""
    read -p "按 Enter 继续..."
    clear
done

