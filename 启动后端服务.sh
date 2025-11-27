#!/bin/bash

# 启动后端服务（systemd）
# 如果服务不存在，会自动创建

set -e

# 自动检测项目路径
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo "=========================================="
echo "🔧 启动后端服务"
echo "=========================================="
echo "项目路径: $PROJECT_DIR"
echo ""

# 检查服务文件是否存在
SERVICE_FILE="/etc/systemd/system/canteen-backend.service"

if [ ! -f "$SERVICE_FILE" ]; then
    echo "ℹ️ 服务文件不存在，正在创建..."
    
    # 检查虚拟环境
    VENV_PATH=""
    if [ -d "$PROJECT_DIR/backend/venv" ]; then
        VENV_PATH="$PROJECT_DIR/backend/venv/bin/python3"
        echo "✅ 找到虚拟环境: $VENV_PATH"
    else
        VENV_PATH="/usr/bin/python3"
        echo "⚠️ 未找到虚拟环境，使用系统 Python: $VENV_PATH"
    fi
    
    # 创建服务文件
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Canteen Recommendation System Backend
After=network.target mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR/backend
Environment="PATH=$PROJECT_DIR/backend/venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="MYSQL_HOST=localhost"
Environment="MYSQL_PORT=3306"
Environment="MYSQL_USER=root"
Environment="MYSQL_PASSWORD=password"
Environment="MYSQL_DATABASE=canteen_recommendation"
ExecStart=$VENV_PATH $PROJECT_DIR/backend/app.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    echo "✅ 服务文件已创建"
    
    # 重新加载 systemd
    sudo systemctl daemon-reload
    echo "✅ systemd 配置已重新加载"
else
    echo "✅ 服务文件已存在"
    
    # 检查路径是否正确
    CURRENT_WD=$(grep "WorkingDirectory" "$SERVICE_FILE" | awk -F'=' '{print $2}' | tr -d ' ' || echo "")
    if [ "$CURRENT_WD" != "$PROJECT_DIR/backend" ]; then
        echo "⚠️ 工作目录不匹配，正在更新..."
        sudo sed -i "s|WorkingDirectory=.*|WorkingDirectory=$PROJECT_DIR/backend|g" "$SERVICE_FILE"
        
        # 更新 ExecStart
        if [ -d "$PROJECT_DIR/backend/venv" ]; then
            sudo sed -i "s|ExecStart=.*|ExecStart=$PROJECT_DIR/backend/venv/bin/python3 $PROJECT_DIR/backend/app.py|g" "$SERVICE_FILE"
        else
            sudo sed -i "s|ExecStart=.*|ExecStart=/usr/bin/python3 $PROJECT_DIR/backend/app.py|g" "$SERVICE_FILE"
        fi
        
        sudo systemctl daemon-reload
        echo "✅ 服务文件已更新"
    fi
fi

# 检查 MySQL 是否运行
echo ""
echo "ℹ️ 检查 MySQL 服务..."
if systemctl is-active --quiet mysql || systemctl is-active --quiet mysqld; then
    echo "✅ MySQL 服务运行中"
else
    echo "⚠️ MySQL 服务未运行，正在启动..."
    sudo systemctl start mysql 2>/dev/null || sudo systemctl start mysqld 2>/dev/null || {
        echo "❌ MySQL 启动失败，请手动启动"
    }
    sleep 3
fi

# 检查后端目录和文件
echo ""
echo "ℹ️ 检查后端文件..."
if [ ! -f "$PROJECT_DIR/backend/app.py" ]; then
    echo "❌ 后端文件不存在: $PROJECT_DIR/backend/app.py"
    exit 1
fi

if [ ! -d "$PROJECT_DIR/backend/venv" ]; then
    echo "⚠️ 虚拟环境不存在，建议先创建虚拟环境"
    echo "运行: cd $PROJECT_DIR/backend && python3 -m venv venv"
fi

# 启动服务
echo ""
echo "ℹ️ 启动后端服务..."
sudo systemctl start canteen-backend

# 等待服务启动
sleep 3

# 检查服务状态
if systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务已启动"
    echo ""
    echo "服务状态:"
    sudo systemctl status canteen-backend --no-pager -l | head -15
else
    echo "❌ 后端服务启动失败"
    echo ""
    echo "查看错误日志:"
    sudo journalctl -u canteen-backend -n 30 --no-pager
    echo ""
    echo "请检查："
    echo "1. Python 环境是否正确"
    echo "2. 依赖是否已安装"
    echo "3. MySQL 是否正常运行"
    echo "4. 端口 5000 是否被占用"
    exit 1
fi

# 测试服务
echo ""
echo "ℹ️ 测试服务..."
sleep 2
if curl -s http://localhost:5000/health >/dev/null 2>&1; then
    RESPONSE=$(curl -s http://localhost:5000/health)
    echo "✅ 服务健康检查通过: $RESPONSE"
else
    echo "⚠️ 服务健康检查失败，但服务可能正在启动中"
    echo "请稍等片刻后再次检查: curl http://localhost:5000/health"
fi

echo ""
echo "=========================================="
echo "✅ 完成"
echo "=========================================="
echo ""
echo "常用命令:"
echo "  查看状态: sudo systemctl status canteen-backend"
echo "  查看日志: sudo journalctl -u canteen-backend -f"
echo "  重启服务: sudo systemctl restart canteen-backend"
echo "  停止服务: sudo systemctl stop canteen-backend"
echo ""

