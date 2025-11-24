# API 连接问题排查指南

## 🔍 问题描述

- ✅ 前端界面可以访问
- ❌ 前端按钮点击提示"加载失败"
- ❌ 无法注册/登录
- ❌ 后端 API 无法访问

## 🚀 立即修复

运行完整修复脚本：

```bash
cd ~/gksys/GkSystem
chmod +x fix-api-connection-complete.sh
sudo ./fix-api-connection-complete.sh
```

## 📋 手动排查步骤

### 步骤1：检查后端服务

```bash
# 检查服务状态
sudo systemctl status canteen-backend

# 如果未运行，启动
sudo systemctl start canteen-backend

# 查看日志
sudo journalctl -u canteen-backend -n 50
```

### 步骤2：测试后端 API（本地）

```bash
# 测试健康检查
curl http://localhost:5000/health

# 应该返回: {"status":"healthy"}
```

### 步骤3：检查 Nginx API 代理

```bash
# 查看配置
sudo cat /etc/nginx/sites-available/canteen | grep -A 10 "location /api"

# 应该包含：
# location /api {
#     proxy_pass http://127.0.0.1:5000/api;
#     ...
# }
```

### 步骤4：测试 API 代理

```bash
# 测试通过 Nginx 代理访问
curl http://localhost/api/v1/

# 或测试健康检查
curl http://localhost/api/v1/health
```

### 步骤5：检查浏览器控制台

在浏览器中：
1. 按 F12 打开开发者工具
2. 切换到 Network 标签
3. 尝试注册/登录
4. 查看失败的请求
5. 查看 Console 标签的错误信息

## 🔧 常见问题和解决方案

### 问题1：Nginx API 代理配置缺失

**症状：** 前端请求返回 404

**解决：**
```bash
# 编辑配置
sudo nano /etc/nginx/sites-available/canteen

# 确保包含：
location /api {
    proxy_pass http://127.0.0.1:5000/api;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

# 测试并重启
sudo nginx -t
sudo systemctl restart nginx
```

### 问题2：后端服务未运行

**症状：** API 请求返回 502 Bad Gateway

**解决：**
```bash
# 启动后端服务
sudo systemctl start canteen-backend

# 检查状态
sudo systemctl status canteen-backend

# 查看日志
sudo journalctl -u canteen-backend -f
```

### 问题3：前端使用了错误的 API 地址

**症状：** 浏览器控制台显示连接错误

**解决：**
```bash
# 重新构建前端（不使用环境变量）
cd ~/gksys/GkSystem/frontend

# 确保没有设置 VITE_API_URL
unset VITE_API_URL

# 重新构建
npm run build

# 重新部署
sudo cp -r dist/* /var/www/canteen/
sudo chown -R www-data:www-data /var/www/canteen
sudo systemctl reload nginx
```

### 问题4：CORS 问题

**症状：** 浏览器控制台显示 CORS 错误

**解决：**
检查后端 CORS 配置（应该已经配置）：
```python
# backend/app.py
CORS(app, resources={r"/api/*": {"origins": "*"}})
```

## 🔍 实时调试

### 方法1：查看 Nginx 访问日志

```bash
# 实时查看访问日志
sudo tail -f /var/log/nginx/canteen-access.log

# 在浏览器中操作，观察日志输出
```

### 方法2：查看后端日志

```bash
# 实时查看后端日志
sudo journalctl -u canteen-backend -f

# 在浏览器中操作，观察日志输出
```

### 方法3：浏览器开发者工具

1. 打开浏览器开发者工具（F12）
2. Network 标签：查看所有请求
3. Console 标签：查看 JavaScript 错误
4. 尝试注册/登录，观察错误

## 📊 测试检查清单

- [ ] 后端服务运行中
- [ ] 后端 API 可访问（localhost:5000）
- [ ] Nginx API 代理配置正确
- [ ] API 代理可访问（localhost/api/v1/）
- [ ] 前端使用相对路径（/api/v1/）
- [ ] 防火墙允许 80 端口
- [ ] 浏览器控制台无错误

## 🚀 快速修复命令

```bash
# 1. 确保后端运行
sudo systemctl restart canteen-backend

# 2. 检查 Nginx 配置
sudo nginx -t

# 3. 重启 Nginx
sudo systemctl restart nginx

# 4. 测试
curl http://localhost/api/v1/health
curl http://localhost/
```

## 📚 相关脚本

- `fix-api-connection-complete.sh` - 完整修复脚本
- `fix-api-connection.sh` - 基础修复脚本

---

**先运行修复脚本，然后检查浏览器控制台的错误信息！**

