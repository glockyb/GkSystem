#!/bin/bash
# conservative_install.sh - 保守版本安装

echo "=== 保守版本安装 ==="

cd /root/gksys/backend

# 清理并重建
rm -rf venv
python3 -m venv venv
source venv/bin/activate

# 升级pip
pip3 install --upgrade pip

echo "安装经过验证的稳定版本..."

# 使用经过验证的稳定版本
STABLE_PACKAGES=(
    "numpy==1.19.5"
    "pandas==1.1.5"
    "flask==1.1.4"
    "sqlalchemy==1.3.24"
    "pymysql==0.10.1"
    "redis==3.5.3"
    "scikit-learn==0.24.2"
)

for package in "${STABLE_PACKAGES[@]}"; do
    echo "安装: $package"
    pip3 install "$package"
    if [ $? -eq 0 ]; then
        echo "✓ 成功"
    else
        echo "✗ 失败"
    fi
done

echo "验证安装..."
python3 -c "
try:
    import numpy; print('✓ numpy')
except: print('✗ numpy')
try:
    import pandas; print('✓ pandas')
except: print('✗ pandas') 
try:
    import flask; print('✓ flask')
except: print('✗ flask')
try:
    import sqlalchemy; print('✓ sqlalchemy')
except: print('✗ sqlalchemy')
try:
    import pymysql; print('✓ pymysql')
except: print('✗ pymysql')
try:
    import redis; print('✓ redis')
except: print('✗ redis')
try:
    import sklearn; print('✓ scikit-learn')
except: print('✗ scikit-learn')
"

echo "=== 保守安装完成 ==="