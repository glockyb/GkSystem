-- 创建数据库
CREATE DATABASE IF NOT EXISTS canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE canteen_recommendation;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 菜品表
CREATE TABLE IF NOT EXISTS dishes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10, 2),
    description TEXT,
    image_url VARCHAR(255),
    nutrition_info JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户消费记录表
CREATE TABLE IF NOT EXISTS consumption_records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    dish_id INT NOT NULL,
    consumption_time TIMESTAMP NOT NULL,
    price DECIMAL(10, 2),
    rating INT CHECK (rating >= 1 AND rating <= 5),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (dish_id) REFERENCES dishes(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_dish_id (dish_id),
    INDEX idx_consumption_time (consumption_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户评分表
CREATE TABLE IF NOT EXISTS ratings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    dish_id INT NOT NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (dish_id) REFERENCES dishes(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_dish (user_id, dish_id),
    INDEX idx_user_id (user_id),
    INDEX idx_dish_id (dish_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户收藏表
CREATE TABLE IF NOT EXISTS favorites (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    dish_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (dish_id) REFERENCES dishes(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_favorite (user_id, dish_id),
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 菜品特征表
CREATE TABLE IF NOT EXISTS dish_features (
    id INT AUTO_INCREMENT PRIMARY KEY,
    dish_id INT NOT NULL,
    feature_vector JSON,
    pca_vector JSON,
    category_encoded INT,
    price_range INT,
    avg_rating DECIMAL(3, 2),
    total_ratings INT DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (dish_id) REFERENCES dishes(id) ON DELETE CASCADE,
    UNIQUE KEY unique_dish_feature (dish_id),
    INDEX idx_dish_id (dish_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 插入示例数据
INSERT INTO dishes (name, category, price, description, image_url) VALUES
('红烧肉', '荤菜', 12.00, '经典红烧肉，肥而不腻', '/images/hongshaorou.jpg'),
('麻婆豆腐', '素菜', 8.00, '川味麻婆豆腐，麻辣鲜香', '/images/mapodoufu.jpg'),
('西红柿鸡蛋', '素菜', 10.00, '家常西红柿炒鸡蛋', '/images/xihongshijidan.jpg'),
('宫保鸡丁', '荤菜', 15.00, '经典川菜宫保鸡丁', '/images/gongbaojiding.jpg'),
('糖醋里脊', '荤菜', 14.00, '酸甜可口的糖醋里脊', '/images/tangculiji.jpg'),
('地三鲜', '素菜', 9.00, '东北名菜地三鲜', '/images/disanxian.jpg'),
('鱼香肉丝', '荤菜', 13.00, '川菜鱼香肉丝', '/images/yuxiangrousi.jpg'),
('青椒土豆丝', '素菜', 7.00, '清爽青椒土豆丝', '/images/qingjiaotudousi.jpg'),
('回锅肉', '荤菜', 16.00, '四川回锅肉', '/images/huiguorou.jpg'),
('酸辣土豆丝', '素菜', 8.00, '开胃酸辣土豆丝', '/images/suanlatudousi.jpg');
