#!/bin/bash

echo "启动校园食堂菜品推荐系统后端服务..."

# 检查Python环境
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到Python3，请先安装Python 3.8+"
    exit 1
fi

# 检查依赖
if [ ! -d "venv" ]; then
    echo "创建虚拟环境..."
    python3 -m venv venv
fi

echo "激活虚拟环境..."
source venv/bin/activate

echo "安装依赖..."
pip install -r requirements.txt

# 检查数据库连接
echo "检查数据库连接..."
python3 -c "from utils.database import db; db.get_connection(); print('数据库连接成功')" || {
    echo "错误: 数据库连接失败，请检查配置"
    exit 1
}

# 检查Redis连接
echo "检查Redis连接..."
python3 -c "from utils.database import db; db.get_redis().ping(); print('Redis连接成功')" || {
    echo "警告: Redis连接失败，推荐功能可能受影响"
}

# 检查模型文件
if [ ! -f "models/cf_model.pkl" ] || [ ! -f "models/cb_model.pkl" ]; then
    echo "模型文件不存在，开始训练模型..."
    python3 train_model.py
fi

echo "启动Flask服务..."
python3 app.py
