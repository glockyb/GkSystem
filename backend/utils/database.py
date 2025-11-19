import pymysql
import redis
import sys
import os

# 添加项目根目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config import Config

class Database:
    """数据库连接管理类"""
    def __init__(self):
        self.connection = None
        self.redis_client = None
    
    def get_connection(self):
        """获取MySQL连接"""
        if self.connection is None:
            try:
                self.connection = pymysql.connect(
                    host=Config.MYSQL_HOST,
                    port=Config.MYSQL_PORT,
                    user=Config.MYSQL_USER,
                    password=Config.MYSQL_PASSWORD,
                    database=Config.MYSQL_DATABASE,
                    charset='utf8mb4',
                    cursorclass=pymysql.cursors.DictCursor
                )
            except Exception as e:
                print(f"数据库连接失败: {e}")
                raise
        return self.connection
    
    def get_redis(self):
        """获取Redis连接"""
        if self.redis_client is None:
            try:
                self.redis_client = redis.Redis(
                    host=Config.REDIS_HOST,
                    port=Config.REDIS_PORT,
                    db=Config.REDIS_DB,
                    decode_responses=True
                )
                # 测试连接
                self.redis_client.ping()
            except Exception as e:
                print(f"Redis连接失败: {e}")
                raise
        return self.redis_client
    
    def close(self):
        """关闭连接"""
        if self.connection:
            self.connection.close()
            self.connection = None

db = Database()
