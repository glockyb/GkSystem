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
        
        # JWT identity 必须是字符串
        access_token = create_access_token(identity=str(user_id))
        
        return jsonify({
            'message': 'Login successful',
            'access_token': access_token,
            'user_id': user_id
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
    
    connection = db.get_connection()
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT id, username, email, created_at FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
        if isinstance(user, dict):
            return jsonify({
                'id': user.get('id'),
                'username': user.get('username'),
                'email': user.get('email'),
                'created_at': user.get('created_at').isoformat() if user.get('created_at') else None
            }), 200
        else:
            return jsonify({
                'id': user[0],
                'username': user[1],
                'email': user[2],
                'created_at': user[3].isoformat() if user[3] else None
            }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
