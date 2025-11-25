#!/usr/bin/env python3
"""
添加示例评分数据到数据库
用于测试推荐功能
"""
import sys
import os
import random
from datetime import datetime, timedelta

# 添加项目根目录到路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from backend.utils.database import db
import pymysql

def add_sample_ratings():
    """添加示例评分数据"""
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        
        # 获取所有用户
        cursor.execute("SELECT id FROM users")
        users = cursor.fetchall()
        if not users:
            print("❌ 没有用户，请先注册用户")
            return
        
        if isinstance(users[0], dict):
            user_ids = [u.get('id') for u in users if u.get('id')]
        else:
            user_ids = [u[0] for u in users if u[0]]
        
        if not user_ids:
            print("❌ 没有有效的用户ID")
            return
        
        # 获取所有菜品
        cursor.execute("SELECT id FROM dishes")
        dishes = cursor.fetchall()
        if not dishes:
            print("❌ 没有菜品数据")
            return
        
        if isinstance(dishes[0], dict):
            dish_ids = [d.get('id') for d in dishes if d.get('id')]
        else:
            dish_ids = [d[0] for d in dishes if d[0]]
        
        if not dish_ids:
            print("❌ 没有菜品数据")
            return
        
        print(f"✅ 找到 {len(user_ids)} 个用户，{len(dish_ids)} 个菜品")
        print("开始添加评分数据...")
        
        # 为每个用户添加一些评分
        total_ratings = 0
        for user_id in user_ids:
            # 每个用户随机评分 5-15 个菜品
            num_ratings = random.randint(5, min(15, len(dish_ids)))
            rated_dishes = random.sample(dish_ids, num_ratings)
            
            for dish_id in rated_dishes:
                # 随机评分（1-5星，偏向高分）
                rating = random.choices(
                    [1, 2, 3, 4, 5],
                    weights=[0.05, 0.1, 0.15, 0.3, 0.4]  # 更偏向4-5星
                )[0]
                
                # 随机评论
                comments = [
                    "很好吃！",
                    "味道不错",
                    "一般般",
                    "推荐",
                    "下次还会点",
                    "不太喜欢",
                    "还可以",
                    "很棒",
                    None
                ]
                comment = random.choice(comments)
                
                # 随机时间（最近30天内）
                days_ago = random.randint(0, 30)
                created_at = datetime.now() - timedelta(days=days_ago)
                
                try:
                    # 插入或更新评分
                    cursor.execute("""
                        INSERT INTO ratings (user_id, dish_id, rating, comment, created_at)
                        VALUES (%s, %s, %s, %s, %s)
                        ON DUPLICATE KEY UPDATE
                        rating = VALUES(rating),
                        comment = VALUES(comment),
                        updated_at = NOW()
                    """, (user_id, dish_id, rating, comment, created_at))
                    total_ratings += 1
                except Exception as e:
                    print(f"⚠️  插入评分失败 (user_id={user_id}, dish_id={dish_id}): {e}")
        
        connection.commit()
        print(f"✅ 成功添加 {total_ratings} 条评分数据")
        
        # 显示统计信息
        cursor.execute("SELECT COUNT(*) as total FROM ratings")
        count = cursor.fetchone()
        if isinstance(count, dict):
            total_count = count.get('total', 0)
        else:
            total_count = count[0] if count else 0
        print(f"📊 数据库中总共有 {total_count} 条评分记录")
        
        # 显示每个菜品的平均评分
        cursor.execute("""
            SELECT d.id, d.name, AVG(r.rating) as avg_rating, COUNT(r.id) as rating_count
            FROM dishes d
            LEFT JOIN ratings r ON d.id = r.dish_id
            GROUP BY d.id, d.name
            ORDER BY rating_count DESC
            LIMIT 10
        """)
        top_dishes = cursor.fetchall()
        
        print("\n📈 评分最多的菜品（前10）:")
        for dish in top_dishes:
            if isinstance(dish, dict):
                dish_id = dish.get('id')
                name = dish.get('name')
                avg = dish.get('avg_rating') or 0
                count = dish.get('rating_count') or 0
            else:
                dish_id, name, avg, count = dish[0], dish[1], dish[2] or 0, dish[3] or 0
            print(f"  - {name}: 平均 {avg:.2f} 星 ({count} 条评分)")
        
    except Exception as e:
        connection.rollback()
        print(f"❌ 添加评分数据失败: {e}")
        import traceback
        traceback.print_exc()
    finally:
        cursor.close()

if __name__ == '__main__':
    print("=" * 50)
    print("添加示例评分数据")
    print("=" * 50)
    print()
    add_sample_ratings()
    print()
    print("=" * 50)
    print("完成！现在可以重新训练推荐模型")
    print("运行: cd backend && python train_model.py")
    print("=" * 50)

