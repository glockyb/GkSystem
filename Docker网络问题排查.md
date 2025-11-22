# Docker 网络问题排查指南

## 📋 问题描述

在远端服务器上部署时，如果遇到以下错误：
```
Error response from daemon: failed to resolve reference "docker.io/library/redis:7-alpine": 
failed to do request: Head "https://registry-1.docker.io/v2/library/redis/manifests/7-alpine": 
dial tcp 69.63.186.31:443: i/o timeout
```

这表示**无法连接到 Docker Hub 拉取镜像**。

## 🔍 问题原因

1. **网络超时**：无法访问 Docker Hub（通常在中国服务器上）
2. **连接中断**：部署过程中 SSH 连接中断，导致容器状态异常
3. **防火墙限制**：防火墙阻止了 Docker Hub 的连接
4. **DNS 问题**：无法解析 Docker Hub 域名

## ✅ 解决方案

### 方案一：使用修复脚本（推荐）

运行修复脚本，它会：
- 清理残留容器和资源
- 自动配置 Docker 镜像加速器（中国镜像源）
- 测试网络连接
- 可选预拉取镜像

```bash
# 在项目根目录运行
./fix-deploy-issue.sh
```

### 方案二：手动配置 Docker 镜像加速器

#### 1. 创建或编辑 Docker 配置文件

```bash
sudo mkdir -p /etc/docker
sudo nano /etc/docker/daemon.json
```

#### 2. 添加镜像加速器配置

```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

#### 3. 重启 Docker 服务

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker

# 验证配置
docker info | grep -A 10 "Registry Mirrors"
```

### 方案三：手动清理和重新部署

#### 1. 清理残留容器

```bash
cd /path/to/GkSystem

# 停止所有容器
docker-compose down || docker compose down

# 如果上面失败，手动停止
docker stop canteen-mysql canteen-redis canteen-backend canteen-frontend 2>/dev/null
docker rm canteen-mysql canteen-redis canteen-backend canteen-frontend 2>/dev/null

# 清理网络
docker network prune -f
```

#### 2. 手动拉取镜像（使用镜像加速器）

```bash
# 配置镜像加速器后，拉取镜像
docker pull mysql:8.0
docker pull redis:7-alpine
docker pull nginx:alpine
docker pull python:3.9-slim
docker pull node:18-alpine
```

#### 3. 重新部署

```bash
./deploy-remote.sh
```

### 方案四：使用阿里云镜像加速器

#### 1. 获取阿里云加速器地址

1. 登录阿里云控制台
2. 进入容器镜像服务
3. 获取专属加速器地址（格式：`https://xxxxx.mirror.aliyuncs.com`）

#### 2. 配置加速器

```bash
sudo nano /etc/docker/daemon.json
```

添加：
```json
{
  "registry-mirrors": [
    "https://xxxxx.mirror.aliyuncs.com"
  ]
}
```

#### 3. 重启 Docker

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## 🛠️ 故障排查步骤

### 步骤1：检查网络连接

```bash
# 测试 Docker Hub 连接
ping -c 3 registry-1.docker.io

# 测试镜像加速器连接
ping -c 3 docker.mirrors.ustc.edu.cn

# 测试 HTTPS 连接
curl -I https://docker.mirrors.ustc.edu.cn
```

### 步骤2：检查 Docker 服务状态

```bash
# 检查 Docker 状态
sudo systemctl status docker

# 检查 Docker 信息
docker info

# 检查镜像仓库配置
docker info | grep -A 10 "Registry Mirrors"
```

### 步骤3：检查防火墙设置

```bash
# Ubuntu/Debian
sudo ufw status
sudo ufw allow 443/tcp  # 允许 HTTPS

# CentOS/RHEL
sudo firewall-cmd --list-all
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 步骤4：检查 DNS 解析

```bash
# 测试 DNS 解析
nslookup registry-1.docker.io
nslookup docker.mirrors.ustc.edu.cn

# 如果 DNS 有问题，可以修改 /etc/resolv.conf
sudo nano /etc/resolv.conf
# 添加：
# nameserver 8.8.8.8
# nameserver 114.114.114.114
```

### 步骤5：查看 Docker 日志

```bash
# 查看 Docker 服务日志
sudo journalctl -u docker.service -n 50

# 查看 Docker 守护进程日志
sudo journalctl -xe | grep docker
```

## 🔧 常用镜像加速器列表

### 国内镜像加速器

1. **中科大镜像**（推荐）
   ```
   https://docker.mirrors.ustc.edu.cn
   ```

2. **网易镜像**
   ```
   https://hub-mirror.c.163.com
   ```

3. **百度云镜像**
   ```
   https://mirror.baidubce.com
   ```

4. **阿里云镜像**（需要注册）
   ```
   https://xxxxx.mirror.aliyuncs.com
   ```

5. **腾讯云镜像**（需要注册）
   ```
   https://mirror.ccs.tencentyun.com
   ```

## 📝 部署中断后的处理流程

### 1. 立即处理

```bash
# 运行修复脚本
./fix-deploy-issue.sh
```

### 2. 如果修复脚本不可用

```bash
# 步骤1：清理残留容器
docker-compose down || docker compose down
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# 步骤2：配置镜像加速器
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF

# 步骤3：重启 Docker
sudo systemctl daemon-reload
sudo systemctl restart docker

# 步骤4：验证配置
docker info | grep "Registry Mirrors"

# 步骤5：重新部署
./deploy-remote.sh
```

## ⚠️ 注意事项

1. **保持连接**：使用 `screen` 或 `tmux` 保持会话
   ```bash
   # 安装 screen
   sudo apt install screen
   
   # 创建会话
   screen -S deploy
   
   # 运行部署脚本
   ./deploy-remote.sh
   
   # 断开连接（Ctrl+A, D）
   # 重新连接：screen -r deploy
   ```

2. **使用 nohup**：后台运行部署
   ```bash
   nohup ./deploy-remote.sh > deploy.log 2>&1 &
   
   # 查看日志
   tail -f deploy.log
   ```

3. **检查资源**：确保服务器有足够的资源
   ```bash
   # 检查磁盘空间
   df -h
   
   # 检查内存
   free -h
   
   # 检查 Docker 资源
   docker system df
   ```

## 🎯 快速修复命令

如果遇到网络问题，运行以下命令：

```bash
# 一键修复（使用修复脚本）
./fix-deploy-issue.sh

# 或手动修复（快速版）
docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true
sudo systemctl restart docker
sleep 5
./deploy-remote.sh
```

## 📚 相关文档

- [DOCKER_DEPLOY.md](./DOCKER_DEPLOY.md) - Docker 部署完整指南
- [UBUNTU_DOCKER_SETUP.md](./UBUNTU_DOCKER_SETUP.md) - Ubuntu 服务器部署指南
- [QUICK_START_UBUNTU.md](./QUICK_START_UBUNTU.md) - 快速部署指南

---

**记住：如果部署中断，先运行修复脚本清理残留资源，配置镜像加速器，然后重新部署！**

