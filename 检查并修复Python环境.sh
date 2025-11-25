#!/bin/bash

# 检查并修复 Python 环境

set -e

echo "=========================================="
echo "🔧 检查并修复 Python 环境"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查虚拟环境
echo ""
echo "ℹ️ 步骤1: 检查虚拟环境..."
if [ -d "venv" ]; then
    echo "✅ 虚拟环境存在: venv/"
    VENV_PATH="venv"
elif [ -d "backend/venv" ]; then
    echo "✅ 虚拟环境存在: backend/venv/"
    VENV_PATH="backend/venv"
else
    echo "❌ 未找到虚拟环境，创建新的虚拟环境..."
    python3 -m venv venv
    VENV_PATH="venv"
    echo "✅ 虚拟环境已创建"
fi

# 2. 检查 Python 版本
echo ""
echo "ℹ️ 步骤2: 检查 Python 版本..."
VENV_PYTHON="$VENV_PATH/bin/python3"
if [ -f "$VENV_PYTHON" ]; then
    PYTHON_VERSION=$($VENV_PYTHON --version)
    echo "✅ Python 版本: $PYTHON_VERSION"
else
    echo "❌ 虚拟环境 Python 不存在"
    exit 1
fi

# 3. 检查 pip
echo ""
echo "ℹ️ 步骤3: 检查 pip..."
VENV_PIP="$VENV_PATH/bin/pip3"
if [ -f "$VENV_PIP" ]; then
    PIP_VERSION=$($VENV_PIP --version)
    echo "✅ pip 版本: $PIP_VERSION"
else
    echo "❌ pip 不存在"
    exit 1
fi

# 4. 检查关键模块
echo ""
echo "ℹ️ 步骤4: 检查关键模块..."
MISSING_MODULES=()

if ! $VENV_PYTHON -c "import pymysql" 2>/dev/null; then
    MISSING_MODULES+=("pymysql")
fi

if ! $VENV_PYTHON -c "import flask" 2>/dev/null; then
    MISSING_MODULES+=("flask")
fi

if ! $VENV_PYTHON -c "import pandas" 2>/dev/null; then
    MISSING_MODULES+=("pandas")
fi

if [ ${#MISSING_MODULES[@]} -eq 0 ]; then
    echo "✅ 所有关键模块已安装"
else
    echo "⚠️ 缺少以下模块: ${MISSING_MODULES[*]}"
fi

# 5. 安装依赖
echo ""
echo "ℹ️ 步骤5: 安装/更新依赖..."
if [ -f "backend/requirements.txt" ]; then
    echo "从 backend/requirements.txt 安装依赖..."
    $VENV_PIP install -q -r backend/requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
    echo "✅ 依赖安装完成"
elif [ -f "requirements.txt" ]; then
    echo "从 requirements.txt 安装依赖..."
    $VENV_PIP install -q -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
    echo "✅ 依赖安装完成"
else
    echo "⚠️ 未找到 requirements.txt，手动安装关键模块..."
    $VENV_PIP install -q pymysql flask flask-cors flask-jwt-extended pandas numpy scikit-learn -i https://pypi.tuna.tsinghua.edu.cn/simple
    echo "✅ 关键模块安装完成"
fi

# 6. 验证安装
echo ""
echo "ℹ️ 步骤6: 验证安装..."
ALL_OK=true

for module in pymysql flask flask_cors flask_jwt_extended pandas numpy sklearn; do
    if $VENV_PYTHON -c "import $module" 2>/dev/null; then
        echo "✅ $module"
    else
        echo "❌ $module"
        ALL_OK=false
    fi
done

# 7. 检查后端服务配置
echo ""
echo "ℹ️ 步骤7: 检查后端服务配置..."
if [ -f "/etc/systemd/system/canteen-backend.service" ]; then
    echo "✅ 后端服务配置文件存在"
    
    # 检查服务是否使用虚拟环境
    if grep -q "venv/bin/python" /etc/systemd/system/canteen-backend.service; then
        echo "✅ 服务配置使用虚拟环境"
    else
        echo "⚠️ 服务配置可能未使用虚拟环境"
        echo "   检查服务文件:"
        grep -E "ExecStart|WorkingDirectory" /etc/systemd/system/canteen-backend.service | head -2
    fi
else
    echo "⚠️ 后端服务配置文件不存在"
fi

# 8. 测试数据库连接
echo ""
echo "ℹ️ 步骤8: 测试数据库连接..."
cd backend
if $VENV_PYTHON -c "
import sys
import os
sys.path.insert(0, '.')
from utils.database import db
try:
    conn = db.get_connection()
    if conn:
        cursor = conn.cursor()
        cursor.execute('SELECT 1')
        result = cursor.fetchone()
        cursor.close()
        print('✅ 数据库连接成功')
    else:
        print('❌ 无法获取数据库连接')
except Exception as e:
    print(f'❌ 数据库连接失败: {e}')
" 2>&1; then
    echo "✅ 数据库连接测试通过"
else
    echo "❌ 数据库连接测试失败"
    ALL_OK=false
fi
cd ..

# 9. 总结
echo ""
echo "=========================================="
echo "📋 检查结果"
echo "=========================================="
if [ "$ALL_OK" = true ]; then
    echo "✅ Python 环境配置正常"
    echo ""
    echo "虚拟环境路径: $VENV_PATH"
    echo "Python 路径: $VENV_PYTHON"
    echo ""
    echo "如果后端服务仍有问题，请重启服务:"
    echo "  sudo systemctl restart canteen-backend"
else
    echo "❌ 仍有问题需要解决"
    echo ""
    echo "请检查上述错误信息，或手动安装依赖:"
    echo "  source $VENV_PATH/bin/activate"
    echo "  pip install -r backend/requirements.txt"
fi
echo ""

