# 修复 API 连接问题

## 🔍 问题描述

前端尝试直接访问 `http://119.3.232.65:5000/api/v1/register`，导致 `ERR_CONNECTION_REFUSED` 错误。

**原因：** 前端构建时设置了 `VITE_API_URL` 环境变量，导致使用绝对 URL 而不是相对路径。

## 🚀 立即修复

在服务器上运行：

```bash
cd ~/gksys/GkSystem
chmod +x fix-frontend-api-url.sh
sudo ./fix-frontend-api-url.sh
```

这个脚本会：
1. 清除 `VITE_API_URL` 环境变量
2. 重新构建前端（使用相对路径）
3. 部署到 `/var/www/canteen`
4. 重新加载 Nginx

## 📋 手动修复步骤

如果脚本无法运行，手动执行：

```bash
cd ~/gksys/GkSystem/frontend

# 1. 清除环境变量
unset VITE_API_URL
export VITE_API_URL=""

# 2. 删除旧的 .env.production 文件（如果存在）
rm -f .env.production

# 3. 清理旧构建
rm -rf dist

# 4. 重新构建
npm run build

# 5. 部署
sudo rm -rf /var/www/canteen/*
sudo cp -r dist/* /var/www/canteen/
sudo chown -R www-data:www-data /var/www/canteen
sudo chmod -R 755 /var/www/canteen

# 6. 重新加载 Nginx
sudo systemctl reload nginx
```

## ✅ 验证修复

1. **清除浏览器缓存**
   - Windows/Linux: `Ctrl + Shift + Delete`
   - Mac: `Cmd + Shift + Delete`
   - 或强制刷新: `Ctrl + F5` / `Cmd + Shift + R`

2. **打开浏览器开发者工具 (F12)**
   - 切换到 Network 标签
   - 尝试注册/登录
   - 查看请求 URL

3. **正确的请求 URL 应该是：**
   - ✅ `http://119.3.232.65/api/v1/register`（通过 Nginx 代理）
   - ❌ `http://119.3.232.65:5000/api/v1/register`（直接访问，错误）

## 🔧 为什么使用相对路径？

1. **安全性：** 后端不需要对外开放 5000 端口
2. **灵活性：** 更换域名/IP 时不需要重新构建前端
3. **标准实践：** 通过 Nginx 反向代理是标准做法

## 📊 架构说明

```
浏览器
  ↓
http://119.3.232.65/api/v1/register
  ↓
Nginx (端口 80)
  ↓
proxy_pass http://127.0.0.1:5000/api
  ↓
后端 Flask (端口 5000，仅本地访问)
```

## 🐛 如果问题仍然存在

1. **检查浏览器控制台**
   - 按 F12 打开开发者工具
   - 查看 Console 和 Network 标签
   - 截图错误信息

2. **检查 Nginx 日志**
   ```bash
   sudo tail -f /var/log/nginx/canteen-access.log
   sudo tail -f /var/log/nginx/canteen-error.log
   ```

3. **检查后端服务**
   ```bash
   sudo systemctl status canteen-backend
   curl http://localhost:5000/health
   ```

4. **检查 Nginx 配置**
   ```bash
   sudo cat /etc/nginx/sites-available/canteen | grep -A 10 "location /api"
   ```

## 📚 相关脚本

- `fix-frontend-api-url.sh` - 修复前端 API URL
- `fix-api-connection-complete.sh` - 完整 API 连接修复

---

**运行修复脚本后，清除浏览器缓存并重新测试！**

