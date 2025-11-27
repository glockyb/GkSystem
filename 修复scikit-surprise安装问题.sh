#!/bin/bash

# 修复 scikit-surprise 安装问题
# 问题：Cython 编译错误，通常是由于版本不兼容或缺少编译依赖

set -e

# 自动检测项目路径
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo "=========================================="
echo "🔧 修复 scikit-surprise 安装问题"
echo "=========================================="
echo "项目路径: $SCRIPT_DIR"
echo ""

# 1. 安装编译依赖
echo "ℹ️ 步骤1: 安装编译依赖..."
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    python3-dev \
    gcc \
    g++ \
    libblas-dev \
    liblapack-dev \
    libatlas-base-dev \
    gfortran \
    pkg-config \
    || { echo "⚠️ 部分依赖安装失败，继续尝试..." ; }
echo "✅ 编译依赖安装完成"
echo ""

# 2. 进入后端目录
cd "$SCRIPT_DIR/backend" || exit 1

# 3. 检查虚拟环境
echo "ℹ️ 步骤2: 检查虚拟环境..."
if [ ! -d "venv" ]; then
    echo "创建虚拟环境..."
    python3 -m venv venv
    echo "✅ 虚拟环境已创建"
else
    echo "✅ 虚拟环境已存在"
fi

# 激活虚拟环境
source venv/bin/activate
echo "✅ 虚拟环境已激活"
echo ""

# 4. 升级 pip 和基础工具
echo "ℹ️ 步骤3: 升级 pip 和基础工具..."
pip install --upgrade pip setuptools wheel
echo "✅ pip 和基础工具已升级"
echo ""

# 5. 安装兼容版本的 Cython 和 NumPy
echo "ℹ️ 步骤4: 安装兼容版本的 Cython 和 NumPy..."
# Cython 0.29.x 与 scikit-surprise 兼容性较好
pip install "Cython<3.0" "numpy==1.24.3"
echo "✅ Cython 和 NumPy 已安装"
echo ""

# 6. 尝试安装 scikit-surprise（使用特定版本）
echo "ℹ️ 步骤5: 安装 scikit-surprise..."
# 方法1: 尝试安装 1.1.3 版本（较稳定）
echo "尝试安装 scikit-surprise==1.1.3..."
if pip install "scikit-surprise==1.1.3" --no-cache-dir; then
    echo "✅ scikit-surprise 1.1.3 安装成功"
else
    echo "⚠️ scikit-surprise 1.1.3 安装失败，尝试其他方法..."
    
    # 方法2: 尝试从源码安装（使用 --no-build-isolation）
    echo "尝试从源码安装 scikit-surprise（无构建隔离）..."
    if pip install scikit-surprise --no-build-isolation --no-cache-dir; then
        echo "✅ scikit-surprise 从源码安装成功"
    else
        echo "⚠️ 从源码安装也失败，尝试使用预编译 wheel..."
        
        # 方法3: 尝试安装最新版本（可能有预编译 wheel）
        echo "尝试安装最新版本的 scikit-surprise..."
        if pip install scikit-surprise --no-cache-dir; then
            echo "✅ scikit-surprise 最新版本安装成功"
        else
            echo "❌ 所有安装方法都失败"
            echo ""
            echo "请尝试以下手动步骤："
            echo "1. 检查 Python 版本: python3 --version (需要 3.8+)"
            echo "2. 检查编译工具: gcc --version"
            echo "3. 手动安装: pip install scikit-surprise==1.1.3 --no-cache-dir"
            exit 1
        fi
    fi
fi
echo ""

# 7. 验证安装
echo "ℹ️ 步骤6: 验证 scikit-surprise 安装..."
python3 -c "import surprise; print(f'✅ scikit-surprise 版本: {surprise.__version__}')" || {
    echo "❌ scikit-surprise 导入失败"
    exit 1
}
echo ""

# 8. 安装其他依赖
echo "ℹ️ 步骤7: 安装其他依赖..."
cd "$SCRIPT_DIR/backend" || exit 1
if [ -f "requirements.txt" ]; then
    # 跳过 scikit-surprise，因为已经安装
    pip install -r requirements.txt --no-cache-dir || {
        echo "⚠️ 部分依赖安装失败，但继续..."
    }
    echo "✅ 其他依赖安装完成"
else
    echo "⚠️ requirements.txt 不存在，跳过"
fi
echo ""

echo "=========================================="
echo "✅ scikit-surprise 安装问题修复完成"
echo "=========================================="
echo ""
echo "现在可以尝试启动后端服务："
echo "  cd $SCRIPT_DIR/backend"
echo "  source venv/bin/activate"
echo "  python3 app.py"
echo ""

