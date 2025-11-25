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
    try:
        user_id = get_jwt_identity()
        # 确保 user_id 是整数
        if isinstance(user_id, str):
            try:
                user_id = int(user_id)
            except ValueError:
                import traceback
                error_msg = f"无法将 user_id 转换为整数: {user_id}, 类型: {type(user_id)}"
                print(f"获取用户ID失败: {error_msg}")
                traceback.print_exc()
                return jsonify({'error': 'Invalid user ID format'}), 400
        elif not isinstance(user_id, int):
            import traceback
            error_msg = f"user_id 类型不正确: {user_id}, 类型: {type(user_id)}"
            print(f"获取用户ID失败: {error_msg}")
            traceback.print_exc()
            return jsonify({'error': 'Invalid user ID format'}), 400
        
        n = request.args.get('n', Config.RECOMMENDATION_COUNT, type=int)
        if n is None:
            n = Config.RECOMMENDATION_COUNT
    except Exception as e:
        import traceback
        error_msg = str(e) if str(e) else traceback.format_exc()
        print(f"获取用户ID失败: {error_msg}")
        traceback.print_exc()
        return jsonify({'error': f'Invalid authentication: {error_msg}'}), 401
    
    # 尝试从Redis缓存获取
    try:
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
    except Exception as e:
        # 如果 Redis 失败，直接生成推荐（不使用缓存）
        print(f"Redis 错误: {e}")
        dish_ids = recommender.recommend(user_id, n)
    
    # 获取菜品详情
    connection = db.get_connection()
    try:
        if not dish_ids:
            return jsonify({'dishes': []}), 200
        
        # 确保 dish_ids 都是整数
        dish_ids = [int(did) for did in dish_ids if did is not None]
        
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
        # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
        if dishes and isinstance(dishes[0], dict):
            dish_dict = {dish.get('id'): dish for dish in dishes}
        else:
            dish_dict = {dish[0]: dish for dish in dishes}
        
        result = []
        for dish_id in dish_ids:
            if dish_id in dish_dict:
                dish = dish_dict[dish_id]
                if isinstance(dish, dict):
                    result.append({
                        'id': dish.get('id'),
                        'name': dish.get('name'),
                        'category': dish.get('category'),
                        'price': float(dish.get('price', 0)),
                        'description': dish.get('description'),
                        'image_url': dish.get('image_url'),
                        'nutrition_info': dish.get('nutrition_info')
                    })
                else:
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
        import traceback
        error_msg = str(e) if str(e) else traceback.format_exc()
        print(f"推荐API错误: {error_msg}")
        return jsonify({'error': error_msg}), 500
    finally:
        cursor.close()
