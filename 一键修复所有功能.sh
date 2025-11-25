#!/bin/bash

# 一键修复所有功能

set -e

echo "=========================================="
echo "🔧 一键修复所有功能"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 停止所有服务
echo ""
echo "ℹ️ 步骤1: 停止所有服务..."
sudo systemctl stop canteen-backend 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true
sleep 1

# 2. 重新构建前端
echo ""
echo "ℹ️ 步骤2: 重新构建前端..."
cd frontend

# 清除缓存
rm -rf dist node_modules/.vite .vite

# 确保依赖完整
if [ ! -d "node_modules" ] || [ ! -d "node_modules/vue" ]; then
    echo "安装依赖..."
    npm install
fi

# 清除环境变量并构建
unset VITE_API_URL
export NODE_ENV=production
npm run build

# 验证构建
if [ ! -d "dist" ] || [ ! -f "dist/index.html" ]; then
    echo "❌ 前端构建失败"
    exit 1
fi

js_files=$(find dist/assets -name "*.js" 2>/dev/null | wc -l)
if [ "$js_files" -eq 0 ]; then
    echo "❌ 构建后没有 JS 文件"
    exit 1
fi

echo "✅ 前端构建成功 (JS 文件: $js_files)"
cd ..

# 3. 部署前端
echo ""
echo "ℹ️ 步骤3: 部署前端..."
sudo rm -rf /var/www/canteen/*
sudo cp -r frontend/dist/* /var/www/canteen/
sudo chown -R www-data:www-data /var/www/canteen
sudo chmod -R 755 /var/www/canteen

# 验证部署
if [ ! -f "/var/www/canteen/index.html" ]; then
    echo "❌ 前端部署失败"
    exit 1
fi
echo "✅ 前端部署成功"

# 4. 检查并修复 Nginx 配置
echo ""
echo "ℹ️ 步骤4: 检查 Nginx 配置..."
if [ ! -f "/etc/nginx/sites-available/canteen" ]; then
    echo "创建 Nginx 配置..."
    sudo tee /etc/nginx/sites-available/canteen > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;
    
    access_log /var/log/nginx/canteen-access.log;
    error_log /var/log/nginx/canteen-error.log;
    
    root /var/www/canteen;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://127.0.0.1:5000/api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        proxy_set_header Host $host;
    }
}
EOF
    
    if [ ! -L "/etc/nginx/sites-enabled/canteen" ]; then
        sudo ln -s /etc/nginx/sites-available/canteen /etc/nginx/sites-enabled/
    fi
    
    if [ -L "/etc/nginx/sites-enabled/default" ]; then
        sudo rm /etc/nginx/sites-enabled/default
    fi
fi

# 测试 Nginx 配置
if ! sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "❌ Nginx 配置错误"
    sudo nginx -t
    exit 1
fi
echo "✅ Nginx 配置正确"

# 5. 检查后端服务配置
echo ""
echo "ℹ️ 步骤5: 检查后端服务配置..."
if [ ! -f "/etc/systemd/system/canteen-backend.service" ]; then
    echo "创建后端服务配置..."
    sudo tee /etc/systemd/system/canteen-backend.service > /dev/null <<EOF
[Unit]
Description=Canteen Recommendation Backend
After=network.target mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=$(pwd)/backend
Environment="PATH=$(pwd)/venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="MYSQL_HOST=localhost"
Environment="MYSQL_PORT=3306"
Environment="MYSQL_USER=root"
Environment="MYSQL_PASSWORD=password"
Environment="MYSQL_DATABASE=canteen_recommendation"
Environment="FLASK_HOST=127.0.0.1"
Environment="FLASK_PORT=5000"
ExecStart=$(pwd)/venv/bin/python3 $(pwd)/backend/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
fi

# 6. 启动所有服务
echo ""
echo "ℹ️ 步骤6: 启动所有服务..."
sudo systemctl start canteen-backend
sleep 3

if ! sudo systemctl is-active --quiet canteen-backend; then
    echo "❌ 后端服务启动失败"
    sudo systemctl status canteen-backend --no-pager -l | head -20
    exit 1
fi
echo "✅ 后端服务启动成功"

sudo systemctl start nginx
sleep 1

if ! sudo systemctl is-active --quiet nginx; then
    echo "❌ Nginx 启动失败"
    sudo systemctl status nginx --no-pager -l | head -20
    exit 1
fi
echo "✅ Nginx 启动成功"

# 7. 启用自动启动
echo ""
echo "ℹ️ 步骤7: 启用自动启动..."
sudo systemctl enable canteen-backend
sudo systemctl enable nginx
echo "✅ 自动启动已启用"

# 8. 验证所有功能
echo ""
echo "ℹ️ 步骤8: 验证所有功能..."
sleep 2

# 测试前端
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
if [ "$http_code" = "200" ]; then
    echo "✅ 前端访问正常 (HTTP 200)"
else
    echo "⚠️ 前端访问返回 HTTP $http_code"
fi

# 测试后端健康检查
health_response=$(curl -s http://localhost:5000/health || echo "failed")
if echo "$health_response" | grep -q "healthy"; then
    echo "✅ 后端健康检查正常"
else
    echo "⚠️ 后端健康检查异常: $health_response"
fi

# 测试 API
api_response=$(curl -s http://localhost/api/v1/dishes/categories || echo "failed")
if echo "$api_response" | grep -q "categories\|error\|\[\]"; then
    echo "✅ API 可访问"
else
    echo "⚠️ API 响应异常: ${api_response:0:100}"
fi

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "📱 访问地址："
echo "   http://$(hostname -I | awk '{print $1}')"
echo ""
echo "📋 如果仍有问题："
echo "1. 清除浏览器缓存 (Ctrl+Shift+Delete)"
echo "2. 强制刷新 (Ctrl+F5)"
echo "3. 查看浏览器控制台 (F12)"
echo "4. 查看日志："
echo "   sudo journalctl -u canteen-backend -f"
echo "   sudo tail -f /var/log/nginx/error.log"
echo ""

