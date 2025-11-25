#!/bin/bash
# 快速修复 scikit-surprise（简化版）

cd ~/gksys/GkSystem/backend
source ../venv/bin/activate

echo "步骤1: 卸载 Cython 3.x..."
pip uninstall -y Cython

echo "步骤2: 安装兼容的 Cython 0.29.36..."
pip install Cython==0.29.36 -i https://pypi.tuna.tsinghua.edu.cn/simple

echo "步骤3: 安装 scikit-surprise..."
pip install scikit-surprise -i https://pypi.tuna.tsinghua.edu.cn/simple --no-cache-dir

echo "步骤4: 验证..."
python -c "import surprise; print('✅ 成功！版本:', surprise.__version__)"

echo ""
echo "完成！"

