"""
Flask应用主文件
提供RESTful API接口
"""
from flask import Flask
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
    
    # 启动应用
    app.run(host='0.0.0.0', port=5000, debug=True)
