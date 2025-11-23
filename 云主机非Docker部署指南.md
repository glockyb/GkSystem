# 云主机非 Docker 部署指南

## 📋 概述

本指南说明如何在云主机上**不使用 Docker**，直接安装和运行前后端服务，并通过公网 IP 访问。

## 🎯 适用场景

- ✅ 云主机无法使用 Docker（网络问题、权限问题等）
- ✅ 需要更直接的控制和调试
- ✅ 资源受限，无法运行 Docker
- ✅ 需要更好的性能（无容器开销）

## 📋 前置要求

### 服务器要求

- **操作系统：Ubuntu 20.04 LTS**（推荐，脚本已优化）⭐
- 内存：至少 2GB
- 磁盘空间：至少 5GB
- 公网 IP：已配置并可访问

**注意**: 本部署脚本主要针对 **Ubuntu 20.04** 优化，其他版本可能需要手动调整。

### 软件要求

- Python 3.8+
- Node.js 16+
- MySQL 8.0+
- Redis 6.0+
- Nginx（用于反向代理）

## 🚀 快速部署

### 方法一：使用自动部署脚本（推荐）

```bash
# 1. 上传项目到云主机
scp -r GkSystem username@your-server-ip:~/

# 2. SSH 连接到云主机
ssh username@your-server-ip

# 3. 进入项目目录
cd ~/GkSystem

# 4. 运行部署脚本
chmod +x deploy-cloud-server.sh
sudo ./deploy-cloud-server.sh
```

脚本会自动：
- ✅ 安装所有系统依赖
- ✅ 配置 MySQL 和 Redis
- ✅ 配置后端 Python 环境
- ✅ 构建前端生产版本
- ✅ 配置 Nginx 反向代理
- ✅ 创建 systemd 服务
- ✅ 初始化数据和训练模型
- ✅ 配置防火墙

### 方法二：手动部署

详见下方详细步骤。

---

## 📝 详细部署步骤

### 第一步：连接到云主机

```bash
ssh username@your-server-ip
```

### 第二步：安装系统依赖

#### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    mysql-server \
    redis-server \
    nginx \
    nodejs \
    npm \
    curl \
    git
```

#### CentOS/RHEL

```bash
sudo yum install -y \
    python3 \
    python3-pip \
    mysql-server \
    redis \
    nginx \
    nodejs \
    npm \
    curl \
    git
```

### 第三步：配置 MySQL

```bash
# 启动 MySQL
sudo systemctl start mysql
sudo systemctl enable mysql

# 创建数据库
sudo mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS canteen_recommendation CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
EOF

# 导入初始化脚本
cd ~/GkSystem
sudo mysql -u root canteen_recommendation < backend/database/init.sql
```

### 第四步：配置 Redis

```bash
# 启动 Redis
sudo systemctl start redis-server  # Ubuntu
# 或
sudo systemctl start redis        # CentOS

# 设置开机自启
sudo systemctl enable redis-server
# 或
sudo systemctl enable redis

# 测试 Redis
redis-cli ping  # 应该返回 PONG
```

### 第五步：配置后端

```bash
cd ~/GkSystem/backend

# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate

# 安装依赖
pip3 install --upgrade pip
pip3 install -r requirements.txt

# 创建环境变量文件
cat > .env <<EOF
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=password
MYSQL_DATABASE=canteen_recommendation
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
EOF

# 修改 config.py 或使用环境变量
# 后端默认会读取环境变量
```

### 第六步：配置前端

```bash
cd ~/GkSystem/frontend

# 安装依赖
npm install --registry=https://registry.npmmirror.com || npm install

# 创建生产环境变量文件
# 获取公网 IP
PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "your-server-ip")

cat > .env.production <<EOF
VITE_API_URL=http://$PUBLIC_IP:5000
EOF

# 构建生产版本
npm run build
```

### 第七步：配置 Nginx 反向代理

```bash
# 创建 Nginx 配置
sudo nano /etc/nginx/sites-available/canteen
```

添加以下配置（替换 `your-server-ip` 为实际公网 IP）：

```nginx
server {
    listen 80;
    server_name your-server-ip;  # 或使用域名

    # 前端静态文件
    location / {
        root /home/username/GkSystem/frontend/dist;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # 后端 API 代理
    location /api {
        proxy_pass http://localhost:5000/api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

启用配置：

```bash
# 创建符号链接
sudo ln -s /etc/nginx/sites-available/canteen /etc/nginx/sites-enabled/

# 删除默认配置（可选）
sudo rm -f /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### 第八步：创建 systemd 服务

#### 后端服务

```bash
sudo nano /etc/systemd/system/canteen-backend.service
```

添加以下内容（替换路径为实际路径）：

```ini
[Unit]
Description=Canteen Recommendation Backend Service
After=network.target mysql.service redis.service

[Service]
Type=simple
User=username
WorkingDirectory=/home/username/GkSystem/backend
Environment="PATH=/home/username/GkSystem/backend/venv/bin"
ExecStart=/home/username/GkSystem/backend/venv/bin/python3 app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启用并启动服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable canteen-backend
sudo systemctl start canteen-backend

# 查看状态
sudo systemctl status canteen-backend
```

### 第九步：初始化数据

```bash
cd ~/GkSystem/backend
source venv/bin/activate

# 数据预处理
python3 data/preprocessor.py

# 训练模型
python3 train_model.py
```

### 第十步：配置防火墙

```bash
# Ubuntu/Debian
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP (Nginx)
sudo ufw allow 5000/tcp  # 后端 API（可选）
sudo ufw enable

# CentOS/RHEL
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --reload
```

### 第十一步：验证部署

```bash
# 检查后端服务
sudo systemctl status canteen-backend

# 检查 Nginx
sudo systemctl status nginx

# 测试后端 API
curl http://localhost:5000/health

# 测试前端
curl http://localhost/

# 从外部测试（使用公网 IP）
curl http://your-server-ip/health
```

---

## 🌐 访问系统

### 访问地址

- **前端界面**: `http://your-server-ip`（通过 Nginx，端口 80）
- **后端 API**: `http://your-server-ip:5000`（直接访问，可选）
- **健康检查**: `http://your-server-ip:5000/health`

### 使用域名（可选）

如果有域名，修改 Nginx 配置：

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    # ... 其他配置相同
}
```

然后配置 DNS 解析：
- A 记录：`your-domain.com` → `your-server-ip`

---

## 🔧 服务管理

### 后端服务管理

```bash
# 启动服务
sudo systemctl start canteen-backend

# 停止服务
sudo systemctl stop canteen-backend

# 重启服务
sudo systemctl restart canteen-backend

# 查看状态
sudo systemctl status canteen-backend

# 查看日志
sudo journalctl -u canteen-backend -f

# 查看最近日志
sudo journalctl -u canteen-backend -n 50
```

### Nginx 管理

```bash
# 重启 Nginx
sudo systemctl restart nginx

# 重新加载配置（不中断服务）
sudo systemctl reload nginx

# 查看状态
sudo systemctl status nginx

# 查看错误日志
sudo tail -f /var/log/nginx/error.log

# 查看访问日志
sudo tail -f /var/log/nginx/access.log
```

### MySQL 管理

```bash
# 启动/停止
sudo systemctl start mysql
sudo systemctl stop mysql

# 连接数据库
mysql -u root -p

# 备份数据库
mysqldump -u root -p canteen_recommendation > backup.sql

# 恢复数据库
mysql -u root -p canteen_recommendation < backup.sql
```

### Redis 管理

```bash
# 启动/停止
sudo systemctl start redis-server
sudo systemctl stop redis-server

# 连接 Redis
redis-cli

# 测试连接
redis-cli ping
```

---

## 🔄 更新应用

### 更新后端

```bash
cd ~/GkSystem

# 拉取最新代码
git pull

# 进入后端目录
cd backend
source venv/bin/activate

# 更新依赖（如果有新依赖）
pip3 install -r requirements.txt

# 重启服务
sudo systemctl restart canteen-backend
```

### 更新前端

```bash
cd ~/GkSystem/frontend

# 拉取最新代码
git pull

# 重新构建
npm run build

# 重启 Nginx（通常不需要，但建议）
sudo systemctl reload nginx
```

---

## 🐛 故障排查

### 后端服务无法启动

```bash
# 查看日志
sudo journalctl -u canteen-backend -n 50

# 检查 Python 环境
cd ~/GkSystem/backend
source venv/bin/activate
python3 --version

# 检查依赖
pip3 list

# 手动测试启动
python3 app.py
```

### 前端无法访问

```bash
# 检查 Nginx 状态
sudo systemctl status nginx

# 检查 Nginx 配置
sudo nginx -t

# 检查前端文件
ls -la ~/GkSystem/frontend/dist

# 查看 Nginx 错误日志
sudo tail -f /var/log/nginx/error.log
```

### 数据库连接失败

```bash
# 检查 MySQL 状态
sudo systemctl status mysql

# 测试连接
mysql -u root -p

# 检查数据库
mysql -u root -p -e "SHOW DATABASES;"

# 检查后端配置
cd ~/GkSystem/backend
cat .env
```

### API 请求失败

```bash
# 检查后端是否运行
curl http://localhost:5000/health

# 检查 Nginx 代理配置
sudo nginx -t

# 检查防火墙
sudo ufw status
```

---

## 🔒 安全建议

### 1. 修改 MySQL 密码

```bash
sudo mysql_secure_installation

# 或手动修改
sudo mysql -u root
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your-secure-password';
FLUSH PRIVILEGES;
exit;

# 更新后端配置
cd ~/GkSystem/backend
nano .env
# 修改 MYSQL_PASSWORD
```

### 2. 配置 HTTPS（推荐）

使用 Let's Encrypt 免费 SSL 证书：

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx

# 获取证书（需要域名）
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo certbot renew --dry-run
```

### 3. 限制后端端口访问

如果不需要直接访问后端 API，可以：

```bash
# 只允许本地访问（修改后端配置）
# 在 backend/app.py 中，确保 host='127.0.0.1' 而不是 '0.0.0.0'
# 或使用防火墙限制
sudo ufw deny 5000/tcp
sudo ufw allow from 127.0.0.1 to any port 5000
```

### 4. 定期更新

```bash
# 更新系统
sudo apt update && sudo apt upgrade

# 更新 Python 依赖
cd ~/GkSystem/backend
source venv/bin/activate
pip3 list --outdated
pip3 install --upgrade package-name
```

---

## 📊 性能优化

### 1. 使用 Gunicorn（生产环境推荐）

```bash
# 安装 Gunicorn
cd ~/GkSystem/backend
source venv/bin/activate
pip3 install gunicorn

# 修改 systemd 服务
sudo nano /etc/systemd/system/canteen-backend.service
```

修改 ExecStart：
```ini
ExecStart=/home/username/GkSystem/backend/venv/bin/gunicorn -w 4 -b 127.0.0.1:5000 app:app
```

### 2. 配置 Nginx 缓存

```nginx
# 在 Nginx 配置中添加
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### 3. 启用 Gzip 压缩

```nginx
# 在 Nginx 配置中添加
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss;
```

---

## 📚 相关文档

- [系统架构说明.md](./系统架构说明.md) - 系统架构
- [前后端连接说明.md](./前后端连接说明.md) - 前后端连接
- [防火墙端口配置指南.md](./防火墙端口配置指南.md) - 防火墙配置

---

## ✅ 部署检查清单

- [ ] 系统依赖已安装
- [ ] MySQL 已安装并运行
- [ ] Redis 已安装并运行
- [ ] 后端虚拟环境已创建
- [ ] 后端依赖已安装
- [ ] 前端已构建
- [ ] Nginx 已配置
- [ ] systemd 服务已创建
- [ ] 数据已初始化
- [ ] 模型已训练
- [ ] 防火墙已配置
- [ ] 服务正常运行
- [ ] 可以通过公网 IP 访问

---

**部署完成后，访问 `http://your-server-ip` 即可使用系统！**

