#!/bin/bash

# 检查并修复 systemd 服务文件中的路径配置

set -e

# 自动检测项目路径
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo "=========================================="
echo "🔧 检查并修复 systemd 服务路径"
echo "=========================================="
echo "项目路径: $PROJECT_DIR"
echo ""

# 检查是否存在 systemd 服务文件
SERVICE_FILE="/etc/systemd/system/canteen-backend.service"

if [ -f "$SERVICE_FILE" ]; then
    echo "ℹ️ 找到 systemd 服务文件: $SERVICE_FILE"
    echo ""
    
    # 检查当前配置
    echo "当前配置:"
    grep -E "WorkingDirectory|ExecStart" "$SERVICE_FILE" || true
    echo ""
    
    # 检查路径是否正确
    CURRENT_WD=$(grep "WorkingDirectory" "$SERVICE_FILE" | awk -F'=' '{print $2}' | tr -d ' ' || echo "")
    
    if [ "$CURRENT_WD" != "$PROJECT_DIR/backend" ]; then
        echo "⚠️ 工作目录不匹配"
        echo "  当前: $CURRENT_WD"
        echo "  应该: $PROJECT_DIR/backend"
        echo ""
        read -p "是否更新服务文件? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # 备份原文件
            sudo cp "$SERVICE_FILE" "${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
            
            # 更新 WorkingDirectory
            sudo sed -i "s|WorkingDirectory=.*|WorkingDirectory=$PROJECT_DIR/backend|g" "$SERVICE_FILE"
            
            # 更新 ExecStart（如果包含路径）
            if grep -q "ExecStart.*app.py" "$SERVICE_FILE"; then
                # 检查是否有虚拟环境
                if [ -d "$PROJECT_DIR/backend/venv" ]; then
                    sudo sed -i "s|ExecStart=.*|ExecStart=$PROJECT_DIR/backend/venv/bin/python3 $PROJECT_DIR/backend/app.py|g" "$SERVICE_FILE"
                else
                    sudo sed -i "s|ExecStart=.*|ExecStart=/usr/bin/python3 $PROJECT_DIR/backend/app.py|g" "$SERVICE_FILE"
                fi
            fi
            
            echo "✅ 服务文件已更新"
            echo ""
            echo "新配置:"
            grep -E "WorkingDirectory|ExecStart" "$SERVICE_FILE" || true
            echo ""
            
            # 重新加载 systemd
            sudo systemctl daemon-reload
            echo "✅ systemd 配置已重新加载"
            
            # 重启服务
            if systemctl is-active --quiet canteen-backend; then
                echo "重启服务..."
                sudo systemctl restart canteen-backend
                sleep 2
                if systemctl is-active --quiet canteen-backend; then
                    echo "✅ 服务已重启"
                else
                    echo "⚠️ 服务重启失败，请检查日志"
                    sudo journalctl -u canteen-backend -n 20 --no-pager
                fi
            fi
        fi
    else
        echo "✅ 工作目录配置正确"
    fi
else
    echo "ℹ️ 未找到 systemd 服务文件"
    echo "如果使用 systemd 服务，请确保服务文件中的路径正确"
fi

echo ""
echo "=========================================="
echo "✅ 检查完成"
echo "=========================================="
echo ""

