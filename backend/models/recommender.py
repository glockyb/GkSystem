"""
推荐算法模块
实现协同过滤、内容推荐和混合推荐算法
"""
import numpy as np
import pandas as pd
from surprise import SVD, Dataset, Reader
from surprise.model_selection import train_test_split
from sklearn.neighbors import NearestNeighbors
import pymysql
import json
import sys
import os

# 添加项目根目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import joblib
from config import Config
from utils.database import db

# 确保models目录存在
os.makedirs('models', exist_ok=True)

class CollaborativeFiltering:
    """协同过滤推荐算法"""
    
    def __init__(self):
        self.model = None
        self.trainset = None
        self.model_path = 'models/cf_model.pkl'
        
    def load_ratings(self):
        """加载评分数据"""
        connection = db.get_connection()
        try:
            query = """
                SELECT user_id, dish_id, rating
                FROM ratings
                WHERE rating IS NOT NULL
                UNION
                SELECT user_id, dish_id, rating
                FROM consumption_records
                WHERE rating IS NOT NULL
            """
            df = pd.read_sql(query, connection)
            return df
        except Exception as e:
            print(f"加载评分数据失败: {e}")
            return pd.DataFrame()
    
    def train(self):
        """训练模型"""
        print("Training collaborative filtering model...")
        ratings_df = self.load_ratings()
        
        if len(ratings_df) == 0:
            print("No ratings data available, skipping CF training")
            return
        
        try:
            # 使用Surprise库进行矩阵分解
            reader = Reader(rating_scale=(1, 5))
            data = Dataset.load_from_df(ratings_df[['user_id', 'dish_id', 'rating']], reader)
            
            trainset, testset = train_test_split(data, test_size=0.2)
            self.trainset = trainset
            
            # SVD模型
            self.model = SVD(
                n_factors=Config.LATENT_FACTORS,
                lr_all=Config.LEARNING_RATE,
                n_epochs=Config.ITERATIONS,
                verbose=False
            )
            
            self.model.fit(trainset)
            
            # 保存模型
            joblib.dump(self.model, self.model_path)
            print("Collaborative filtering model trained and saved")
        except Exception as e:
            print(f"训练协同过滤模型失败: {e}")
    
    def predict(self, user_id, dish_id):
        """预测用户对菜品的评分"""
        if self.model is None:
            self.load_model()
        
        if self.model is None:
            return 3.0  # 默认评分
        
        try:
            prediction = self.model.predict(user_id, dish_id)
            return prediction.est
        except:
            return 3.0
    
    def recommend(self, user_id, n=10):
        """为用户推荐菜品"""
        # 确保 user_id 是整数
        try:
            user_id = int(user_id)
        except (ValueError, TypeError):
            print(f"无效的用户ID: {user_id}")
            return []
        
        if self.model is None:
            self.load_model()
        
        if self.model is None:
            return []
        
        connection = db.get_connection()
        try:
            # 获取所有菜品
            cursor = connection.cursor()
            cursor.execute("SELECT id FROM dishes")
            rows = cursor.fetchall()
            # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
            if rows and isinstance(rows[0], dict):
                all_dishes = [row.get('id') for row in rows if row.get('id')]
            else:
                all_dishes = [row[0] for row in rows if row[0]]
            
            if not all_dishes:
                return []
            
            # 获取用户已评价的菜品
            cursor.execute("""
                SELECT dish_id FROM ratings WHERE user_id = %s
                UNION
                SELECT dish_id FROM consumption_records WHERE user_id = %s
            """, (user_id, user_id))
            rated_rows = cursor.fetchall()
            # 处理 DictCursor
            if rated_rows and isinstance(rated_rows[0], dict):
                rated_dishes = {row.get('dish_id') for row in rated_rows}
            else:
                rated_dishes = {row[0] for row in rated_rows}
            
            # 预测未评价菜品的评分
            predictions = []
            for dish_id in all_dishes:
                if dish_id not in rated_dishes:
                    score = self.predict(user_id, dish_id)
                    predictions.append((dish_id, score))
            
            # 按评分排序
            predictions.sort(key=lambda x: x[1], reverse=True)
            return [dish_id for dish_id, score in predictions[:n]]
        except Exception as e:
            print(f"推荐失败: {e}")
            return []
        finally:
            cursor.close()
    
    def load_model(self):
        """加载已保存的模型"""
        try:
            if os.path.exists(self.model_path):
                self.model = joblib.load(self.model_path)
            else:
                print("Model file not found")
        except Exception as e:
            print(f"加载模型失败: {e}")

class ContentBasedRecommender:
    """基于内容的推荐算法"""
    
    def __init__(self):
        self.knn_model = None
        self.dish_features = None
        self.dish_ids = None
        self.model_path = 'models/cb_model.pkl'
        
    def load_features(self):
        """加载菜品特征"""
        connection = db.get_connection()
        try:
            query = """
                SELECT df.dish_id, df.pca_vector
                FROM dish_features df
            """
            cursor = connection.cursor()
            cursor.execute(query)
            
            features_dict = {}
            for row in cursor.fetchall():
                dish_id = row[0]
                pca_vector = json.loads(row[1])
                features_dict[dish_id] = np.array(pca_vector)
            
            return features_dict
        except Exception as e:
            print(f"加载特征失败: {e}")
            return {}
        finally:
            cursor.close()
    
    def train(self):
        """训练KNN模型"""
        print("Training content-based recommender...")
        self.dish_features = self.load_features()
        
        if len(self.dish_features) == 0:
            print("No features data available, skipping CB training")
            return
        
        try:
            # 准备数据
            dish_ids = list(self.dish_features.keys())
            feature_matrix = np.array([self.dish_features[did] for did in dish_ids])
            
            # 训练KNN模型
            self.knn_model = NearestNeighbors(
                n_neighbors=min(Config.K_NEIGHBORS + 1, len(dish_ids)),
                metric='cosine'
            )
            self.knn_model.fit(feature_matrix)
            
            # 保存模型和映射
            joblib.dump({
                'model': self.knn_model,
                'dish_ids': dish_ids,
                'features': self.dish_features
            }, self.model_path)
            self.dish_ids = dish_ids
            print("Content-based model trained and saved")
        except Exception as e:
            print(f"训练内容推荐模型失败: {e}")
    
    def recommend(self, dish_ids, n=10):
        """基于相似菜品推荐"""
        if self.knn_model is None:
            self.load_model()
        
        if self.knn_model is None or len(dish_ids) == 0:
            return []
        
        try:
            # 获取用户喜欢的菜品特征
            user_features = []
            valid_dish_ids = []
            for did in dish_ids:
                if did in self.dish_features:
                    user_features.append(self.dish_features[did])
                    valid_dish_ids.append(did)
            
            if len(user_features) == 0:
                return []
            
            # 计算平均特征
            avg_features = np.mean(user_features, axis=0).reshape(1, -1)
            
            # 找到相似菜品
            n_neighbors = min(n + len(valid_dish_ids), len(self.dish_ids))
            distances, indices = self.knn_model.kneighbors(avg_features, n_neighbors=n_neighbors)
            
            # 获取推荐菜品ID
            recommended = []
            for idx in indices[0]:
                dish_id = self.dish_ids[idx]
                if dish_id not in valid_dish_ids:
                    recommended.append(dish_id)
                if len(recommended) >= n:
                    break
            
            return recommended
        except Exception as e:
            print(f"内容推荐失败: {e}")
            return []
    
    def load_model(self):
        """加载已保存的模型"""
        try:
            if os.path.exists(self.model_path):
                data = joblib.load(self.model_path)
                self.knn_model = data['model']
                self.dish_ids = data['dish_ids']
                self.dish_features = data['features']
            else:
                print("Model file not found")
        except Exception as e:
            print(f"加载模型失败: {e}")

class HybridRecommender:
    """混合推荐算法"""
    
    def __init__(self):
        self.cf_recommender = CollaborativeFiltering()
        self.cb_recommender = ContentBasedRecommender()
        self.cf_weight = 0.6  # 协同过滤权重
        self.cb_weight = 0.4  # 内容推荐权重
    
    def train(self):
        """训练所有模型"""
        self.cf_recommender.train()
        self.cb_recommender.train()
    
    def recommend(self, user_id, n=10):
        """混合推荐"""
        # 确保 user_id 是整数
        try:
            user_id = int(user_id)
        except (ValueError, TypeError):
            print(f"无效的用户ID: {user_id}")
            return self.get_popular_dishes(n)
        
        # 协同过滤推荐
        cf_recommendations = self.cf_recommender.recommend(user_id, n)
        
        # 获取用户历史记录
        connection = db.get_connection()
        try:
            cursor = connection.cursor()
            cursor.execute("""
                SELECT dish_id FROM ratings WHERE user_id = %s AND rating >= 4
                UNION
                SELECT dish_id FROM consumption_records WHERE user_id = %s AND rating >= 4
            """, (user_id, user_id))
            rows = cursor.fetchall()
            # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
            if rows:
                if isinstance(rows[0], dict):
                    user_dishes = [row.get('dish_id') for row in rows if row.get('dish_id')]
                else:
                    user_dishes = [row[0] for row in rows if row[0]]
            else:
                user_dishes = []
            
            # 内容推荐
            cb_recommendations = self.cb_recommender.recommend(user_dishes, n) if user_dishes else []
        except Exception as e:
            print(f"获取用户历史失败: {e}")
            user_dishes = []
            cb_recommendations = []
        finally:
            cursor.close()
        
        # 合并推荐结果
        recommendations = {}
        
        # 添加协同过滤结果
        for i, dish_id in enumerate(cf_recommendations):
            score = self.cf_weight * (len(cf_recommendations) - i) / max(len(cf_recommendations), 1)
            recommendations[dish_id] = recommendations.get(dish_id, 0) + score
        
        # 添加内容推荐结果
        for i, dish_id in enumerate(cb_recommendations):
            score = self.cb_weight * (len(cb_recommendations) - i) / max(len(cb_recommendations), 1)
            recommendations[dish_id] = recommendations.get(dish_id, 0) + score
        
        # 如果混合推荐为空，使用协同过滤或内容推荐
        if not recommendations:
            if cf_recommendations:
                return cf_recommendations[:n]
            elif cb_recommendations:
                return cb_recommendations[:n]
            else:
                # 返回热门菜品
                return self.get_popular_dishes(n)
        
        # 按分数排序
        sorted_recommendations = sorted(recommendations.items(), key=lambda x: x[1], reverse=True)
        return [dish_id for dish_id, score in sorted_recommendations[:n]]
    
    def get_popular_dishes(self, n=10):
        """获取热门菜品"""
        connection = db.get_connection()
        try:
            cursor = connection.cursor()
            cursor.execute("""
                SELECT dish_id, COUNT(*) as count
                FROM ratings
                GROUP BY dish_id
                ORDER BY count DESC
                LIMIT %s
            """, (n,))
            rows = cursor.fetchall()
            # 处理 DictCursor（返回字典）或普通 cursor（返回元组）
            if rows and isinstance(rows[0], dict):
                return [row.get('dish_id') for row in rows]
            else:
                return [row[0] for row in rows]
        except Exception as e:
            print(f"获取热门菜品失败: {e}")
            # 如果失败，返回所有菜品
            try:
                cursor.execute("SELECT id FROM dishes LIMIT %s", (n,))
                rows = cursor.fetchall()
                if rows and isinstance(rows[0], dict):
                    return [row.get('id') for row in rows]
                else:
                    return [row[0] for row in rows]
            except:
                return []
        finally:
            cursor.close()

# 全局推荐器实例
recommender = HybridRecommender()
