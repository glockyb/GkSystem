-- 添加管理员支持

USE canteen_recommendation;

-- 添加用户角色字段
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'user' AFTER email,
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE AFTER role;

-- 创建管理员用户（如果不存在）
-- 默认管理员：admin / admin123
INSERT INTO users (username, password_hash, email, role, is_admin) 
SELECT 'admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyY5Y5Y5Y5Y5', 'admin@example.com', 'admin', TRUE
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin');

-- 如果admin用户已存在，更新为管理员
UPDATE users SET role = 'admin', is_admin = TRUE WHERE username = 'admin';

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_is_admin ON users(is_admin);

