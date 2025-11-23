# Ubuntu 20.04 部署说明

## 📋 系统要求

- **操作系统**: Ubuntu 20.04 LTS
- **内存**: 至少 2GB
- **磁盘空间**: 至少 5GB
- **网络**: 公网 IP 可访问

## 🚀 快速部署

### 一键部署脚本

```bash
# 1. 上传项目到 Ubuntu 20.04 云主机
scp -r GkSystem username@your-server-ip:~/

# 2. SSH 连接到云主机
ssh username@your-server-ip

# 3. 进入项目目录
cd ~/GkSystem

# 4. 运行部署脚本（专为 Ubuntu 20.04 优化）
chmod +x deploy-cloud-server.sh
sudo ./deploy-cloud-server.sh
```

## 🔧 Ubuntu 20.04 特定配置

### Node.js 版本

Ubuntu 20.04 默认的 Node.js 版本可能较旧，脚本会自动：
- 检测 Node.js 版本
- 如果版本 < 16，自动添加 NodeSource 仓库
- 安装 Node.js 18.x LTS 版本

### MySQL 配置

Ubuntu 20.04 使用 MySQL 8.0：
```bash
# 检查 MySQL 版本
mysql --version

# 如果未安装，脚本会自动安装
sudo apt-get install mysql-server
```

### Python 版本

Ubuntu 20.04 默认 Python 3.8：
```bash
# 检查 Python 版本
python3 --version

# 脚本会自动创建虚拟环境
python3 -m venv venv
```

## 📝 部署步骤详解

### 1. 系统准备

```bash
# 更新系统
sudo apt update
sudo apt upgrade -y

# 安装基础工具
sudo apt install -y curl git build-essential
```

### 2. 安装 Node.js 18.x

```bash
# 添加 NodeSource 仓库
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

# 安装 Node.js
sudo apt install -y nodejs

# 验证版本
node --version  # 应该显示 v18.x.x
npm --version
```

### 3. 安装 Python 3.8+

```bash
# Ubuntu 20.04 默认已安装 Python 3.8
python3 --version

# 安装 pip 和 venv
sudo apt install -y python3-pip python3-venv
```

### 4. 安装 MySQL 8.0

```bash
# 安装 MySQL
sudo apt install -y mysql-server

# 启动 MySQL
sudo systemctl start mysql
sudo systemctl enable mysql

# 安全配置（可选）
sudo mysql_secure_installation
```

### 5. 安装 Redis

```bash
# 安装 Redis
sudo apt install -y redis-server

# 启动 Redis
sudo systemctl start redis-server
sudo systemctl enable redis-server

# 测试 Redis
redis-cli ping  # 应该返回 PONG
```

### 6. 安装 Nginx

```bash
# 安装 Nginx
sudo apt install -y nginx

# 启动 Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# 检查状态
sudo systemctl status nginx
```

## 🎯 部署脚本功能

`deploy-cloud-server.sh` 脚本专为 Ubuntu 20.04 优化，会自动：

1. ✅ **检测系统版本** - 确认 Ubuntu 20.04
2. ✅ **安装 Node.js 18.x** - 自动配置 NodeSource 仓库
3. ✅ **安装系统依赖** - Python、MySQL、Redis、Nginx
4. ✅ **配置数据库** - 创建数据库并导入初始化脚本
5. ✅ **配置后端** - 创建虚拟环境并安装依赖
6. ✅ **构建前端** - 安装依赖并构建生产版本
7. ✅ **配置 Nginx** - 设置反向代理
8. ✅ **创建服务** - systemd 服务自动启动
9. ✅ **初始化数据** - 数据预处理和模型训练
10. ✅ **配置防火墙** - UFW 防火墙规则

## 🔍 验证部署

### 检查服务状态

```bash
# 检查后端服务
sudo systemctl status canteen-backend

# 检查 Nginx
sudo systemctl status nginx

# 检查 MySQL
sudo systemctl status mysql

# 检查 Redis
sudo systemctl status redis-server
```

### 测试服务

```bash
# 测试后端 API
curl http://localhost:5000/health

# 测试前端（通过 Nginx）
curl http://localhost/

# 从外部测试（使用公网 IP）
curl http://your-server-ip/health
```

## 🔒 防火墙配置（UFW）

Ubuntu 20.04 默认使用 UFW 防火墙：

```bash
# 检查状态
sudo ufw status

# 允许 SSH（重要！）
sudo ufw allow 22/tcp

# 允许 HTTP
sudo ufw allow 80/tcp

# 允许后端 API（可选）
sudo ufw allow 5000/tcp

# 启用防火墙
sudo ufw enable

# 查看规则
sudo ufw status verbose
```

## 📊 系统资源监控

```bash
# 查看系统资源
htop  # 或 top

# 查看磁盘使用
df -h

# 查看内存使用
free -h

# 查看服务资源占用
systemctl status canteen-backend
```

## 🐛 常见问题

### 问题1：Node.js 版本过低

**症状**: `npm install` 失败或警告

**解决**:
```bash
# 脚本会自动处理，或手动执行
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
```

### 问题2：MySQL 无法启动

**症状**: `systemctl status mysql` 显示失败

**解决**:
```bash
# 查看日志
sudo journalctl -u mysql -n 50

# 检查配置
sudo mysql -u root -p

# 重启服务
sudo systemctl restart mysql
```

### 问题3：端口被占用

**症状**: 服务启动失败，端口已被占用

**解决**:
```bash
# 查看端口占用
sudo netstat -tulpn | grep -E '5000|80|3306|6379'

# 或使用 ss
sudo ss -tulpn | grep -E '5000|80|3306|6379'

# 停止占用端口的服务
sudo systemctl stop [service-name]
```

### 问题4：权限问题

**症状**: 无法创建文件或目录

**解决**:
```bash
# 确保使用 sudo 运行部署脚本
sudo ./deploy-cloud-server.sh

# 检查目录权限
ls -la ~/GkSystem

# 修复权限（如果需要）
sudo chown -R $USER:$USER ~/GkSystem
```

## 📚 相关文档

- [云主机非Docker部署指南.md](./云主机非Docker部署指南.md) - 完整部署指南
- [云主机快速部署.md](./云主机快速部署.md) - 快速参考
- [防火墙端口配置指南.md](./防火墙端口配置指南.md) - 防火墙配置

## ✅ 部署检查清单

- [ ] Ubuntu 20.04 系统
- [ ] 系统已更新
- [ ] Node.js 18.x 已安装
- [ ] Python 3.8+ 已安装
- [ ] MySQL 8.0 已安装并运行
- [ ] Redis 已安装并运行
- [ ] Nginx 已安装并运行
- [ ] 后端服务已启动
- [ ] 前端已构建
- [ ] Nginx 配置正确
- [ ] 防火墙已配置
- [ ] 可以通过公网 IP 访问

---

**专为 Ubuntu 20.04 优化，一键完成部署！**

