"""
用户认证API
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
import bcrypt
import pymysql
from utils.database import db

bp = Blueprint('auth', __name__)

@bp.route('/register', methods=['POST'])
def register():
    """用户注册"""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    email = data.get('email')
    
    if not username or not password:
        return jsonify({'error': 'Username and password are required'}), 400
    
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        
        # 检查用户名是否已存在
        cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
        if cursor.fetchone():
            return jsonify({'error': 'Username already exists'}), 400
        
        # 加密密码
        password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        
        # 插入新用户
        cursor.execute(
            "INSERT INTO users (username, password_hash, email) VALUES (%s, %s, %s)",
            (username, password_hash, email)
        )
        connection.commit()
        
        user_id = cursor.lastrowid
        # JWT identity 必须是字符串
        access_token = create_access_token(identity=str(user_id))
        
        return jsonify({
            'message': 'User registered successfully',
            'access_token': access_token,
            'user_id': user_id
        }), 201
    except Exception as e:
        connection.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()

@bp.route('/login', methods=['POST'])
def login():
    """用户登录"""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({'error': 'Username and password are required'}), 400
    
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT id, password_hash FROM users WHERE username = %s", (username,))
        user = cursor.fetchone()
        
        if not user:
            return jsonify({'error': 'Invalid credentials'}), 401
        
        # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
        if isinstance(user, dict):
            user_id = user.get('id')
            password_hash = user.get('password_hash')
        else:
            user_id, password_hash = user
        
        # 验证密码
        if not password_hash:
            return jsonify({'error': 'Invalid credentials'}), 401
        
        # 确保 password_hash 是字符串
        if isinstance(password_hash, bytes):
            password_hash = password_hash.decode('utf-8')
        
        if not bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8')):
            return jsonify({'error': 'Invalid credentials'}), 401
        
        # 获取用户角色信息
        cursor.execute("SELECT role, is_admin FROM users WHERE id = %s", (user_id,))
        user_info = cursor.fetchone()
        
        if isinstance(user_info, dict):
            role = user_info.get('role', 'user')
            is_admin = bool(user_info.get('is_admin', 0))
        else:
            role = user_info[0] if user_info else 'user'
            is_admin = bool(user_info[1] if len(user_info) > 1 else 0)
        
        # JWT identity 必须是字符串
        access_token = create_access_token(identity=str(user_id))
        
        return jsonify({
            'message': 'Login successful',
            'access_token': access_token,
            'user_id': user_id,
            'username': username,
            'role': role,
            'is_admin': is_admin
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()

@bp.route('/profile', methods=['GET'])
@jwt_required()
def get_profile():
    """获取用户信息"""
    user_id = get_jwt_identity()
    
    # JWT identity 返回的是字符串，需要转换为整数用于数据库查询
    try:
        user_id = int(user_id) if isinstance(user_id, str) else user_id
    except (ValueError, TypeError):
        return jsonify({'error': 'Invalid user ID format'}), 400
    
    connection = None
    cursor = None
    request_id = request.headers.get('X-Request-ID', 'N/A')
    
    try:
        connection = db.get_connection()
        if not connection:
            raise Exception("无法获取数据库连接")
        
        # database.py 已经设置了 DictCursor，直接使用即可
        cursor = connection.cursor()
        
        # 先尝试查询包含 role 和 is_admin 的完整字段
        query_success = False
        user = None
        
        try:
            cursor.execute("SELECT id, username, email, role, is_admin, created_at FROM users WHERE id = %s", (user_id,))
            user = cursor.fetchone()
            query_success = True
        except pymysql.Error as e:
            error_str = str(e)
            # 如果字段不存在，使用基本查询
            if 'Unknown column' in error_str or 'role' in error_str or 'is_admin' in error_str:
                print(f"[Profile API] role/is_admin 字段不存在，使用基本查询")
                try:
                    cursor.execute("SELECT id, username, email, created_at FROM users WHERE id = %s", (user_id,))
                    user = cursor.fetchone()
                    query_success = True
                except Exception as e2:
                    print(f"[Profile API] 基本查询也失败: {e2}")
                    raise
            else:
                print(f"[Profile API] 数据库查询错误: {error_str}")
                raise
        
        if not user:
            return jsonify({
                'error': 'User not found',
                'error_code': 'USER_NOT_FOUND',
                'request_id': request_id
            }), 404
        
        # 处理 DictCursor（返回字典）- database.py 默认使用 DictCursor
        if isinstance(user, dict):
            user_data = {
                'id': user.get('id'),
                'username': user.get('username') or '',
                'email': user.get('email') or '',
                'created_at': user.get('created_at').isoformat() if user.get('created_at') else None
            }
            
            # 如果字段存在，添加角色信息
            if 'role' in user:
                user_data['role'] = user.get('role') or 'user'
            else:
                user_data['role'] = 'user'
            
            if 'is_admin' in user:
                is_admin_val = user.get('is_admin')
                # 处理不同的布尔值表示方式
                if isinstance(is_admin_val, bool):
                    user_data['is_admin'] = is_admin_val
                elif isinstance(is_admin_val, (int, str)):
                    user_data['is_admin'] = bool(int(is_admin_val))
                else:
                    user_data['is_admin'] = False
            else:
                user_data['is_admin'] = False
            
            return jsonify(user_data), 200
        else:
            # 处理普通 cursor（返回元组）- 兼容旧代码
            user_data = {
                'id': user[0] if len(user) > 0 else None,
                'username': user[1] if len(user) > 1 else '',
                'email': user[2] if len(user) > 2 else '',
                'role': 'user',
                'is_admin': False,
                'created_at': user[3].isoformat() if len(user) > 3 and user[3] else None
            }
            
            # 如果返回了更多字段，尝试获取角色信息
            if len(user) > 4:
                user_data['role'] = user[3] if user[3] else 'user'
                user_data['is_admin'] = bool(int(user[4])) if len(user) > 4 and user[4] is not None else False
                if len(user) > 5:
                    user_data['created_at'] = user[5].isoformat() if user[5] else None
            
            return jsonify(user_data), 200
            
    except pymysql.Error as db_error:
        import traceback
        error_msg = f"Database error: {str(db_error)}"
        print(f"[Profile API] 数据库错误: {error_msg}")
        traceback.print_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'DATABASE_ERROR',
            'request_id': request_id
        }), 500
    except Exception as e:
        import traceback
        error_msg = str(e) if str(e) else traceback.format_exc()
        print(f"[Profile API] 未知错误: {error_msg}")
        traceback.print_exc()
        return jsonify({
            'error': error_msg,
            'error_code': 'PROFILE_ERROR',
            'request_id': request_id
        }), 500
    finally:
        if cursor:
            try:
                cursor.close()
            except:
                pass
        # 注意：不要关闭 connection，因为 db.get_connection() 可能使用连接池
