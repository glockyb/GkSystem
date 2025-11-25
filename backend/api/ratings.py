"""
评分API
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
import pymysql
from datetime import datetime
from utils.database import db

bp = Blueprint('ratings', __name__)

@bp.route('/ratings', methods=['POST'])
@jwt_required()
def create_rating():
    """创建评分"""
    user_id = get_jwt_identity()
    data = request.get_json()
    dish_id = data.get('dish_id')
    rating = data.get('rating')
    comment = data.get('comment')
    
    if not dish_id or not rating:
        return jsonify({'error': 'dish_id and rating are required'}), 400
    
    if rating < 1 or rating > 5:
        return jsonify({'error': 'Rating must be between 1 and 5'}), 400
    
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        
        # 插入或更新评分
        cursor.execute("""
            INSERT INTO ratings (user_id, dish_id, rating, comment)
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
            rating = VALUES(rating),
            comment = VALUES(comment),
            updated_at = NOW()
        """, (user_id, dish_id, rating, comment))
        
        connection.commit()
        
        return jsonify({'message': 'Rating created successfully'}), 201
    except Exception as e:
        connection.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()

@bp.route('/ratings/<int:dish_id>', methods=['GET'])
@jwt_required()
def get_rating(dish_id):
    """获取用户对菜品的评分"""
    user_id = get_jwt_identity()
    
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        cursor.execute(
            "SELECT rating, comment FROM ratings WHERE user_id = %s AND dish_id = %s",
            (user_id, dish_id)
        )
        rating = cursor.fetchone()
        
        if rating:
            # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
            if isinstance(rating, dict):
                return jsonify({
                    'rating': rating.get('rating'),
                    'comment': rating.get('comment')
                }), 200
            else:
                return jsonify({
                    'rating': rating[0],
                    'comment': rating[1]
                }), 200
        else:
            return jsonify({'rating': None}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()

@bp.route('/history', methods=['GET'])
@jwt_required()
def get_history():
    """获取用户消费历史"""
    user_id = get_jwt_identity()
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        cursor.execute("""
            SELECT cr.id, cr.dish_id, d.name, d.category, cr.price, cr.rating, cr.consumption_time
            FROM consumption_records cr
            JOIN dishes d ON cr.dish_id = d.id
            WHERE cr.user_id = %s
            ORDER BY cr.consumption_time DESC
            LIMIT %s OFFSET %s
        """, (user_id, per_page, (page - 1) * per_page))
        
        records = cursor.fetchall()
        result = []
        for record in records:
            # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
            if isinstance(record, dict):
                result.append({
                    'id': record.get('id'),
                    'dish_id': record.get('dish_id'),
                    'dish_name': record.get('name'),
                    'category': record.get('category'),
                    'price': float(record.get('price', 0)),
                    'rating': record.get('rating'),
                    'consumption_time': record.get('consumption_time').isoformat() if record.get('consumption_time') else None
                })
            else:
                result.append({
                    'id': record[0],
                    'dish_id': record[1],
                    'dish_name': record[2],
                    'category': record[3],
                    'price': float(record[4]),
                    'rating': record[5],
                    'consumption_time': record[6].isoformat() if record[6] else None
                })
        
        return jsonify({'history': result}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
