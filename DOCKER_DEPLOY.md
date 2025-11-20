# Docker 部署指南

本文档说明如何在远端服务器上使用 Docker 部署和运行校园食堂菜品推荐系统。

## 📋 前置要求

### 服务器要求
- 操作系统：Linux (Ubuntu 20.04+ / CentOS 7+)
- Docker：版本 20.10+
- Docker Compose：版本 1.29+
- 内存：至少 2GB
- 磁盘空间：至少 10GB

### 网络要求
- 开放端口：8080 (前端), 5000 (后端), 3306 (MySQL), 6379 (Redis)
- 建议使用防火墙规则限制访问

## 🚀 快速部署

### 1. 连接到远端服务器

```bash
# 使用 SSH 连接到服务器
ssh username@your-server-ip

# 或者使用密钥文件
ssh -i /path/to/your-key.pem username@your-server-ip
```

### 2. 安装 Docker 和 Docker Compose

如果服务器上还没有安装 Docker，可以运行：

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker --version
docker-compose --version
```

### 3. 上传项目文件

#### 方法一：使用 Git（推荐）

```bash
# 在服务器上克隆项目
git clone <your-repo-url> GkSystem
cd GkSystem
```

#### 方法二：使用 SCP

```bash
# 在本地执行
scp -r /path/to/GkSystem username@your-server-ip:/home/username/
```

#### 方法三：使用 rsync

```bash
# 在本地执行
rsync -avz --exclude 'node_modules' --exclude '.git' /path/to/GkSystem username@your-server-ip:/home/username/
```

### 4. 配置环境变量

编辑 `docker-compose.yml` 文件，根据实际情况修改配置：

```yaml
# 修改数据库密码（生产环境必须修改）
environment:
  MYSQL_ROOT_PASSWORD: your-secure-password  # 修改为强密码
  MYSQL_DATABASE: canteen_recommendation

# 修改前端 API 地址（如果前端和后端不在同一服务器）
environment:
  - VITE_API_URL=http://your-backend-ip:5000
```

### 5. 构建和启动服务

```bash
# 进入项目目录
cd GkSystem

# 构建并启动所有服务
docker-compose up -d --build

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 6. 初始化数据（首次运行）

```bash
# 等待 MySQL 和 Redis 完全启动（约30秒）
sleep 30

# 初始化数据
docker-compose exec backend python data/preprocessor.py

# 训练推荐模型
docker-compose exec backend python train_model.py
```

## 🔧 配置说明

### 端口映射

默认端口配置：
- **前端**: 8080 → 80 (容器内)
- **后端**: 5000 → 5000 (容器内)
- **MySQL**: 3306 → 3306 (容器内)
- **Redis**: 6379 → 6379 (容器内)

如需修改端口，编辑 `docker-compose.yml`：

```yaml
ports:
  - "8080:80"  # 修改左侧端口号
```

### 数据持久化

数据存储在 Docker volumes 中：
- `mysql_data`: MySQL 数据
- `redis_data`: Redis 数据
- `model_data`: 训练好的模型

查看 volumes：
```bash
docker volume ls
```

备份数据：
```bash
# 备份 MySQL
docker run --rm -v canteen_recommendation_mysql_data:/data -v $(pwd):/backup alpine tar czf /backup/mysql_backup.tar.gz /data

# 恢复 MySQL
docker run --rm -v canteen_recommendation_mysql_data:/data -v $(pwd):/backup alpine tar xzf /backup/mysql_backup.tar.gz -C /
```

## 🌐 访问系统

### 本地访问

如果服务器在本地网络：
- 前端：http://your-server-ip:8080
- 后端 API：http://your-server-ip:5000

### 公网访问

1. **配置防火墙**（以 Ubuntu UFW 为例）：
```bash
sudo ufw allow 8080/tcp
sudo ufw allow 5000/tcp
sudo ufw status
```

2. **配置域名（可选）**：
   - 使用 Nginx 反向代理
   - 配置 SSL 证书（Let's Encrypt）

### Nginx 反向代理配置示例

```nginx
# /etc/nginx/sites-available/canteen
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /api {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

启用配置：
```bash
sudo ln -s /etc/nginx/sites-available/canteen /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 📊 常用命令

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

# 查看日志
docker-compose logs -f              # 所有服务
docker-compose logs -f backend      # 特定服务
docker-compose logs --tail=100      # 最后100行
```

### 容器管理

```bash
# 进入容器
docker-compose exec backend bash
docker-compose exec frontend sh

# 查看容器资源使用
docker stats

# 查看容器详细信息
docker inspect canteen-backend
```

### 数据库操作

```bash
# 连接 MySQL
docker-compose exec mysql mysql -uroot -ppassword canteen_recommendation

# 备份数据库
docker-compose exec mysql mysqldump -uroot -ppassword canteen_recommendation > backup.sql

# 恢复数据库
docker-compose exec -T mysql mysql -uroot -ppassword canteen_recommendation < backup.sql
```

### 更新和重建

```bash
# 拉取最新代码
git pull

# 重新构建并启动
docker-compose up -d --build

# 仅重建特定服务
docker-compose build backend
docker-compose up -d backend
```

## 🔍 故障排查

### 检查服务状态

```bash
# 查看所有容器状态
docker-compose ps

# 查看服务健康状态
docker-compose ps | grep healthy
```

### 查看日志

```bash
# 查看所有日志
docker-compose logs

# 查看错误日志
docker-compose logs | grep -i error

# 实时查看日志
docker-compose logs -f backend
```

### 常见问题

1. **端口被占用**
```bash
# 检查端口占用
sudo netstat -tulpn | grep :8080
sudo lsof -i :8080

# 修改 docker-compose.yml 中的端口映射
```

2. **容器无法启动**
```bash
# 查看详细错误
docker-compose logs backend

# 检查镜像是否构建成功
docker images

# 重新构建
docker-compose build --no-cache backend
```

3. **数据库连接失败**
```bash
# 检查 MySQL 是否健康
docker-compose exec mysql mysqladmin ping -h localhost -uroot -ppassword

# 检查网络连接
docker-compose exec backend ping mysql
```

4. **前端无法连接后端**
```bash
# 检查后端是否运行
curl http://localhost:5000/health

# 检查前端配置
docker-compose exec frontend cat /usr/share/nginx/html/index.html
```

### 清理和重置

```bash
# 停止并删除容器
docker-compose down

# 删除容器和 volumes（⚠️ 会删除数据）
docker-compose down -v

# 删除所有相关镜像
docker-compose down --rmi all

# 清理未使用的资源
docker system prune -a
```

## 🔒 安全建议

1. **修改默认密码**
   - 修改 MySQL root 密码
   - 使用强密码策略

2. **限制端口访问**
   - 使用防火墙只允许必要端口
   - 考虑使用 VPN 或 SSH 隧道

3. **使用 HTTPS**
   - 配置 SSL 证书
   - 使用 Let's Encrypt 免费证书

4. **定期备份**
   - 设置自动备份脚本
   - 备份数据库和模型文件

5. **更新和维护**
   - 定期更新 Docker 镜像
   - 监控系统资源使用

## 📝 监控和维护

### 资源监控

```bash
# 查看资源使用
docker stats

# 查看磁盘使用
docker system df
```

### 日志管理

```bash
# 配置日志轮转（在 docker-compose.yml 中）
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 自动启动

配置 Docker Compose 服务自动启动：

```bash
# 创建 systemd 服务文件
sudo nano /etc/systemd/system/canteen.service
```

内容：
```ini
[Unit]
Description=Canteen Recommendation System
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/username/GkSystem
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

启用服务：
```bash
sudo systemctl enable canteen.service
sudo systemctl start canteen.service
```

## 📞 技术支持

如遇到问题，请检查：
1. Docker 和 Docker Compose 版本
2. 系统资源（内存、磁盘）
3. 网络连接和防火墙设置
4. 日志文件中的错误信息

---

**部署完成后，访问 http://your-server-ip:8080 即可使用系统！**

