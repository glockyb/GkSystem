#!/bin/bash

# 修复后端启动错误

set -e

echo "=========================================="
echo "🔧 修复后端启动错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查 admin.py 文件是否存在
echo ""
echo "ℹ️ 步骤1: 检查 admin.py 文件..."
if [ -f "backend/api/admin.py" ]; then
    echo "✅ admin.py 文件存在"
else
    echo "❌ admin.py 文件不存在！"
    exit 1
fi

# 2. 检查 Python 语法
echo ""
echo "ℹ️ 步骤2: 检查 Python 语法..."
cd backend
if [ -d "venv" ]; then
    source venv/bin/activate
    echo "✅ 已激活虚拟环境"
fi

python3 -m py_compile api/admin.py 2>&1
if [ $? -eq 0 ]; then
    echo "✅ admin.py 语法正确"
else
    echo "❌ admin.py 语法有错误"
    exit 1
fi

python3 -m py_compile app.py 2>&1
if [ $? -eq 0 ]; then
    echo "✅ app.py 语法正确"
else
    echo "❌ app.py 语法有错误"
    exit 1
fi

cd ..

# 3. 重启后端服务
echo ""
echo "ℹ️ 步骤3: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 3

# 4. 检查服务状态
echo ""
echo "ℹ️ 步骤4: 检查服务状态..."
if systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行正常"
    
    # 测试健康检查
    sleep 1
    if curl -s http://localhost:5000/health | grep -q "healthy"; then
        echo "✅ 健康检查通过"
    else
        echo "⚠️ 健康检查失败"
    fi
else
    echo "❌ 后端服务启动失败，查看日志:"
    sudo journalctl -u canteen-backend -n 30 --no-pager
    exit 1
fi

# 5. 显示最近日志
echo ""
echo "ℹ️ 步骤5: 显示最近日志（最后 10 行）..."
sudo journalctl -u canteen-backend -n 10 --no-pager

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "如果仍有问题，请查看完整日志:"
echo "  sudo journalctl -u canteen-backend -f"
echo ""

