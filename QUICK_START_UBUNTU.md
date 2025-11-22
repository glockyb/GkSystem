# Ubuntu 快速部署指南

## 🚀 三步快速部署

### 第一步：连接到服务器并安装 Docker

```bash
# 1. SSH 连接到 Ubuntu 服务器
ssh username@your-server-ip

# 2. 上传脚本到服务器（在本地执行）
scp install-docker-ubuntu.sh fix-docker-gpg.sh username@your-server-ip:~/

# 3. 如果遇到 GPG 密钥错误，先运行修复脚本（在服务器上）
ssh username@your-server-ip
chmod +x fix-docker-gpg.sh
sudo ./fix-docker-gpg.sh

# 4. 运行安装脚本
chmod +x install-docker-ubuntu.sh
sudo ./install-docker-ubuntu.sh

# 4. 重新登录或执行以下命令使组更改生效
newgrp docker
# 或重新 SSH 登录

# 5. 验证 Docker 安装
docker ps
```

### 第二步：上传项目文件

**方法一：使用 Git（推荐）**
```bash
# 在服务器上
cd ~
git clone <your-repo-url> GkSystem
cd GkSystem
```

**方法二：使用 SCP**
```bash
# 在本地电脑上执行
cd /path/to/GkSystem
tar -czf GkSystem.tar.gz --exclude='node_modules' --exclude='.git' --exclude='dist' .
scp GkSystem.tar.gz username@your-server-ip:~/

# 在服务器上
cd ~
tar -xzf GkSystem.tar.gz -C GkSystem
cd GkSystem
```

### 第三步：部署应用

```bash
# 1. 进入项目目录
cd ~/GkSystem

# 2. 运行部署脚本
chmod +x deploy-remote.sh
./deploy-remote.sh

# 或者手动部署
docker-compose up -d --build

# 3. 等待服务启动（约30秒）
sleep 30

# 4. 初始化数据
docker-compose exec backend python data/preprocessor.py
docker-compose exec backend python train_model.py

# 5. 配置防火墙
sudo ufw allow 8080/tcp
sudo ufw allow 5000/tcp
sudo ufw allow 22/tcp
sudo ufw enable
```

### 完成！访问系统

- 前端：`http://your-server-ip:8080`
- 后端：`http://your-server-ip:5000`

## 📋 常用命令

```bash
# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 进入容器
docker-compose exec backend bash
```

## 🐛 遇到问题？

1. **Docker 命令需要 sudo**
   ```bash
   newgrp docker  # 或重新登录
   ```

2. **端口被占用**
   ```bash
   sudo lsof -i :8080
   # 修改 docker-compose.yml 中的端口
   ```

3. **查看详细错误**
   ```bash
   docker-compose logs -f backend
   ```

详细文档请查看：
- [UBUNTU_DOCKER_SETUP.md](./UBUNTU_DOCKER_SETUP.md) - 完整部署指南
- [DOCKER_DEPLOY.md](./DOCKER_DEPLOY.md) - Docker 部署文档

