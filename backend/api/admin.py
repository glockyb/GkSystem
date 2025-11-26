"""
后台管理API
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
import pymysql
from utils.database import db
import traceback

bp = Blueprint('admin', __name__)

def check_admin(user_id):
    """检查用户是否为管理员"""
    connection = db.get_connection()
    try:
        cursor = connection.cursor(pymysql.cursors.DictCursor)
        cursor.execute("SELECT is_admin, role FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        
        if not user:
            return False
        
        if isinstance(user, dict):
            return user.get('is_admin') == 1 or user.get('role') == 'admin'
        else:
            return user[0] == 1 or user[1] == 'admin'
    except Exception as e:
        print(f"[Admin] 检查管理员权限失败: {e}")
        traceback.print_exc()
        return False
    finally:
        if 'cursor' in locals():
            cursor.close()

def admin_required(f):
    """管理员权限装饰器"""
    from functools import wraps
    
    @wraps(f)
    @jwt_required()
    def decorated_function(*args, **kwargs):
        user_id_str = get_jwt_identity()
        try:
            user_id = int(user_id_str) if isinstance(user_id_str, str) else user_id_str
        except (ValueError, TypeError):
            return jsonify({
                'error': 'Invalid user ID format',
                'error_code': 'INVALID_USER_ID'
            }), 400
        
        if not check_admin(user_id):
            return jsonify({
                'error': 'Admin access required',
                'error_code': 'ADMIN_REQUIRED'
            }), 403
        
        return f(*args, **kwargs)
    return decorated_function

# ==================== 菜品管理 ====================

@bp.route('/admin/dishes', methods=['GET'])
@admin_required
def get_all_dishes():
    """获取所有菜品（管理员）"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        search = request.args.get('search')
        category = request.args.get('category')
        
        if page < 1:
            page = 1
        if per_page < 1 or per_page > 100:
            per_page = 50
        
        connection = db.get_connection()
        try:
            cursor = connection.cursor(pymysql.cursors.DictCursor)
            
            # 构建查询
            where_conditions = []
            params = []
            
            if search:
                where_conditions.append("name LIKE %s")
                params.append(f'%{search}%')
            
            if category:
                where_conditions.append("category = %s")
                params.append(category)
            
            where_clause = " WHERE " + " AND ".join(where_conditions) if where_conditions else ""
            
            # 获取总数
            count_query = f"SELECT COUNT(*) as total FROM dishes{where_clause}"
            cursor.execute(count_query, params)
            total_result = cursor.fetchone()
            total = total_result.get('total') if isinstance(total_result, dict) else total_result[0]
            
            # 获取列表
            query = f"""
                SELECT d1.id, d1.name, d1.category, d1.price, d1.description, d1.image_url, 
                       d1.nutrition_info, d1.created_at, d1.updated_at,
                       (SELECT COUNT(*) FROM ratings WHERE dish_id = d1.id) as rating_count,
                       (SELECT AVG(rating) FROM ratings WHERE dish_id = d1.id) as avg_rating
                FROM dishes d1
                INNER JOIN (
                    SELECT name, MIN(id) as min_id
                    FROM dishes
                    {where_clause}
                    GROUP BY name
                ) d2 ON d1.name = d2.name AND d1.id = d2.min_id
                {where_clause.replace('name', 'd1.name').replace('category', 'd1.category')}
                ORDER BY d1.id DESC
                LIMIT %s OFFSET %s
            """
            params.extend([per_page, (page - 1) * per_page])
            
            cursor.execute(query, params)
            dishes = cursor.fetchall()
            
            result = []
            for dish in dishes:
                result.append({
                    'id': dish.get('id'),
                    'name': dish.get('name'),
                    'category': dish.get('category'),
                    'price': float(dish.get('price', 0)) if dish.get('price') else 0.0,
                    'description': dish.get('description'),
                    'image_url': dish.get('image_url'),
                    'nutrition_info': dish.get('nutrition_info'),
                    'rating_count': dish.get('rating_count', 0),
                    'avg_rating': float(dish.get('avg_rating', 0)) if dish.get('avg_rating') else 0.0,
                    'created_at': dish.get('created_at').isoformat() if dish.get('created_at') else None,
                    'updated_at': dish.get('updated_at').isoformat() if dish.get('updated_at') else None
                })
            
            return jsonify({
                'dishes': result,
                'total': total,
                'page': page,
                'per_page': per_page,
                'request_id': request_id
            }), 200
        except Exception as e:
            error_msg = str(e) if str(e) else traceback.format_exc()
            print(f"[Admin Dishes] 错误: {error_msg}")
            traceback.print_exc()
            return jsonify({
                'error': error_msg,
                'error_code': 'DATABASE_ERROR',
                'request_id': request_id
            }), 500
        finally:
            if 'cursor' in locals():
                cursor.close()
    except Exception as e:
        error_msg = str(e) if str(e) else traceback.format_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'UNEXPECTED_ERROR',
            'request_id': request_id
        }), 500

@bp.route('/admin/dishes', methods=['POST'])
@admin_required
def create_dish():
    """创建菜品"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'Request body is required',
                'error_code': 'MISSING_BODY',
                'request_id': request_id
            }), 400
        
        name = data.get('name')
        category = data.get('category')
        price = data.get('price')
        description = data.get('description', '')
        image_url = data.get('image_url', '')
        nutrition_info = data.get('nutrition_info')
        
        if not name:
            return jsonify({
                'error': 'name is required',
                'error_code': 'MISSING_NAME',
                'request_id': request_id
            }), 400
        
        if price is None:
            return jsonify({
                'error': 'price is required',
                'error_code': 'MISSING_PRICE',
                'request_id': request_id
            }), 400
        
        try:
            price = float(price)
            if price < 0:
                raise ValueError("Price must be positive")
        except (ValueError, TypeError):
            return jsonify({
                'error': 'price must be a positive number',
                'error_code': 'INVALID_PRICE',
                'request_id': request_id
            }), 400
        
        connection = db.get_connection()
        try:
            cursor = connection.cursor()
            
            # 检查是否已存在同名菜品
            cursor.execute("SELECT id FROM dishes WHERE name = %s", (name,))
            if cursor.fetchone():
                return jsonify({
                    'error': 'Dish with this name already exists',
                    'error_code': 'DUPLICATE_NAME',
                    'request_id': request_id
                }), 400
            
            # 插入新菜品
            cursor.execute("""
                INSERT INTO dishes (name, category, price, description, image_url, nutrition_info)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (name, category, price, description, image_url, nutrition_info))
            
            connection.commit()
            dish_id = cursor.lastrowid
            
            return jsonify({
                'message': 'Dish created successfully',
                'dish_id': dish_id,
                'request_id': request_id
            }), 201
        except pymysql.Error as db_error:
            connection.rollback()
            error_msg = f"Database error: {db_error}"
            print(f"[Admin Dishes] {error_msg}")
            traceback.print_exc()
            return jsonify({
                'error': error_msg,
                'error_code': 'DB_ERROR',
                'request_id': request_id
            }), 500
        finally:
            if 'cursor' in locals():
                cursor.close()
    except Exception as e:
        error_msg = str(e) if str(e) else traceback.format_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'UNEXPECTED_ERROR',
            'request_id': request_id
        }), 500

@bp.route('/admin/dishes/<int:dish_id>', methods=['PUT'])
@admin_required
def update_dish(dish_id):
    """更新菜品"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'Request body is required',
                'error_code': 'MISSING_BODY',
                'request_id': request_id
            }), 400
        
        connection = db.get_connection()
        try:
            cursor = connection.cursor()
            
            # 检查菜品是否存在
            cursor.execute("SELECT id FROM dishes WHERE id = %s", (dish_id,))
            if not cursor.fetchone():
                return jsonify({
                    'error': 'Dish not found',
                    'error_code': 'DISH_NOT_FOUND',
                    'request_id': request_id
                }), 404
            
            # 构建更新语句
            updates = []
            params = []
            
            if 'name' in data:
                updates.append("name = %s")
                params.append(data['name'])
            
            if 'category' in data:
                updates.append("category = %s")
                params.append(data['category'])
            
            if 'price' in data:
                try:
                    price = float(data['price'])
                    if price < 0:
                        raise ValueError("Price must be positive")
                    updates.append("price = %s")
                    params.append(price)
                except (ValueError, TypeError):
                    return jsonify({
                        'error': 'price must be a positive number',
                        'error_code': 'INVALID_PRICE',
                        'request_id': request_id
                    }), 400
            
            if 'description' in data:
                updates.append("description = %s")
                params.append(data['description'])
            
            if 'image_url' in data:
                updates.append("image_url = %s")
                params.append(data['image_url'])
            
            if 'nutrition_info' in data:
                updates.append("nutrition_info = %s")
                params.append(data['nutrition_info'])
            
            if not updates:
                return jsonify({
                    'error': 'No fields to update',
                    'error_code': 'NO_UPDATES',
                    'request_id': request_id
                }), 400
            
            updates.append("updated_at = NOW()")
            params.append(dish_id)
            
            query = f"UPDATE dishes SET {', '.join(updates)} WHERE id = %s"
            cursor.execute(query, params)
            connection.commit()
            
            return jsonify({
                'message': 'Dish updated successfully',
                'request_id': request_id
            }), 200
        except pymysql.Error as db_error:
            connection.rollback()
            error_msg = f"Database error: {db_error}"
            print(f"[Admin Dishes] {error_msg}")
            traceback.print_exc()
            return jsonify({
                'error': error_msg,
                'error_code': 'DB_ERROR',
                'request_id': request_id
            }), 500
        finally:
            if 'cursor' in locals():
                cursor.close()
    except Exception as e:
        error_msg = str(e) if str(e) else traceback.format_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'UNEXPECTED_ERROR',
            'request_id': request_id
        }), 500

@bp.route('/admin/dishes/<int:dish_id>', methods=['DELETE'])
@admin_required
def delete_dish(dish_id):
    """删除菜品"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        
        # 检查菜品是否存在
        cursor.execute("SELECT id FROM dishes WHERE id = %s", (dish_id,))
        if not cursor.fetchone():
            return jsonify({
                'error': 'Dish not found',
                'error_code': 'DISH_NOT_FOUND',
                'request_id': request_id
            }), 404
        
        # 删除菜品（外键约束会自动删除相关评分等）
        cursor.execute("DELETE FROM dishes WHERE id = %s", (dish_id,))
        connection.commit()
        
        return jsonify({
            'message': 'Dish deleted successfully',
            'request_id': request_id
        }), 200
    except pymysql.Error as db_error:
        connection.rollback()
        error_msg = f"Database error: {db_error}"
        print(f"[Admin Dishes] {error_msg}")
        traceback.print_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'DB_ERROR',
            'request_id': request_id
        }), 500
    finally:
        if 'cursor' in locals():
            cursor.close()

# ==================== 用户管理 ====================

@bp.route('/admin/users', methods=['GET'])
@admin_required
def get_all_users():
    """获取所有用户"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        search = request.args.get('search')
        
        if page < 1:
            page = 1
        if per_page < 1 or per_page > 100:
            per_page = 50
        
        connection = db.get_connection()
        try:
            cursor = connection.cursor(pymysql.cursors.DictCursor)
            
            # 构建查询
            where_clause = ""
            params = []
            
            if search:
                where_clause = " WHERE username LIKE %s OR email LIKE %s"
                params.extend([f'%{search}%', f'%{search}%'])
            
            # 获取总数
            count_query = f"SELECT COUNT(*) as total FROM users{where_clause}"
            cursor.execute(count_query, params)
            total_result = cursor.fetchone()
            total = total_result.get('total') if isinstance(total_result, dict) else total_result[0]
            
            # 获取列表
            query = f"""
                SELECT u.id, u.username, u.email, u.role, u.is_admin, u.created_at, u.updated_at,
                       (SELECT COUNT(*) FROM ratings WHERE user_id = u.id) as rating_count,
                       (SELECT COUNT(*) FROM consumption_records WHERE user_id = u.id) as consumption_count
                FROM users u
                {where_clause.replace('username', 'u.username').replace('email', 'u.email')}
                ORDER BY u.id DESC
                LIMIT %s OFFSET %s
            """
            params.extend([per_page, (page - 1) * per_page])
            
            cursor.execute(query, params)
            users = cursor.fetchall()
            
            result = []
            for user in users:
                result.append({
                    'id': user.get('id'),
                    'username': user.get('username'),
                    'email': user.get('email'),
                    'role': user.get('role', 'user'),
                    'is_admin': bool(user.get('is_admin', 0)),
                    'rating_count': user.get('rating_count', 0),
                    'consumption_count': user.get('consumption_count', 0),
                    'created_at': user.get('created_at').isoformat() if user.get('created_at') else None,
                    'updated_at': user.get('updated_at').isoformat() if user.get('updated_at') else None
                })
            
            return jsonify({
                'users': result,
                'total': total,
                'page': page,
                'per_page': per_page,
                'request_id': request_id
            }), 200
        except Exception as e:
            error_msg = str(e) if str(e) else traceback.format_exc()
            print(f"[Admin Users] 错误: {error_msg}")
            traceback.print_exc()
            return jsonify({
                'error': error_msg,
                'error_code': 'DATABASE_ERROR',
                'request_id': request_id
            }), 500
        finally:
            if 'cursor' in locals():
                cursor.close()
    except Exception as e:
        error_msg = str(e) if str(e) else traceback.format_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'UNEXPECTED_ERROR',
            'request_id': request_id
        }), 500

@bp.route('/admin/users/<int:user_id>', methods=['PUT'])
@admin_required
def update_user(user_id):
    """更新用户信息"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    try:
        data = request.get_json()
        if not data:
            return jsonify({
                'error': 'Request body is required',
                'error_code': 'MISSING_BODY',
                'request_id': request_id
            }), 400
        
        connection = db.get_connection()
        try:
            cursor = connection.cursor()
            
            # 检查用户是否存在
            cursor.execute("SELECT id FROM users WHERE id = %s", (user_id,))
            if not cursor.fetchone():
                return jsonify({
                    'error': 'User not found',
                    'error_code': 'USER_NOT_FOUND',
                    'request_id': request_id
                }), 404
            
            # 构建更新语句
            updates = []
            params = []
            
            if 'email' in data:
                updates.append("email = %s")
                params.append(data['email'])
            
            if 'role' in data:
                if data['role'] not in ['user', 'admin']:
                    return jsonify({
                        'error': 'Invalid role. Must be "user" or "admin"',
                        'error_code': 'INVALID_ROLE',
                        'request_id': request_id
                    }), 400
                updates.append("role = %s")
                updates.append("is_admin = %s")
                params.append(data['role'])
                params.append(data['role'] == 'admin')
            
            if not updates:
                return jsonify({
                    'error': 'No fields to update',
                    'error_code': 'NO_UPDATES',
                    'request_id': request_id
                }), 400
            
            updates.append("updated_at = NOW()")
            params.append(user_id)
            
            query = f"UPDATE users SET {', '.join(updates)} WHERE id = %s"
            cursor.execute(query, params)
            connection.commit()
            
            return jsonify({
                'message': 'User updated successfully',
                'request_id': request_id
            }), 200
        except pymysql.Error as db_error:
            connection.rollback()
            error_msg = f"Database error: {db_error}"
            print(f"[Admin Users] {error_msg}")
            traceback.print_exc()
            return jsonify({
                'error': error_msg,
                'error_code': 'DB_ERROR',
                'request_id': request_id
            }), 500
        finally:
            if 'cursor' in locals():
                cursor.close()
    except Exception as e:
        error_msg = str(e) if str(e) else traceback.format_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'UNEXPECTED_ERROR',
            'request_id': request_id
        }), 500

@bp.route('/admin/users/<int:user_id>', methods=['DELETE'])
@admin_required
def delete_user(user_id):
    """删除用户"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        
        # 检查用户是否存在
        cursor.execute("SELECT id, is_admin FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        
        if not user:
            return jsonify({
                'error': 'User not found',
                'error_code': 'USER_NOT_FOUND',
                'request_id': request_id
            }), 404
        
        # 不能删除自己
        current_user_id = int(get_jwt_identity())
        if user_id == current_user_id:
            return jsonify({
                'error': 'Cannot delete yourself',
                'error_code': 'CANNOT_DELETE_SELF',
                'request_id': request_id
            }), 400
        
        # 删除用户（外键约束会自动删除相关数据）
        cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
        connection.commit()
        
        return jsonify({
            'message': 'User deleted successfully',
            'request_id': request_id
        }), 200
    except pymysql.Error as db_error:
        connection.rollback()
        error_msg = f"Database error: {db_error}"
        print(f"[Admin Users] {error_msg}")
        traceback.print_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'DB_ERROR',
            'request_id': request_id
        }), 500
    finally:
        if 'cursor' in locals():
            cursor.close()

# ==================== 评分管理 ====================

@bp.route('/admin/ratings', methods=['GET'])
@admin_required
def get_all_ratings():
    """获取所有评分"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 50, type=int)
        user_id = request.args.get('user_id', type=int)
        dish_id = request.args.get('dish_id', type=int)
        
        if page < 1:
            page = 1
        if per_page < 1 or per_page > 100:
            per_page = 50
        
        connection = db.get_connection()
        try:
            cursor = connection.cursor(pymysql.cursors.DictCursor)
            
            # 构建查询
            where_conditions = []
            params = []
            
            if user_id:
                where_conditions.append("r.user_id = %s")
                params.append(user_id)
            
            if dish_id:
                where_conditions.append("r.dish_id = %s")
                params.append(dish_id)
            
            where_clause = " WHERE " + " AND ".join(where_conditions) if where_conditions else ""
            
            # 获取总数
            count_query = f"SELECT COUNT(*) as total FROM ratings r{where_clause}"
            cursor.execute(count_query, params)
            total_result = cursor.fetchone()
            total = total_result.get('total') if isinstance(total_result, dict) else total_result[0]
            
            # 获取列表
            query = f"""
                SELECT r.id, r.user_id, r.dish_id, r.rating, r.comment, r.created_at, r.updated_at,
                       u.username, d.name as dish_name
                FROM ratings r
                LEFT JOIN users u ON r.user_id = u.id
                LEFT JOIN dishes d ON r.dish_id = d.id
                {where_clause}
                ORDER BY r.id DESC
                LIMIT %s OFFSET %s
            """
            params.extend([per_page, (page - 1) * per_page])
            
            cursor.execute(query, params)
            ratings = cursor.fetchall()
            
            result = []
            for rating in ratings:
                result.append({
                    'id': rating.get('id'),
                    'user_id': rating.get('user_id'),
                    'username': rating.get('username'),
                    'dish_id': rating.get('dish_id'),
                    'dish_name': rating.get('dish_name'),
                    'rating': float(rating.get('rating', 0)) if rating.get('rating') else 0.0,
                    'comment': rating.get('comment'),
                    'created_at': rating.get('created_at').isoformat() if rating.get('created_at') else None,
                    'updated_at': rating.get('updated_at').isoformat() if rating.get('updated_at') else None
                })
            
            return jsonify({
                'ratings': result,
                'total': total,
                'page': page,
                'per_page': per_page,
                'request_id': request_id
            }), 200
        except Exception as e:
            error_msg = str(e) if str(e) else traceback.format_exc()
            print(f"[Admin Ratings] 错误: {error_msg}")
            traceback.print_exc()
            return jsonify({
                'error': error_msg,
                'error_code': 'DATABASE_ERROR',
                'request_id': request_id
            }), 500
        finally:
            if 'cursor' in locals():
                cursor.close()
    except Exception as e:
        error_msg = str(e) if str(e) else traceback.format_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'UNEXPECTED_ERROR',
            'request_id': request_id
        }), 500

@bp.route('/admin/ratings/<int:rating_id>', methods=['DELETE'])
@admin_required
def delete_rating(rating_id):
    """删除评分"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        
        # 检查评分是否存在
        cursor.execute("SELECT id FROM ratings WHERE id = %s", (rating_id,))
        if not cursor.fetchone():
            return jsonify({
                'error': 'Rating not found',
                'error_code': 'RATING_NOT_FOUND',
                'request_id': request_id
            }), 404
        
        # 删除评分
        cursor.execute("DELETE FROM ratings WHERE id = %s", (rating_id,))
        connection.commit()
        
        return jsonify({
            'message': 'Rating deleted successfully',
            'request_id': request_id
        }), 200
    except pymysql.Error as db_error:
        connection.rollback()
        error_msg = f"Database error: {db_error}"
        print(f"[Admin Ratings] {error_msg}")
        traceback.print_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'DB_ERROR',
            'request_id': request_id
        }), 500
    finally:
        if 'cursor' in locals():
            cursor.close()

# ==================== 统计信息 ====================

@bp.route('/admin/stats', methods=['GET'])
@admin_required
def get_stats():
    """获取统计信息"""
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    connection = db.get_connection()
    try:
        cursor = connection.cursor(pymysql.cursors.DictCursor)
        
        stats = {}
        
        # 用户统计
        cursor.execute("SELECT COUNT(*) as total FROM users")
        user_result = cursor.fetchone()
        stats['total_users'] = user_result.get('total') if isinstance(user_result, dict) else user_result[0]
        
        cursor.execute("SELECT COUNT(*) as total FROM users WHERE is_admin = 1")
        admin_result = cursor.fetchone()
        stats['total_admins'] = admin_result.get('total') if isinstance(admin_result, dict) else admin_result[0]
        
        # 菜品统计
        cursor.execute("SELECT COUNT(DISTINCT name) as total FROM dishes")
        dish_result = cursor.fetchone()
        stats['total_dishes'] = dish_result.get('total') if isinstance(dish_result, dict) else dish_result[0]
        
        # 评分统计
        cursor.execute("SELECT COUNT(*) as total FROM ratings")
        rating_result = cursor.fetchone()
        stats['total_ratings'] = rating_result.get('total') if isinstance(rating_result, dict) else rating_result[0]
        
        cursor.execute("SELECT AVG(rating) as avg FROM ratings")
        avg_result = cursor.fetchone()
        stats['avg_rating'] = float(avg_result.get('avg', 0)) if avg_result.get('avg') else 0.0
        
        # 分类统计
        cursor.execute("SELECT category, COUNT(*) as count FROM dishes GROUP BY category")
        categories = cursor.fetchall()
        stats['categories'] = {}
        for cat in categories:
            if isinstance(cat, dict):
                stats['categories'][cat.get('category', '未知')] = cat.get('count', 0)
            else:
                stats['categories'][cat[0]] = cat[1]
        
        return jsonify({
            'stats': stats,
            'request_id': request_id
        }), 200
    except Exception as e:
        error_msg = str(e) if str(e) else traceback.format_exc()
        print(f"[Admin Stats] 错误: {error_msg}")
        traceback.print_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'DATABASE_ERROR',
            'request_id': request_id
        }), 500
    finally:
        if 'cursor' in locals():
            cursor.close()

