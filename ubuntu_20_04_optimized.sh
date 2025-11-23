#!/bin/bash
# ubuntu_20_04_optimized.sh - Ubuntu 20.04 优化安装

echo "=== Ubuntu 20.04 优化安装 ==="

# 更新系统并安装必要的包
sudo apt update
sudo apt upgrade -y
sudo apt install -y \
    build-essential \
    python3-dev \
    python3-pip \
    python3-venv \
    libssl-dev \
    libffi-dev \
    libmysqlclient-dev \
    pkg-config \
    gcc \
    g++ \
    make

# 检查系统信息
echo "系统信息:"
python3 --version
pip3 --version

echo "=== 系统优化完成 ==="