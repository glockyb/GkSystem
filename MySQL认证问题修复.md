# MySQL 认证问题修复指南

## 🔍 问题描述

错误信息：
```
pymysql.err.OperationalError: (1698, "Access denied for user 'root'@'localhost'")
```

**原因：** MySQL 8.0+ 默认使用 `auth_socket` 插件，`root` 用户只能通过 Unix socket 以系统 root 用户身份登录，不能使用密码。

## 🚀 立即修复

运行修复脚本：

```bash
cd ~/gksys/GkSystem
chmod +x fix-mysql-auth.sh
sudo ./fix-mysql-auth.sh
```

## 📋 手动修复步骤

### 方法1：修改 root 用户使用密码认证（推荐）

```bash
# 使用 sudo 登录 MySQL（无需密码）
sudo mysql

# 在 MySQL 中执行：
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';
FLUSH PRIVILEGES;

# 退出
exit;
```

### 方法2：创建新的 MySQL 用户（更安全）

```bash
# 使用 sudo 登录 MySQL
sudo mysql

# 在 MySQL 中执行：
CREATE USER 'canteen'@'localhost' IDENTIFIED BY 'canteen123';
GRANT ALL PRIVILEGES ON *.* TO 'canteen'@'localhost';
FLUSH PRIVILEGES;

# 退出
exit;
```

然后修改后端配置使用新用户。

## 🔧 更新后端服务配置

修复 MySQL 认证后，需要确保后端服务使用正确的数据库配置。

### 检查服务配置

```bash
sudo cat /etc/systemd/system/canteen-backend.service | grep -A 5 Environment
```

### 如果服务配置中没有数据库环境变量，需要添加：

```bash
sudo nano /etc/systemd/system/canteen-backend.service
```

在 `[Service]` 部分添加：

```ini
Environment="MYSQL_HOST=localhost"
Environment="MYSQL_PORT=3306"
Environment="MYSQL_USER=root"
Environment="MYSQL_PASSWORD=password"
Environment="MYSQL_DATABASE=canteen_recommendation"
```

### 重新加载并重启服务

```bash
sudo systemctl daemon-reload
sudo systemctl restart canteen-backend
```

## ✅ 验证修复

```bash
# 1. 测试 MySQL 连接
mysql -u root -ppassword -e "SELECT 1;"

# 2. 测试后端健康检查
curl http://localhost:5000/health

# 3. 测试 API 端点
curl http://localhost:5000/api/v1/dishes/categories

# 4. 查看后端日志
sudo journalctl -u canteen-backend -n 50
```

## 🔍 常见问题

### Q1: `sudo mysql` 也提示需要密码？

**A:** 检查 MySQL 服务是否运行：
```bash
sudo systemctl status mysql
sudo systemctl start mysql
```

### Q2: 修改后仍然无法连接？

**A:** 检查 MySQL 用户权限：
```bash
sudo mysql -e "SELECT user, host, plugin FROM mysql.user WHERE user='root';"
```

应该看到 `plugin` 为 `mysql_native_password`。

### Q3: 想使用不同的密码？

**A:** 修改命令中的密码：
```sql
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '你的密码';
```

然后更新后端服务配置中的 `MYSQL_PASSWORD`。

## 📚 相关脚本

- `fix-mysql-auth.sh` - 自动修复 MySQL 认证问题
- `快速修复500错误.sh` - 快速诊断和修复 500 错误

---

**运行修复脚本后，重启后端服务并测试 API！**

