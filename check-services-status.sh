#!/bin/bash

# 检查服务状态和自动启动配置

echo "=========================================="
echo "🔍 检查服务状态"
echo "=========================================="

# 1. 检查后端服务
echo ""
echo "ℹ️ 步骤1: 检查后端服务..."
if systemctl list-unit-files | grep -q "canteen-backend.service"; then
    echo "✅ canteen-backend.service 已配置"
    
    # 检查服务状态
    if sudo systemctl is-active --quiet canteen-backend; then
        echo "✅ 后端服务正在运行"
    else
        echo "⚠️ 后端服务未运行"
        echo "状态："
        sudo systemctl status canteen-backend --no-pager -l | head -10
    fi
    
    # 检查是否启用自动启动
    if sudo systemctl is-enabled --quiet canteen-backend; then
        echo "✅ 后端服务已启用自动启动（开机自启）"
    else
        echo "⚠️ 后端服务未启用自动启动"
        echo "启用命令: sudo systemctl enable canteen-backend"
    fi
else
    echo "❌ canteen-backend.service 未配置"
fi

# 2. 检查 Nginx 服务
echo ""
echo "ℹ️ 步骤2: 检查 Nginx 服务..."
if sudo systemctl is-active --quiet nginx; then
    echo "✅ Nginx 正在运行"
else
    echo "⚠️ Nginx 未运行"
    echo "状态："
    sudo systemctl status nginx --no-pager -l | head -10
fi

if sudo systemctl is-enabled --quiet nginx; then
    echo "✅ Nginx 已启用自动启动（开机自启）"
else
    echo "⚠️ Nginx 未启用自动启动"
    echo "启用命令: sudo systemctl enable nginx"
fi

# 3. 检查 MySQL 服务
echo ""
echo "ℹ️ 步骤3: 检查 MySQL 服务..."
if sudo systemctl is-active --quiet mysql || sudo systemctl is-active --quiet mysqld; then
    echo "✅ MySQL 正在运行"
else
    echo "⚠️ MySQL 未运行"
fi

# 4. 检查 Redis 服务
echo ""
echo "ℹ️ 步骤4: 检查 Redis 服务..."
if sudo systemctl is-active --quiet redis || sudo systemctl is-active --quiet redis-server; then
    echo "✅ Redis 正在运行"
else
    echo "⚠️ Redis 未运行（不影响主要功能）"
fi

# 5. 显示所有相关服务状态
echo ""
echo "ℹ️ 步骤5: 所有相关服务状态摘要..."
echo "服务名称                   状态      自动启动"
echo "--------------------------------------------"
for service in canteen-backend nginx mysql mysqld redis redis-server; do
    if systemctl list-unit-files | grep -q "$service.service"; then
        status=$(sudo systemctl is-active $service 2>/dev/null || echo "inactive")
        enabled=$(sudo systemctl is-enabled $service 2>/dev/null || echo "disabled")
        printf "%-25s %-10s %s\n" "$service" "$status" "$enabled"
    fi
done

echo ""
echo "=========================================="
echo "✅ 检查完成"
echo "=========================================="
echo ""
echo "📋 服务管理命令："
echo ""
echo "启动服务："
echo "  sudo systemctl start canteen-backend"
echo "  sudo systemctl start nginx"
echo ""
echo "停止服务："
echo "  sudo systemctl stop canteen-backend"
echo "  sudo systemctl stop nginx"
echo ""
echo "重启服务："
echo "  sudo systemctl restart canteen-backend"
echo "  sudo systemctl restart nginx"
echo ""
echo "查看服务状态："
echo "  sudo systemctl status canteen-backend"
echo "  sudo systemctl status nginx"
echo ""
echo "启用自动启动（开机自启）："
echo "  sudo systemctl enable canteen-backend"
echo "  sudo systemctl enable nginx"
echo ""
echo "禁用自动启动："
echo "  sudo systemctl disable canteen-backend"
echo "  sudo systemctl disable nginx"
echo ""
echo "查看服务日志："
echo "  sudo journalctl -u canteen-backend -f"
echo "  sudo tail -f /var/log/nginx/error.log"
echo ""

