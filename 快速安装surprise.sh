#!/bin/bash
# 快速安装 scikit-surprise（简化版）

set -e

echo "=========================================="
echo "快速安装 scikit-surprise"
echo "=========================================="
echo ""

# 安装编译依赖
echo "步骤1: 安装编译依赖..."
sudo apt-get update
sudo apt-get install -y python3-dev python3.9-dev build-essential gcc g++

# 进入虚拟环境
cd ~/gksys/GkSystem/backend
source ../venv/bin/activate

# 升级工具
echo "步骤2: 升级 pip 和工具..."
pip install --upgrade pip setuptools wheel

# 安装 Cython
echo "步骤3: 安装 Cython..."
pip install Cython -i https://pypi.tuna.tsinghua.edu.cn/simple

# 安装 numpy（如果还没有）
echo "步骤4: 检查 numpy..."
pip install numpy==1.24.3 -i https://pypi.tuna.tsinghua.edu.cn/simple || true

# 安装 scikit-surprise
echo "步骤5: 安装 scikit-surprise（可能需要几分钟）..."
pip install scikit-surprise -i https://pypi.tuna.tsinghua.edu.cn/simple --no-cache-dir

# 验证
echo "步骤6: 验证安装..."
python -c "import surprise; print('✅ 安装成功！版本:', surprise.__version__)"

echo ""
echo "=========================================="
echo "安装完成！"
echo "=========================================="

