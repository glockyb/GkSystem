-- 添加管理员支持（简化版，兼容所有 MySQL 版本）

USE canteen_recommendation;

-- 添加用户角色字段
-- 如果列已存在会报错，但可以忽略
ALTER TABLE users 
ADD COLUMN role VARCHAR(20) DEFAULT 'user' AFTER email;

ALTER TABLE users 
ADD COLUMN is_admin BOOLEAN DEFAULT FALSE AFTER role;

-- 如果admin用户已存在，更新为管理员
UPDATE users SET role = 'admin', is_admin = TRUE WHERE username = 'admin';

-- 添加索引（如果已存在会报错，但可以忽略）
CREATE INDEX idx_role ON users(role);
CREATE INDEX idx_is_admin ON users(is_admin);

