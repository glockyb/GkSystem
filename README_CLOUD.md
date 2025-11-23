# 云主机非 Docker 部署快速参考

## 🎯 适用场景

当云主机无法使用 Docker 时（网络问题、权限问题等），可以直接在云主机上运行前后端服务。

## ⚡ 快速开始

### 一键部署

```bash
# 在云主机上执行
cd ~/GkSystem
sudo ./deploy-cloud-server.sh
```

### 手动部署

参考：[云主机非Docker部署指南.md](./云主机非Docker部署指南.md)

---

## 📊 架构说明

```
用户浏览器
    ↓
公网 IP:80 (HTTP)
    ↓
Nginx (反向代理)
    ├─→ / → 前端静态文件 (frontend/dist)
    └─→ /api → 后端 API (localhost:5000)
            ↓
        Flask 后端 (systemd 服务)
            ↓
        MySQL + Redis
```

---

## 🔧 关键配置

### 1. 后端配置

- **运行方式**: systemd 服务
- **监听地址**: 127.0.0.1:5000（只允许本地访问）
- **通过 Nginx 代理**: 外部访问通过 Nginx

### 2. 前端配置

- **构建方式**: `npm run build`
- **部署方式**: Nginx 静态文件服务
- **API 地址**: 使用相对路径 `/api/v1`（通过 Nginx 代理）

### 3. Nginx 配置

- **前端**: 直接提供静态文件
- **后端**: 代理 `/api/*` 到 `http://127.0.0.1:5000`

---

## 📝 端口说明

| 端口 | 服务 | 是否对外开放 |
|------|------|-------------|
| 80 | Nginx（前端+API代理） | ✅ 是 |
| 5000 | Flask 后端 | ⚠️ 可选（建议不开放） |
| 3306 | MySQL | ❌ 否 |
| 6379 | Redis | ❌ 否 |

---

## 🔄 常用操作

### 更新代码

```bash
cd ~/GkSystem
git pull

# 更新后端
cd backend
source venv/bin/activate
pip3 install -r requirements.txt
sudo systemctl restart canteen-backend

# 更新前端
cd ../frontend
npm run build
sudo systemctl reload nginx
```

### 查看日志

```bash
# 后端日志
sudo journalctl -u canteen-backend -f

# Nginx 日志
sudo tail -f /var/log/nginx/canteen-error.log
sudo tail -f /var/log/nginx/canteen-access.log
```

---

## 📚 相关文档

- [云主机非Docker部署指南.md](./云主机非Docker部署指南.md) - 完整部署指南
- [防火墙端口配置指南.md](./防火墙端口配置指南.md) - 防火墙配置
- [系统架构说明.md](./系统架构说明.md) - 系统架构

---

**部署完成后，访问 `http://your-server-ip` 即可使用系统！**

