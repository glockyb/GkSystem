# Ubuntu 远程服务器 Docker 部署完整指南

本指南将帮助您在远程 Ubuntu 服务器上安装 Docker 并部署校园食堂菜品推荐系统。

## 📋 前置准备

### 1. 连接到远程服务器

```bash
# 使用 SSH 连接到 Ubuntu 服务器
ssh username@your-server-ip

# 如果使用密钥文件
ssh -i /path/to/your-key.pem username@your-server-ip
```

### 2. 检查系统信息

```bash
# 查看 Ubuntu 版本
lsb_release -a

# 查看系统信息
uname -a
```

## 🐳 第一步：安装 Docker

### 方法一：使用官方安装脚本（推荐）

```bash
# 更新系统包
sudo apt-get update

# 安装必要的依赖
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 添加 Docker 官方 GPG 密钥
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 设置 Docker 仓库
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装 Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 验证安装
sudo docker --version
sudo docker compose version
```

### 方法二：使用便捷脚本

```bash
# 下载并运行 Docker 官方安装脚本
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 安装 Docker Compose（如果使用独立版本）
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
sudo docker --version
sudo docker-compose --version
```

### 3. 配置 Docker（重要）

```bash
# 将当前用户添加到 docker 组（避免每次使用 sudo）
sudo usermod -aG docker $USER

# 重新登录或执行以下命令使组更改生效
newgrp docker

# 验证无需 sudo 即可运行 Docker
docker ps

# 设置 Docker 开机自启
sudo systemctl enable docker
sudo systemctl start docker

# 验证 Docker 服务状态
sudo systemctl status docker
```

## 📦 第二步：上传项目文件

### 方法一：使用 Git（推荐）

```bash
# 在服务器上安装 Git（如果未安装）
sudo apt-get install -y git

# 克隆项目
cd ~
git clone <your-repo-url> GkSystem
cd GkSystem

# 或使用 HTTPS
git clone https://github.com/your-username/your-repo.git GkSystem
cd GkSystem
```

### 方法二：使用 SCP（从本地传输）

在**本地电脑**上执行：

```bash
# 压缩项目（排除 node_modules 和 .git）
tar -czf GkSystem.tar.gz --exclude='node_modules' --exclude='.git' --exclude='dist' GkSystem

# 传输到服务器
scp GkSystem.tar.gz username@your-server-ip:~/

# 或使用 rsync（更高效）
rsync -avz --exclude 'node_modules' --exclude '.git' --exclude 'dist' \
  GkSystem/ username@your-server-ip:~/GkSystem/
```

在**服务器**上执行：

```bash
# 如果使用 tar.gz
cd ~
tar -xzf GkSystem.tar.gz
cd GkSystem

# 如果使用 rsync，文件已经在正确位置
cd ~/GkSystem
```

### 方法三：使用 SFTP 客户端

使用 FileZilla、WinSCP 等工具直接上传项目文件夹。

## ⚙️ 第三步：配置项目

### 1. 检查项目文件

```bash
cd ~/GkSystem
ls -la

# 确认以下文件存在
# - docker-compose.yml
# - frontend/Dockerfile
# - backend/Dockerfile
```

### 2. 配置环境变量（可选）

```bash
# 创建 .env 文件
nano .env
```

添加以下内容（根据实际情况修改）：

```env
# 服务器 IP 或域名
SERVER_IP=your-server-ip

# 前端 API 地址（如果前端和后端在同一服务器，使用内部地址）
VITE_API_URL=http://your-server-ip:5000

# MySQL 配置（生产环境请使用强密码）
MYSQL_ROOT_PASSWORD=your-secure-password-here
MYSQL_DATABASE=canteen_recommendation
```

保存文件：`Ctrl+O`，然后 `Enter`，退出：`Ctrl+X`

### 3. 修改 docker-compose.yml（如需要）

```bash
# 编辑 docker-compose.yml
nano docker-compose.yml
```

如果需要修改端口或密码，编辑相应部分：

```yaml
# 修改 MySQL 密码
environment:
  MYSQL_ROOT_PASSWORD: your-secure-password  # 修改这里

# 修改端口映射（如果需要）
ports:
  - "8080:80"  # 前端端口
  - "5000:5000"  # 后端端口
```

## 🚀 第四步：构建和启动服务

### 方法一：使用部署脚本（推荐）

```bash
# 确保脚本有执行权限
chmod +x deploy-remote.sh

# 运行部署脚本
./deploy-remote.sh
```

脚本会自动：
- 检查 Docker 环境
- 构建 Docker 镜像
- 启动所有服务
- 初始化数据
- 训练推荐模型

### 方法二：手动部署

```bash
# 1. 构建并启动所有服务
docker-compose up -d --build

# 2. 查看服务状态
docker-compose ps

# 3. 查看日志（确认服务正常启动）
docker-compose logs -f

# 按 Ctrl+C 退出日志查看
```

等待约 30-60 秒，让 MySQL 和 Redis 完全启动。

### 4. 初始化数据

```bash
# 等待数据库就绪
sleep 30

# 初始化数据
docker-compose exec backend python data/preprocessor.py

# 训练推荐模型
docker-compose exec backend python train_model.py
```

## 🔍 第五步：验证部署

### 1. 检查服务状态

```bash
# 查看所有容器状态
docker-compose ps

# 应该看到所有服务都是 "Up" 状态
# - canteen-mysql
# - canteen-redis
# - canteen-backend
# - canteen-frontend
```

### 2. 检查端口监听

```bash
# 检查端口是否被监听
sudo netstat -tulpn | grep -E '8080|5000|3306|6379'

# 或使用 ss 命令
sudo ss -tulpn | grep -E '8080|5000|3306|6379'
```

### 3. 测试服务

```bash
# 测试后端健康检查
curl http://localhost:5000/health

# 测试前端（应该返回 HTML）
curl http://localhost:8080

# 从外部测试（替换为你的服务器 IP）
curl http://your-server-ip:5000/health
```

### 4. 查看日志

```bash
# 查看所有服务日志
docker-compose logs

# 查看特定服务日志
docker-compose logs backend
docker-compose logs frontend
docker-compose logs mysql

# 实时查看日志
docker-compose logs -f backend
```

## 🌐 第六步：配置防火墙

### Ubuntu UFW 防火墙

```bash
# 检查防火墙状态
sudo ufw status

# 如果防火墙未启用，可以启用它
sudo ufw enable

# 允许 SSH（重要！避免被锁在外面）
sudo ufw allow 22/tcp

# 允许应用端口
sudo ufw allow 8080/tcp  # 前端
sudo ufw allow 5000/tcp  # 后端

# 如果需要在外部访问 MySQL 和 Redis（不推荐，仅开发环境）
# sudo ufw allow 3306/tcp
# sudo ufw allow 6379/tcp

# 查看规则
sudo ufw status numbered

# 如果需要删除规则
# sudo ufw delete [规则编号]
```

### 云服务器安全组

如果您使用的是阿里云、腾讯云、AWS 等云服务器，还需要在控制台配置安全组规则：

1. 登录云服务器控制台
2. 找到安全组配置
3. 添加入站规则：
   - 端口 8080，协议 TCP，允许
   - 端口 5000，协议 TCP，允许
   - 端口 22（SSH），协议 TCP，允许

## 📱 第七步：访问系统

### 本地访问（在服务器上）

```bash
# 如果服务器有图形界面，可以在浏览器访问
# http://localhost:8080
```

### 远程访问

在浏览器中访问：
- **前端界面**: `http://your-server-ip:8080`
- **后端 API**: `http://your-server-ip:5000`
- **健康检查**: `http://your-server-ip:5000/health`

### 使用域名（可选）

如果您有域名，可以配置 Nginx 反向代理：

```bash
# 安装 Nginx
sudo apt-get install -y nginx

# 创建配置文件
sudo nano /etc/nginx/sites-available/canteen
```

添加以下配置：

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # 前端
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 后端 API
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

# 测试配置
sudo nginx -t

# 重载 Nginx
sudo systemctl reload nginx
```

## 🔧 常用管理命令

### 服务管理

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 重启特定服务
docker-compose restart backend

# 查看服务状态
docker-compose ps

# 查看资源使用
docker stats
```

### 日志管理

```bash
# 查看所有日志
docker-compose logs

# 查看最近 100 行日志
docker-compose logs --tail=100

# 实时查看日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f backend
```

### 容器管理

```bash
# 进入容器
docker-compose exec backend bash
docker-compose exec frontend sh
docker-compose exec mysql bash

# 查看容器详细信息
docker inspect canteen-backend

# 查看容器资源使用
docker stats canteen-backend
```

### 数据库管理

```bash
# 连接 MySQL
docker-compose exec mysql mysql -uroot -p

# 备份数据库
docker-compose exec mysql mysqldump -uroot -p canteen_recommendation > backup.sql

# 恢复数据库
docker-compose exec -T mysql mysql -uroot -p canteen_recommendation < backup.sql
```

### 更新应用

```bash
# 拉取最新代码
git pull

# 重新构建并启动
docker-compose up -d --build

# 仅重建特定服务
docker-compose build backend
docker-compose up -d backend
```

## 🐛 故障排查

### 问题 1: Docker 命令需要 sudo

```bash
# 解决方案：将用户添加到 docker 组
sudo usermod -aG docker $USER
newgrp docker

# 验证
docker ps
```

### 问题 2: 端口被占用

```bash
# 查看端口占用
sudo lsof -i :8080
sudo netstat -tulpn | grep 8080

# 停止占用端口的服务或修改 docker-compose.yml 中的端口
```

### 问题 3: 容器无法启动

```bash
# 查看详细错误
docker-compose logs backend

# 检查镜像
docker images

# 重新构建（不使用缓存）
docker-compose build --no-cache
docker-compose up -d
```

### 问题 4: 数据库连接失败

```bash
# 检查 MySQL 容器状态
docker-compose ps mysql

# 检查 MySQL 日志
docker-compose logs mysql

# 测试 MySQL 连接
docker-compose exec mysql mysqladmin ping -h localhost -uroot -p

# 检查网络
docker-compose exec backend ping mysql
```

### 问题 5: 前端无法访问后端

```bash
# 检查后端是否运行
curl http://localhost:5000/health

# 检查 nginx 配置
docker-compose exec frontend cat /etc/nginx/conf.d/default.conf

# 查看前端日志
docker-compose logs frontend
```

### 问题 6: 内存不足

```bash
# 查看系统资源
free -h
df -h

# 清理 Docker 资源
docker system prune -a

# 限制容器资源（在 docker-compose.yml 中添加）
deploy:
  resources:
    limits:
      memory: 512M
```

## 🔒 安全建议

### 1. 修改默认密码

```bash
# 编辑 docker-compose.yml，修改 MySQL 密码
nano docker-compose.yml
```

### 2. 配置防火墙

```bash
# 只开放必要端口
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 8080/tcp # 前端
sudo ufw allow 5000/tcp # 后端
sudo ufw enable
```

### 3. 使用 HTTPS

```bash
# 安装 Certbot
sudo apt-get install -y certbot python3-certbot-nginx

# 获取 SSL 证书
sudo certbot --nginx -d your-domain.com
```

### 4. 定期备份

```bash
# 创建备份脚本
nano ~/backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/home/username/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# 备份数据库
docker-compose exec -T mysql mysqldump -uroot -p$MYSQL_PASSWORD canteen_recommendation > $BACKUP_DIR/db_$DATE.sql

# 备份模型文件
docker cp canteen-backend:/app/models $BACKUP_DIR/models_$DATE

# 删除 7 天前的备份
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
```

```bash
chmod +x ~/backup.sh

# 添加到 crontab（每天凌晨 2 点备份）
crontab -e
# 添加：0 2 * * * /home/username/backup.sh
```

## 📊 监控和维护

### 设置开机自启

创建 systemd 服务：

```bash
sudo nano /etc/systemd/system/canteen.service
```

```ini
[Unit]
Description=Canteen Recommendation System
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/username/GkSystem
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

启用服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable canteen.service
sudo systemctl start canteen.service
```

### 监控资源

```bash
# 查看容器资源使用
docker stats

# 查看系统资源
htop  # 需要安装: sudo apt-get install htop
```

## ✅ 部署检查清单

- [ ] Docker 和 Docker Compose 已安装
- [ ] 项目文件已上传到服务器
- [ ] 环境变量已配置
- [ ] 所有服务容器正常运行
- [ ] 端口已正确映射
- [ ] 防火墙规则已配置
- [ ] 可以从外部访问前端
- [ ] 后端 API 可以正常响应
- [ ] 数据库已初始化
- [ ] 推荐模型已训练
- [ ] 日志无错误信息

## 📞 获取帮助

如果遇到问题：

1. 查看日志：`docker-compose logs -f`
2. 检查服务状态：`docker-compose ps`
3. 查看本文档的故障排查部分
4. 检查 [DOCKER_DEPLOY.md](./DOCKER_DEPLOY.md)

---

**部署完成后，访问 `http://your-server-ip:8080` 即可使用系统！**

祝您部署顺利！🎉

