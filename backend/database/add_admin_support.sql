-- 添加管理员支持

USE canteen_recommendation;

-- 添加用户角色字段（兼容 MySQL 5.7+）
-- 先检查列是否存在，如果不存在则添加
SET @dbname = DATABASE();
SET @tablename = 'users';
SET @columnname1 = 'role';
SET @columnname2 = 'is_admin';

SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (TABLE_SCHEMA = @dbname)
      AND (TABLE_NAME = @tablename)
      AND (COLUMN_NAME = @columnname1)
  ) > 0,
  'SELECT 1',
  CONCAT('ALTER TABLE ', @tablename, ' ADD COLUMN ', @columnname1, ' VARCHAR(20) DEFAULT ''user'' AFTER email')
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (TABLE_SCHEMA = @dbname)
      AND (TABLE_NAME = @tablename)
      AND (COLUMN_NAME = @columnname2)
  ) > 0,
  'SELECT 1',
  CONCAT('ALTER TABLE ', @tablename, ' ADD COLUMN ', @columnname2, ' BOOLEAN DEFAULT FALSE AFTER role')
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- 创建管理员用户（如果不存在）
-- 注意：这里使用 Python 脚本创建，因为需要 bcrypt 加密密码
-- 如果 admin 用户已存在，更新为管理员
UPDATE users SET role = 'admin', is_admin = TRUE WHERE username = 'admin';

-- 添加索引（如果不存在）
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE
      (TABLE_SCHEMA = @dbname)
      AND (TABLE_NAME = @tablename)
      AND (INDEX_NAME = 'idx_role')
  ) > 0,
  'SELECT 1',
  CONCAT('CREATE INDEX idx_role ON ', @tablename, '(role)')
));
PREPARE createIndexIfNotExists FROM @preparedStatement;
EXECUTE createIndexIfNotExists;
DEALLOCATE PREPARE createIndexIfNotExists;

SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE
      (TABLE_SCHEMA = @dbname)
      AND (TABLE_NAME = @tablename)
      AND (INDEX_NAME = 'idx_is_admin')
  ) > 0,
  'SELECT 1',
  CONCAT('CREATE INDEX idx_is_admin ON ', @tablename, '(is_admin)')
));
PREPARE createIndexIfNotExists FROM @preparedStatement;
EXECUTE createIndexIfNotExists;
DEALLOCATE PREPARE createIndexIfNotExists;

