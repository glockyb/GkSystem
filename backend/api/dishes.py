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
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    category = request.args.get('category')
    search = request.args.get('search')
    
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
        avg_rating = cursor.fetchone()[0] or 0
        
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
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT DISTINCT category FROM dishes")
        categories = [row[0] for row in cursor.fetchall()]
        return jsonify({'categories': categories}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
