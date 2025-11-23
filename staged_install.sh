#!/bin/bash
# staged_install.sh - 分阶段安装

echo "=== 分阶段安装 ==="

cd /root/gksys/backend

# 阶段1: 基础环境
echo "阶段1: 基础环境设置"
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip3 install --upgrade pip setuptools wheel

# 阶段2: 核心依赖
echo "阶段2: 安装核心依赖"
pip3 install flask==2.0.3
pip3 install pymysql==1.0.3
pip3 install redis==4.5.4

# 阶段3: 数据库相关
echo "阶段3: 数据库相关"
pip3 install sqlalchemy==1.4.46

# 阶段4: 数据处理（可选）
echo "阶段4: 数据处理包"
pip3 install numpy==1.21.6
pip3 install pandas==1.3.5
pip3 install scikit-learn==1.0.2

# 验证
echo "安装验证:"
python3 -c "
import flask, pymysql, sqlalchemy, redis
print('✓ 核心依赖安装成功')
try:
    import numpy, pandas, sklearn
    print('✓ 数据处理包安装成功')
except:
    print('⚠ 部分数据处理包未安装')
"

echo "=== 分阶段安装完成 ==="