#!/usr/bin/env python
"""
模型训练脚本
用于训练推荐算法模型
"""
import sys
import os

# 添加项目路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from data.preprocessor import DataPreprocessor
from models.recommender import recommender

if __name__ == '__main__':
    print("=" * 50)
    print("开始数据预处理...")
    print("=" * 50)
    
    # 数据预处理
    preprocessor = DataPreprocessor()
    preprocessor.process_all()
    
    print("\n" + "=" * 50)
    print("开始训练推荐模型...")
    print("=" * 50)
    
    # 训练模型
    recommender.train()
    
    print("\n" + "=" * 50)
    print("模型训练完成！")
    print("=" * 50)
