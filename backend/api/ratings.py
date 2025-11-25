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
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    try:
        # 获取并验证 user_id
        user_id = get_jwt_identity()
        
        # 确保 user_id 是整数
        if isinstance(user_id, str):
            try:
                user_id = int(user_id)
            except ValueError:
                return jsonify({
                    'error': 'Invalid user ID format',
                    'error_code': 'INVALID_USER_ID',
                    'request_id': request_id
                }), 400
        elif not isinstance(user_id, int):
            return jsonify({
                'error': 'Invalid user ID format',
                'error_code': 'INVALID_USER_ID',
                'request_id': request_id
            }), 400
        
        # 验证 user_id 范围
        if user_id <= 0:
            return jsonify({
                'error': 'Invalid user ID: must be positive',
                'error_code': 'INVALID_USER_ID',
                'request_id': request_id
            }), 400
        
        # 获取请求数据
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'Request body is required',
                'error_code': 'MISSING_BODY',
                'request_id': request_id
            }), 400
        
        dish_id = data.get('dish_id')
        rating = data.get('rating')
        comment = data.get('comment', '')
        
        # 验证必需参数
        if dish_id is None:
            return jsonify({
                'error': 'dish_id is required',
                'error_code': 'MISSING_DISH_ID',
                'request_id': request_id
            }), 400
        
        if rating is None:
            return jsonify({
                'error': 'rating is required',
                'error_code': 'MISSING_RATING',
                'request_id': request_id
            }), 400
        
        # 验证参数类型和范围
        try:
            dish_id = int(dish_id)
            rating = float(rating)
        except (ValueError, TypeError):
            return jsonify({
                'error': 'dish_id must be integer and rating must be number',
                'error_code': 'INVALID_PARAM_TYPE',
                'request_id': request_id
            }), 400
        
        if dish_id <= 0:
            return jsonify({
                'error': 'dish_id must be positive',
                'error_code': 'INVALID_DISH_ID',
                'request_id': request_id
            }), 400
        
        if rating < 1 or rating > 5:
            return jsonify({
                'error': 'Rating must be between 1 and 5',
                'error_code': 'INVALID_RATING_RANGE',
                'request_id': request_id
            }), 400
        
        # 验证 comment 长度
        if comment and len(comment) > 500:
            return jsonify({
                'error': 'Comment must be less than 500 characters',
                'error_code': 'COMMENT_TOO_LONG',
                'request_id': request_id
            }), 400
        
        print(f"[Ratings API] Request ID: {request_id}, User ID: {user_id}, Dish ID: {dish_id}, Rating: {rating}")
        
        # 数据库操作
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
            
            return jsonify({
                'message': 'Rating created successfully',
                'request_id': request_id
            }), 201
        except Exception as e:
            connection.rollback()
            import traceback
            error_msg = str(e) if str(e) else traceback.format_exc()
            print(f"[Ratings API] 创建评分失败: {error_msg}")
            traceback.print_exc()
            return jsonify({
                'error': error_msg,
                'error_code': 'DATABASE_ERROR',
                'request_id': request_id
            }), 500
        finally:
            cursor.close()
            
    except Exception as e:
        import traceback
        error_msg = str(e) if str(e) else traceback.format_exc()
        print(f"[Ratings API] 参数验证失败: {error_msg}")
        traceback.print_exc()
        return jsonify({
            'error': f'Parameter validation failed: {error_msg}',
            'error_code': 'VALIDATION_ERROR',
            'request_id': request_id
        }), 400

@bp.route('/ratings/<int:dish_id>', methods=['GET'])
@jwt_required()
def get_rating(dish_id):
    """获取用户对菜品的评分"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    try:
        # 获取并验证 user_id
        user_id = get_jwt_identity()
        
        # 确保 user_id 是整数
        if isinstance(user_id, str):
            try:
                user_id = int(user_id)
            except ValueError:
                return jsonify({
                    'error': 'Invalid user ID format',
                    'error_code': 'INVALID_USER_ID',
                    'request_id': request_id
                }), 400
        elif not isinstance(user_id, int):
            return jsonify({
                'error': 'Invalid user ID format',
                'error_code': 'INVALID_USER_ID',
                'request_id': request_id
            }), 400
        
        # 验证参数
        if dish_id <= 0:
            return jsonify({
                'error': 'Invalid dish_id: must be positive',
                'error_code': 'INVALID_DISH_ID',
                'request_id': request_id
            }), 400
        
        if user_id <= 0:
            return jsonify({
                'error': 'Invalid user ID: must be positive',
                'error_code': 'INVALID_USER_ID',
                'request_id': request_id
            }), 400
        
        print(f"[Ratings API] Request ID: {request_id}, User ID: {user_id}, Dish ID: {dish_id}")
        
    except Exception as e:
        import traceback
        error_msg = str(e) if str(e) else traceback.format_exc()
        print(f"[Ratings API] 参数验证失败: {error_msg}")
        traceback.print_exc()
        return jsonify({
            'error': f'Parameter validation failed: {error_msg}',
            'error_code': 'VALIDATION_ERROR',
            'request_id': request_id
        }), 400
    
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
            return jsonify({
                'rating': None,
                'request_id': request_id
            }), 200
    except Exception as e:
        import traceback
        error_msg = str(e) if str(e) else traceback.format_exc()
        print(f"[Ratings API] 获取评分失败: {error_msg}")
        traceback.print_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'DATABASE_ERROR',
            'request_id': request_id
        }), 500
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
