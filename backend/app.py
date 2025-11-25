"""
Flask应用主文件
提供RESTful API接口
"""
from flask import Flask, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager
import sys
import os

# 添加项目根目录到路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import Config
from api import auth, dishes, recommendations, ratings

app = Flask(__name__)
app.config.from_object(Config)

# 启用CORS
CORS(app, resources={r"/api/*": {"origins": "*"}})

# JWT配置
jwt = JWTManager(app)

# JWT 错误处理
@jwt.expired_token_loader
def expired_token_callback(jwt_header, jwt_payload):
    """Token 过期处理"""
    import traceback
    print(f"[JWT] Token expired - Header: {jwt_header}, Payload: {jwt_payload}")
    traceback.print_exc()
    return jsonify({
        'error': 'Token has expired',
        'error_code': 'TOKEN_EXPIRED',
        'message': 'Please login again'
    }), 401

@jwt.invalid_token_loader
def invalid_token_callback(error):
    """无效 Token 处理"""
    from flask import request
    import traceback
    
    error_msg = str(error) if error else "Unknown error"
    
    # 获取请求信息用于调试
    auth_header = request.headers.get('Authorization', 'Not provided')
    request_id = request.headers.get('X-Request-ID', 'Not provided')
    
    print(f"[JWT] Invalid token error:")
    print(f"  - Error: {error_msg}")
    print(f"  - Authorization Header: {auth_header[:50]}..." if len(auth_header) > 50 else f"  - Authorization Header: {auth_header}")
    print(f"  - Request ID: {request_id}")
    print(f"  - URL: {request.url}")
    print(f"  - Method: {request.method}")
    print(f"  - All Headers: {dict(request.headers)}")
    traceback.print_exc()
    
    # 检查是否是 Bearer token 格式问题
    if auth_header and not auth_header.startswith('Bearer '):
        error_msg = f"Invalid Authorization header format. Expected 'Bearer <token>', got: {auth_header[:20]}..."
    
    return jsonify({
        'error': f'Invalid token: {error_msg}',
        'error_code': 'INVALID_TOKEN',
        'message': 'Please login again',
        'request_id': request_id
    }), 422

@jwt.unauthorized_loader
def missing_token_callback(error):
    """缺少 Token 处理"""
    from flask import request
    
    request_id = request.headers.get('X-Request-ID', 'Not provided')
    auth_header = request.headers.get('Authorization', 'Not provided')
    
    print(f"[JWT] Missing token:")
    print(f"  - Request ID: {request_id}")
    print(f"  - URL: {request.url}")
    print(f"  - Method: {request.method}")
    print(f"  - Authorization Header: {auth_header}")
    
    return jsonify({
        'error': 'Authorization header is missing',
        'error_code': 'MISSING_TOKEN',
        'message': 'Please provide a valid token in Authorization header',
        'request_id': request_id
    }), 401

# 添加请求前处理，记录请求信息
@app.before_request
def log_request_info():
    """记录请求信息用于调试"""
    from flask import request
    import logging
    
    # 只在需要认证的路由上记录详细信息
    if request.path.startswith('/api/v1'):
        request_id = request.headers.get('X-Request-ID', 'N/A')
        auth_header = request.headers.get('Authorization', 'Not provided')
        
        # 只记录前 50 个字符的 token，避免日志过长
        if auth_header and len(auth_header) > 50:
            auth_display = auth_header[:50] + "..."
        else:
            auth_display = auth_header
        
        logging.info(f"[Request] {request.method} {request.path} - Request ID: {request_id} - Auth: {auth_display}")

# 注册蓝图
app.register_blueprint(auth.bp, url_prefix=Config.API_PREFIX)
app.register_blueprint(dishes.bp, url_prefix=Config.API_PREFIX)
app.register_blueprint(recommendations.bp, url_prefix=Config.API_PREFIX)
app.register_blueprint(ratings.bp, url_prefix=Config.API_PREFIX)

@app.route('/')
def index():
    return {'message': 'Canteen Recommendation System API', 'version': '1.0.0'}

@app.route('/health')
def health():
    return {'status': 'healthy'}

if __name__ == '__main__':
    # 确保模型目录存在
    os.makedirs('models', exist_ok=True)
    
    # 获取运行模式
    debug_mode = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    
    # 启动应用
    # 生产环境：host='127.0.0.1'（只允许本地访问，通过 Nginx 代理）
    # 开发环境：host='0.0.0.0'（允许外部访问）
    host = os.environ.get('FLASK_HOST', '127.0.0.1' if not debug_mode else '0.0.0.0')
    port = int(os.environ.get('FLASK_PORT', 5000))
    
    app.run(host=host, port=port, debug=debug_mode)
