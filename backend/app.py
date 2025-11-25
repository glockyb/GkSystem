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
    return jsonify({'error': 'Token has expired'}), 401

@jwt.invalid_token_loader
def invalid_token_callback(error):
    import traceback
    error_msg = str(error) if error else "Unknown error"
    print(f"JWT 无效 token 错误: {error_msg}")
    traceback.print_exc()
    return jsonify({'error': f'Invalid token: {error_msg}'}), 422

@jwt.unauthorized_loader
def missing_token_callback(error):
    return jsonify({'error': 'Authorization header is missing'}), 401

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
