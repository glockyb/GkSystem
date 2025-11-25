"""
数据预处理模块
实现数据清洗、特征工程、TF-IDF向量化、PCA降维等功能
"""
import pandas as pd
import numpy as np
from sklearn.preprocessing import MinMaxScaler
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.decomposition import PCA
import pymysql
import sys
import os

# 添加项目根目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config import Config
from utils.database import db
import json

class DataPreprocessor:
    """数据预处理器"""
    
    def __init__(self):
        self.scaler = MinMaxScaler()
        self.tfidf_vectorizer = TfidfVectorizer(max_features=128)
        self.pca = PCA(n_components=32)
        
    def load_data(self):
        """从数据库加载数据"""
        connection = db.get_connection()
        try:
            # 加载消费记录
            consumption_query = """
                SELECT cr.user_id, cr.dish_id, cr.rating, cr.consumption_time,
                       d.name, d.category, d.price, d.description
                FROM consumption_records cr
                JOIN dishes d ON cr.dish_id = d.id
                WHERE cr.rating IS NOT NULL
            """
            consumption_df = pd.read_sql(consumption_query, connection)
            
            # 加载评分数据
            ratings_query = """
                SELECT user_id, dish_id, rating, created_at
                FROM ratings
            """
            ratings_df = pd.read_sql(ratings_query, connection)
            
            # 加载菜品数据
            dishes_query = """
                SELECT id, name, category, price, description
                FROM dishes
            """
            dishes_df = pd.read_sql(dishes_query, connection)
            
            # 确保价格列是数值类型
            if not dishes_df.empty and 'price' in dishes_df.columns:
                dishes_df['price'] = pd.to_numeric(dishes_df['price'], errors='coerce').fillna(10.0)
            
            return consumption_df, ratings_df, dishes_df
        except Exception as e:
            print(f"加载数据失败: {e}")
            # 如果没有数据，返回空DataFrame
            return pd.DataFrame(), pd.DataFrame(), pd.DataFrame()
    
    def clean_data(self, df):
        """数据清洗"""
        if df.empty:
            return df
        
        # 处理缺失值
        numeric_cols = df.select_dtypes(include=[np.number]).columns
        for col in numeric_cols:
            if col in df.columns:
                df[col].fillna(df[col].mean(), inplace=True)
        
        # 使用3σ原则剔除异常值
        for col in numeric_cols:
            if col in df.columns:
                mean = df[col].mean()
                std = df[col].std()
                if std > 0:
                    df = df[(df[col] >= mean - 3*std) & (df[col] <= mean + 3*std)]
        
        return df
    
    def extract_features(self, dishes_df, ratings_df):
        """特征工程 - 提取12个特征变量"""
        if dishes_df.empty:
            return pd.DataFrame()
        
        features = []
        
        for _, dish in dishes_df.iterrows():
            dish_id = dish['id']
            
            # 获取该菜品的评分
            if not ratings_df.empty:
                dish_ratings = ratings_df[ratings_df['dish_id'] == dish_id]
                avg_rating = dish_ratings['rating'].mean() if len(dish_ratings) > 0 else 3.0
                total_ratings = len(dish_ratings)
            else:
                avg_rating = 3.0
                total_ratings = 0
            
            # 特征1: 菜品类别编码
            category_map = {'荤菜': 1, '素菜': 0, '汤类': 2, '主食': 3}
            category_encoded = category_map.get(dish.get('category', ''), 0)
            
            # 特征2: 价格区间（确保价格是数值类型）
            try:
                price = float(dish.get('price', 10.0)) if dish.get('price') is not None else 10.0
            except (ValueError, TypeError):
                price = 10.0
            
            if price < 8:
                price_range = 0
            elif price < 12:
                price_range = 1
            elif price < 15:
                price_range = 2
            else:
                price_range = 3
            
            feature_dict = {
                'dish_id': dish_id,
                'category_encoded': category_encoded,
                'price_range': price_range,
                'price': float(price),
                'avg_rating': float(avg_rating),
                'total_ratings': int(total_ratings),
                'name': dish.get('name', ''),
                'description': dish.get('description', '') or ''
            }
            features.append(feature_dict)
        
        return pd.DataFrame(features)
    
    def tfidf_vectorize(self, texts):
        """TF-IDF向量化"""
        # 处理空值
        texts = [str(text) if pd.notna(text) else '' for text in texts]
        if not texts or all(not t for t in texts):
            # 如果所有文本都为空，返回零矩阵
            return np.zeros((len(texts), 128))
        tfidf_matrix = self.tfidf_vectorizer.fit_transform(texts)
        return tfidf_matrix.toarray()
    
    def normalize_features(self, feature_df):
        """特征归一化"""
        if feature_df.empty:
            return feature_df
        
        numeric_cols = ['price', 'avg_rating', 'total_ratings']
        existing_cols = [col for col in numeric_cols if col in feature_df.columns]
        if existing_cols:
            feature_df[existing_cols] = self.scaler.fit_transform(feature_df[existing_cols])
        return feature_df
    
    def pca_transform(self, feature_matrix):
        """PCA降维到32维"""
        if feature_matrix.shape[0] == 0:
            return feature_matrix
        pca_result = self.pca.fit_transform(feature_matrix)
        return pca_result
    
    def process_all(self):
        """完整的数据预处理流程"""
        print("Loading data...")
        consumption_df, ratings_df, dishes_df = self.load_data()
        
        if dishes_df.empty:
            print("警告: 没有菜品数据，跳过预处理")
            return pd.DataFrame(), np.array([])
        
        print("Cleaning data...")
        if not consumption_df.empty:
            consumption_df = self.clean_data(consumption_df)
        if not ratings_df.empty:
            ratings_df = self.clean_data(ratings_df)
        
        print("Extracting features...")
        feature_df = self.extract_features(dishes_df, ratings_df)
        
        if feature_df.empty:
            print("警告: 特征提取失败")
            return pd.DataFrame(), np.array([])
        
        print("TF-IDF vectorization...")
        # 结合名称和描述进行TF-IDF
        texts = feature_df['name'] + ' ' + feature_df['description']
        tfidf_vectors = self.tfidf_vectorize(texts)
        
        print("Normalizing features...")
        feature_df = self.normalize_features(feature_df)
        
        # 组合特征
        numeric_features = feature_df[['category_encoded', 'price_range', 'price', 'avg_rating', 'total_ratings']].values
        combined_features = np.hstack([numeric_features, tfidf_vectors])
        
        print("PCA transformation...")
        pca_features = self.pca_transform(combined_features)
        
        # 保存特征到数据库
        self.save_features_to_db(feature_df, pca_features)
        
        print("Data preprocessing completed!")
        return feature_df, pca_features
    
    def save_features_to_db(self, feature_df, pca_features):
        """保存特征到数据库"""
        if feature_df.empty or pca_features.shape[0] == 0:
            return
        
        connection = db.get_connection()
        try:
            cursor = connection.cursor()
            for idx, row in feature_df.iterrows():
                dish_id = row['dish_id']
                pca_vector = pca_features[idx].tolist()
                feature_vector = {
                    'category_encoded': int(row['category_encoded']),
                    'price_range': int(row['price_range']),
                    'price': float(row['price']),
                    'avg_rating': float(row['avg_rating']),
                    'total_ratings': int(row['total_ratings'])
                }
                
                # 更新或插入特征
                sql = """
                    INSERT INTO dish_features 
                    (dish_id, feature_vector, pca_vector, category_encoded, price_range, avg_rating, total_ratings)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE
                    feature_vector = VALUES(feature_vector),
                    pca_vector = VALUES(pca_vector),
                    category_encoded = VALUES(category_encoded),
                    price_range = VALUES(price_range),
                    avg_rating = VALUES(avg_rating),
                    total_ratings = VALUES(total_ratings)
                """
                cursor.execute(sql, (
                    dish_id,
                    json.dumps(feature_vector),
                    json.dumps(pca_vector),
                    int(row['category_encoded']),
                    int(row['price_range']),
                    float(row['avg_rating']),
                    int(row['total_ratings'])
                ))
            connection.commit()
            print(f"成功保存 {len(feature_df)} 条特征数据")
        except Exception as e:
            connection.rollback()
            print(f"保存特征失败: {e}")
        finally:
            cursor.close()

if __name__ == '__main__':
    preprocessor = DataPreprocessor()
    preprocessor.process_all()
