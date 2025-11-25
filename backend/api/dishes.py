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
            
            # 构建查询（使用 GROUP BY 去重，确保每个菜品名称只返回一条记录）
            # 构建 WHERE 条件
            where_conditions = []
            params = []
            count_params = []
            
            if category:
                where_conditions.append("category = %s")
                params.append(category)
                count_params.append(category)
            
            if search:
                where_conditions.append("name LIKE %s")
                search_param = f'%{search}%'
                params.append(search_param)
                count_params.append(search_param)
            
            where_clause = " WHERE " + " AND ".join(where_conditions) if where_conditions else ""
            
            # 获取总数（去重后的唯一名称数量）
            count_query = f"SELECT COUNT(DISTINCT name) FROM dishes{where_clause}"
            
            # 主查询：使用子查询确保每个名称只返回一条记录（取 ID 最小的）
            # 构建外层 WHERE 条件（使用 d1 表别名）
            outer_where_conditions = []
            outer_params = []
            
            if category:
                outer_where_conditions.append("d1.category = %s")
                outer_params.append(category)
            
            if search:
                outer_where_conditions.append("d1.name LIKE %s")
                outer_params.append(f'%{search}%')
            
            outer_where_clause = " WHERE " + " AND ".join(outer_where_conditions) if outer_where_conditions else ""
            
            query = f"""
                SELECT d1.id, d1.name, d1.category, d1.price, d1.description, d1.image_url, d1.nutrition_info
                FROM dishes d1
                INNER JOIN (
                    SELECT name, MIN(id) as min_id
                    FROM dishes
                    {where_clause}
                    GROUP BY name
                ) d2 ON d1.name = d2.name AND d1.id = d2.min_id
                {outer_where_clause}
                ORDER BY d1.id LIMIT %s OFFSET %s
            """
            params = outer_params + [per_page, (page - 1) * per_page]
            
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
            
            # 获取总数（去重后的）
            cursor.execute(count_query, count_params)
            total_count = cursor.fetchone()
            if isinstance(total_count, dict):
                total = total_count.get('COUNT(DISTINCT name)') or 0
            else:
                total = total_count[0] if total_count else 0
            
            print(f"[Dishes API] Request ID: {request_id}, Found {len(result)} dishes (unique: {total})")
            
            # 再次去重（双重保障）- 按名称去重，确保每个名称只出现一次
            seen_names = set()
            unique_result = []
            for dish in result:
                dish_name = dish.get('name', '').strip()
                if dish_name and dish_name not in seen_names:
                    seen_names.add(dish_name)
                    unique_result.append(dish)
                elif not dish_name:
                    # 如果名称为空，按 ID 去重
                    dish_id = dish.get('id')
                    if dish_id and dish_id not in [d.get('id') for d in unique_result]:
                        unique_result.append(dish)
            
            return jsonify({
                'dishes': unique_result,
                'page': page,
                'per_page': per_page,
                'total': total,
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
