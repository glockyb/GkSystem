"""
推荐API
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models.recommender import recommender
from config import Config
import pymysql
from utils.database import db
import redis

bp = Blueprint('recommendations', __name__)

@bp.route('/recommendations', methods=['GET'])
@jwt_required()
def get_recommendations():
    """获取个性化推荐"""
    user_id = get_jwt_identity()
    n = request.args.get('n', Config.RECOMMENDATION_COUNT, type=int)
    
    # 尝试从Redis缓存获取
    redis_client = db.get_redis()
    cache_key = f'recommendations:user:{user_id}'
    cached = redis_client.get(cache_key)
    
    if cached:
        import json
        dish_ids = json.loads(cached)
    else:
        # 生成推荐
        dish_ids = recommender.recommend(user_id, n)
        
        # 缓存结果（1小时）
        import json
        redis_client.setex(cache_key, 3600, json.dumps(dish_ids))
    
    # 获取菜品详情
    connection = db.get_connection()
    try:
        if not dish_ids:
            return jsonify({'dishes': []}), 200
        
        placeholders = ','.join(['%s'] * len(dish_ids))
        cursor = connection.cursor()
        cursor.execute(
            f"SELECT * FROM dishes WHERE id IN ({placeholders})",
            dish_ids
        )
        dishes = cursor.fetchall()
        
        # 保持推荐顺序
        dish_dict = {dish[0]: dish for dish in dishes}
        result = []
        for dish_id in dish_ids:
            if dish_id in dish_dict:
                dish = dish_dict[dish_id]
                result.append({
                    'id': dish[0],
                    'name': dish[1],
                    'category': dish[2],
                    'price': float(dish[3]),
                    'description': dish[4],
                    'image_url': dish[5],
                    'nutrition_info': dish[6]
                })
        
        return jsonify({'dishes': result}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
