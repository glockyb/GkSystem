#!/usr/bin/env python3
"""
添加更多假数据到数据库
"""
import sys
import os
import random
from datetime import datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from backend.config import Config
from backend.utils.database import db
import pymysql

# 扩展的菜品数据
EXTENDED_DISHES = [
    # 荤菜
    ('红烧肉', '荤菜', 12.00, '经典红烧肉，肥而不腻，入口即化', '/images/hongshaorou.jpg'),
    ('宫保鸡丁', '荤菜', 15.00, '经典川菜宫保鸡丁，麻辣鲜香', '/images/gongbaojiding.jpg'),
    ('糖醋里脊', '荤菜', 14.00, '酸甜可口的糖醋里脊，外酥内嫩', '/images/tangculiji.jpg'),
    ('鱼香肉丝', '荤菜', 13.00, '川菜鱼香肉丝，鱼香味浓郁', '/images/yuxiangrousi.jpg'),
    ('回锅肉', '荤菜', 16.00, '四川回锅肉，肥瘦相间，香辣下饭', '/images/huiguorou.jpg'),
    ('水煮鱼', '荤菜', 28.00, '川菜水煮鱼，麻辣鲜香，鱼肉鲜嫩', '/images/shuizhuyu.jpg'),
    ('麻婆豆腐', '荤菜', 8.00, '川味麻婆豆腐，麻辣鲜香', '/images/mapodoufu.jpg'),
    ('口水鸡', '荤菜', 18.00, '四川口水鸡，麻辣鲜香，肉质鲜嫩', '/images/koushuiji.jpg'),
    ('辣子鸡', '荤菜', 22.00, '重庆辣子鸡，麻辣鲜香，外酥内嫩', '/images/laziji.jpg'),
    ('红烧排骨', '荤菜', 20.00, '经典红烧排骨，色泽红亮，肉质鲜嫩', '/images/hongshaopaigu.jpg'),
    ('可乐鸡翅', '荤菜', 16.00, '香甜可口的可乐鸡翅，老少皆宜', '/images/kelejichi.jpg'),
    ('蒜蓉粉丝蒸扇贝', '荤菜', 35.00, '海鲜蒜蓉粉丝蒸扇贝，鲜香美味', '/images/suanrongfensizhengshanbei.jpg'),
    ('白切鸡', '荤菜', 18.00, '广东白切鸡，肉质鲜嫩，原汁原味', '/images/baiqieji.jpg'),
    ('糖醋排骨', '荤菜', 19.00, '酸甜可口的糖醋排骨，外酥内嫩', '/images/tangcupaigu.jpg'),
    ('红烧狮子头', '荤菜', 24.00, '经典红烧狮子头，肉质鲜嫩，汤汁浓郁', '/images/hongshaoshizitou.jpg'),
    
    # 素菜
    ('麻婆豆腐', '素菜', 8.00, '川味麻婆豆腐，麻辣鲜香', '/images/mapodoufu.jpg'),
    ('西红柿鸡蛋', '素菜', 10.00, '家常西红柿炒鸡蛋，营养丰富', '/images/xihongshijidan.jpg'),
    ('地三鲜', '素菜', 9.00, '东北名菜地三鲜，土豆茄子青椒', '/images/disanxian.jpg'),
    ('青椒土豆丝', '素菜', 7.00, '清爽青椒土豆丝，清脆爽口', '/images/qingjiaotudousi.jpg'),
    ('酸辣土豆丝', '素菜', 8.00, '开胃酸辣土豆丝，酸辣爽口', '/images/suanlatudousi.jpg'),
    ('干煸豆角', '素菜', 12.00, '川菜干煸豆角，麻辣鲜香', '/images/ganbiandoujiao.jpg'),
    ('蒜蓉西兰花', '素菜', 11.00, '清爽蒜蓉西兰花，营养丰富', '/images/suanrongxilanhua.jpg'),
    ('清炒小白菜', '素菜', 6.00, '清淡清炒小白菜，清爽可口', '/images/qingchaoxiaobaicai.jpg'),
    ('醋溜白菜', '素菜', 7.00, '酸甜可口的醋溜白菜，开胃下饭', '/images/culiubaicai.jpg'),
    ('凉拌黄瓜', '素菜', 5.00, '清爽凉拌黄瓜，清脆爽口', '/images/liangbanhuanggua.jpg'),
    ('蒜蓉菠菜', '素菜', 8.00, '营养蒜蓉菠菜，清爽可口', '/images/suanrongbocai.jpg'),
    ('干锅花菜', '素菜', 13.00, '川菜干锅花菜，麻辣鲜香', '/images/ganguohuacai.jpg'),
    ('清炒时蔬', '素菜', 9.00, '清淡清炒时蔬，营养丰富', '/images/qingchaoshishu.jpg'),
    ('蒜蓉空心菜', '素菜', 7.00, '清爽蒜蓉空心菜，清脆爽口', '/images/suanrongkongxincai.jpg'),
    ('凉拌豆腐', '素菜', 6.00, '清爽凉拌豆腐，清淡可口', '/images/liangbandoufu.jpg'),
    
    # 汤类
    ('紫菜蛋花汤', '汤类', 8.00, '清淡紫菜蛋花汤，营养丰富', '/images/zicaidanhuatang.jpg'),
    ('西红柿鸡蛋汤', '汤类', 9.00, '家常西红柿鸡蛋汤，酸甜可口', '/images/xihongshijidantang.jpg'),
    ('冬瓜排骨汤', '汤类', 15.00, '营养冬瓜排骨汤，清淡鲜美', '/images/dongguapaigutang.jpg'),
    ('玉米排骨汤', '汤类', 16.00, '香甜玉米排骨汤，营养丰富', '/images/yumipaigutang.jpg'),
    ('银耳莲子汤', '汤类', 12.00, '滋补银耳莲子汤，清甜润燥', '/images/yinerlianzitang.jpg'),
    ('紫菜虾皮汤', '汤类', 10.00, '鲜美紫菜虾皮汤，清淡可口', '/images/zicaixiapitang.jpg'),
    ('酸辣汤', '汤类', 11.00, '开胃酸辣汤，酸辣鲜香', '/images/suanlatang.jpg'),
    ('冬瓜汤', '汤类', 7.00, '清淡冬瓜汤，清爽可口', '/images/dongguatang.jpg'),
    
    # 主食
    ('蛋炒饭', '主食', 10.00, '经典蛋炒饭，粒粒分明，香气扑鼻', '/images/danchaofan.jpg'),
    ('扬州炒饭', '主食', 12.00, '经典扬州炒饭，配料丰富', '/images/yangzhouchaoan.jpg'),
    ('西红柿鸡蛋面', '主食', 11.00, '家常西红柿鸡蛋面，酸甜可口', '/images/xihongshijidanmian.jpg'),
    ('炸酱面', '主食', 13.00, '北京炸酱面，酱香浓郁', '/images/zhajiangmian.jpg'),
    ('牛肉面', '主食', 18.00, '香浓牛肉面，牛肉鲜嫩', '/images/niuroumian.jpg'),
    ('担担面', '主食', 14.00, '四川担担面，麻辣鲜香', '/images/dandanmian.jpg'),
    ('水饺', '主食', 15.00, '手工水饺，皮薄馅大', '/images/shuijiao.jpg'),
    ('小笼包', '主食', 16.00, '上海小笼包，汤汁丰富', '/images/xiaolongbao.jpg'),
    ('蒸饺', '主食', 14.00, '鲜香蒸饺，皮薄馅大', '/images/zhengjiao.jpg'),
    ('馄饨', '主食', 12.00, '鲜美馄饨，汤清味美', '/images/huntun.jpg'),
    ('白米饭', '主食', 2.00, '香糯白米饭，粒粒分明', '/images/baimifan.jpg'),
    ('小米粥', '主食', 5.00, '营养小米粥，清淡养胃', '/images/xiaomizhou.jpg'),
    ('八宝粥', '主食', 8.00, '香甜八宝粥，营养丰富', '/images/babaozhou.jpg'),
    
    # 小吃
    ('炸鸡排', '小吃', 15.00, '香酥炸鸡排，外酥内嫩', '/images/zhajipai.jpg'),
    ('炸薯条', '小吃', 10.00, '香脆炸薯条，外酥内软', '/images/zhashutiao.jpg'),
    ('鸡米花', '小吃', 12.00, '香酥鸡米花，外酥内嫩', '/images/jimihua.jpg'),
    ('烤鸡翅', '小吃', 14.00, '香烤鸡翅，外酥内嫩', '/images/kaojichi.jpg'),
    ('手抓饼', '小吃', 8.00, '香酥手抓饼，层次分明', '/images/shouzhuabing.jpg'),
    ('煎饼果子', '小吃', 9.00, '经典煎饼果子，香脆可口', '/images/jianbingguozi.jpg'),
    ('烤冷面', '小吃', 10.00, '东北烤冷面，酸甜可口', '/images/kaolengmian.jpg'),
    ('关东煮', '小吃', 12.00, '日式关东煮，清淡鲜美', '/images/guandongzhu.jpg'),
]

def add_dishes():
    """添加菜品数据"""
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        
        # 检查现有菜品数量
        cursor.execute("SELECT COUNT(*) FROM dishes")
        count_result = cursor.fetchone()
        existing_count = count_result[0] if isinstance(count_result, (tuple, list)) else count_result.get('COUNT(*)') if isinstance(count_result, dict) else 0
        
        print(f"当前菜品数量: {existing_count}")
        
        # 添加新菜品（如果不存在）
        added_count = 0
        skipped_count = 0
        
        for name, category, price, description, image_url in EXTENDED_DISHES:
            # 检查是否已存在
            cursor.execute("SELECT id FROM dishes WHERE name = %s", (name,))
            existing = cursor.fetchone()
            
            if existing:
                skipped_count += 1
                continue
            
            # 插入新菜品
            cursor.execute("""
                INSERT INTO dishes (name, category, price, description, image_url)
                VALUES (%s, %s, %s, %s, %s)
            """, (name, category, price, description, image_url))
            added_count += 1
        
        connection.commit()
        
        # 显示结果
        cursor.execute("SELECT COUNT(*) FROM dishes")
        count_result = cursor.fetchone()
        total_count = count_result[0] if isinstance(count_result, (tuple, list)) else count_result.get('COUNT(*)') if isinstance(count_result, dict) else 0
        
        print(f"\n✅ 添加完成:")
        print(f"   新增菜品: {added_count}")
        print(f"   跳过（已存在）: {skipped_count}")
        print(f"   总菜品数: {total_count}")
        
        # 按分类统计
        cursor.execute("SELECT category, COUNT(*) as count FROM dishes GROUP BY category")
        categories = cursor.fetchall()
        print(f"\n📊 按分类统计:")
        for cat in categories:
            if isinstance(cat, dict):
                print(f"   {cat.get('category', '未知')}: {cat.get('count', 0)}")
            else:
                print(f"   {cat[0]}: {cat[1]}")
        
    except Exception as e:
        connection.rollback()
        print(f"❌ 添加菜品失败: {e}")
        import traceback
        traceback.print_exc()
    finally:
        if 'cursor' in locals():
            cursor.close()
        db.close()

if __name__ == '__main__':
    add_dishes()

