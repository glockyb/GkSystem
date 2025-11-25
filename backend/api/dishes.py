"""
菜品API
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
import pymysql
from utils.database import db

bp = Blueprint('dishes', __name__)

@bp.route('/dishes', methods=['GET'])
def get_dishes():
    """获取菜品列表"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        category = request.args.get('category')
        search = request.args.get('search')
        
        # 验证参数
        if page < 1:
            page = 1
        if per_page < 1 or per_page > 100:
            per_page = 20
        
        print(f"[Dishes API] Request ID: {request_id}, Page: {page}, Per Page: {per_page}, Category: {category}")
        
        connection = db.get_connection()
        try:
            cursor = connection.cursor()
            
            # 构建查询
            query = "SELECT * FROM dishes WHERE 1=1"
            params = []
            
            if category:
                query += " AND category = %s"
                params.append(category)
            
            if search:
                query += " AND name LIKE %s"
                params.append(f'%{search}%')
            
            query += " ORDER BY id LIMIT %s OFFSET %s"
            params.extend([per_page, (page - 1) * per_page])
            
            cursor.execute(query, params)
            dishes = cursor.fetchall()
            
            # 转换为字典列表
            result = []
            for dish in dishes:
                # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
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
            
            print(f"[Dishes API] Request ID: {request_id}, Found {len(result)} dishes")
            return jsonify({
                'dishes': result,
                'page': page,
                'per_page': per_page,
                'total': len(result),
                'request_id': request_id
            }), 200
        except Exception as e:
            import traceback
            error_msg = str(e) if str(e) else traceback.format_exc()
            print(f"[Dishes API] 数据库错误: {error_msg}")
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
        print(f"[Dishes API] 参数验证错误: {error_msg}")
        traceback.print_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'VALIDATION_ERROR',
            'request_id': request_id
        }), 500

@bp.route('/dishes/<int:dish_id>', methods=['GET'])
def get_dish(dish_id):
    """获取单个菜品详情"""
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT * FROM dishes WHERE id = %s", (dish_id,))
        dish = cursor.fetchone()
        
        if not dish:
            return jsonify({'error': 'Dish not found'}), 404
        
        # 获取平均评分
        cursor.execute("SELECT AVG(rating) FROM ratings WHERE dish_id = %s", (dish_id,))
        avg_rating_row = cursor.fetchone()
        if isinstance(avg_rating_row, dict):
            avg_rating = avg_rating_row.get('AVG(rating)') or 0
        else:
            avg_rating = avg_rating_row[0] if avg_rating_row else 0
        
        # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
        if isinstance(dish, dict):
            return jsonify({
                'id': dish.get('id'),
                'name': dish.get('name'),
                'category': dish.get('category'),
                'price': float(dish.get('price', 0)),
                'description': dish.get('description'),
                'image_url': dish.get('image_url'),
                'nutrition_info': dish.get('nutrition_info'),
                'avg_rating': float(avg_rating)
            }), 200
        else:
            return jsonify({
                'id': dish[0],
                'name': dish[1],
                'category': dish[2],
                'price': float(dish[3]),
                'description': dish[4],
                'image_url': dish[5],
                'nutrition_info': dish[6],
                'avg_rating': float(avg_rating)
            }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()

@bp.route('/dishes/categories', methods=['GET'])
def get_categories():
    """获取菜品分类"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT DISTINCT category FROM dishes WHERE category IS NOT NULL")
        rows = cursor.fetchall()
        
        # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
        if rows and isinstance(rows[0], dict):
            categories = [row['category'] for row in rows if row.get('category')]
        else:
            categories = [row[0] for row in rows if row[0]]
        
        # 去重并排序
        categories = sorted(list(set(categories)))
        
        print(f"[Dishes API] Request ID: {request_id}, Found {len(categories)} categories")
        return jsonify({
            'categories': categories,
            'count': len(categories),
            'request_id': request_id
        }), 200
    except Exception as e:
        import traceback
        error_msg = str(e) if str(e) else traceback.format_exc()
        print(f"[Dishes API] 获取分类失败: {error_msg}")
        traceback.print_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'DATABASE_ERROR',
            'request_id': request_id
        }), 500
    finally:
        cursor.close()
