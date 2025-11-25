#!/bin/bash
# 安装旧版本的 scikit-surprise

cd ~/gksys/GkSystem/backend
source ../venv/bin/activate

echo "卸载当前版本..."
pip uninstall -y scikit-surprise Cython 2>/dev/null || true

echo "安装 Cython 0.29.33..."
pip install Cython==0.29.33 -i https://pypi.tuna.tsinghua.edu.cn/simple

echo "安装 scikit-surprise 1.1.1..."
pip install scikit-surprise==1.1.1 -i https://pypi.tuna.tsinghua.edu.cn/simple --no-cache-dir

echo "验证..."
python -c "import surprise; print('✅ 成功！版本:', surprise.__version__)"

