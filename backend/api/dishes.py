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
        
        connection = None
        cursor = None
        try:
            print(f"[Dishes API] Request ID: {request_id}, 获取数据库连接...")
            connection = db.get_connection()
            if not connection:
                raise Exception("无法获取数据库连接")
            print(f"[Dishes API] Request ID: {request_id}, 数据库连接成功")
            
            cursor = connection.cursor()
            print(f"[Dishes API] Request ID: {request_id}, 创建游标成功")
            
            # 构建查询（使用 DISTINCT 去重）
            query = "SELECT DISTINCT id, name, category, price, description, image_url, nutrition_info FROM dishes WHERE 1=1"
            params = []
            
            if category:
                query += " AND category = %s"
                params.append(category)
            
            if search:
                query += " AND name LIKE %s"
                params.append(f'%{search}%')
            
            query += " ORDER BY id LIMIT %s OFFSET %s"
            params.extend([per_page, (page - 1) * per_page])
            
            print(f"[Dishes API] Request ID: {request_id}, 执行查询: {query[:100]}...")
            cursor.execute(query, params)
            dishes = cursor.fetchall()
            print(f"[Dishes API] Request ID: {request_id}, 查询返回 {len(dishes) if dishes else 0} 条记录")
            
            # 转换为字典列表
            result = []
            for idx, dish in enumerate(dishes):
                try:
                    # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
                    if isinstance(dish, dict):
                        dish_data = {
                            'id': dish.get('id'),
                            'name': dish.get('name') or '',
                            'category': dish.get('category') or '',
                            'price': float(dish.get('price', 0)) if dish.get('price') is not None else 0.0,
                            'description': dish.get('description') or '',
                            'image_url': dish.get('image_url') or '',
                            'nutrition_info': dish.get('nutrition_info')
                        }
                    else:
                        dish_data = {
                            'id': dish[0] if len(dish) > 0 else None,
                            'name': dish[1] if len(dish) > 1 else '',
                            'category': dish[2] if len(dish) > 2 else '',
                            'price': float(dish[3]) if len(dish) > 3 and dish[3] is not None else 0.0,
                            'description': dish[4] if len(dish) > 4 else '',
                            'image_url': dish[5] if len(dish) > 5 else '',
                            'nutrition_info': dish[6] if len(dish) > 6 else None
                        }
                    result.append(dish_data)
                except Exception as e:
                    print(f"[Dishes API] Request ID: {request_id}, 处理第 {idx} 条记录时出错: {e}")
                    import traceback
                    traceback.print_exc()
                    # 跳过这条记录，继续处理下一条
                    continue
            
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
            if cursor:
                cursor.close()
            # 注意：不要关闭 connection，因为 db.get_connection() 可能使用连接池
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
    
    connection = None
    cursor = None
    try:
        print(f"[Dishes API] Request ID: {request_id}, 开始获取分类...")
        
        connection = db.get_connection()
        if not connection:
            raise Exception("无法获取数据库连接")
        
        print(f"[Dishes API] Request ID: {request_id}, 数据库连接成功")
        
        cursor = connection.cursor()
        print(f"[Dishes API] Request ID: {request_id}, 执行查询...")
        
        cursor.execute("SELECT DISTINCT category FROM dishes WHERE category IS NOT NULL")
        rows = cursor.fetchall()
        
        print(f"[Dishes API] Request ID: {request_id}, 查询返回 {len(rows) if rows else 0} 行")
        
        # 处理空结果
        if not rows:
            print(f"[Dishes API] Request ID: {request_id}, 未找到分类，返回空列表")
            return jsonify({
                'categories': [],
                'count': 0,
                'request_id': request_id
            }), 200
        
        # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
        categories = []
        if isinstance(rows[0], dict):
            categories = [row.get('category') for row in rows if row.get('category') is not None]
        else:
            categories = [row[0] for row in rows if row[0] is not None]
        
        # 去重并排序
        categories = sorted(list(set(categories)))
        
        print(f"[Dishes API] Request ID: {request_id}, 找到 {len(categories)} 个唯一分类: {categories[:5]}...")
        
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
        if cursor:
            try:
                cursor.close()
            except:
                pass
        # 注意：不要关闭 connection，因为 db.get_connection() 可能使用连接池
