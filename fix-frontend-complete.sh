#!/bin/bash

# 完整修复前端问题

set -e

echo "=========================================="
echo "🔧 完整修复前端问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查前端构建目录
echo ""
echo "ℹ️ 步骤1: 检查前端构建..."
if [ ! -d "frontend/dist" ] || [ -z "$(ls -A frontend/dist 2>/dev/null)" ]; then
    echo "⚠️ 前端未构建，开始构建..."
    cd frontend
    
    # 清除可能的环境变量
    unset VITE_API_URL
    
    # 检查 node_modules
    if [ ! -d "node_modules" ]; then
        echo "安装依赖..."
        npm install
    fi
    
    # 构建前端
    echo "构建前端..."
    npm run build
    
    if [ ! -d "dist" ] || [ -z "$(ls -A dist 2>/dev/null)" ]; then
        echo "❌ 前端构建失败"
        exit 1
    fi
    
    cd ..
    echo "✅ 前端构建完成"
else
    echo "✅ 前端已构建"
fi

# 2. 备份现有文件（可选）
echo ""
echo "ℹ️ 步骤2: 备份现有文件..."
if [ -d "/var/www/canteen" ] && [ -n "$(ls -A /var/www/canteen 2>/dev/null)" ]; then
    backup_dir="/var/www/canteen.backup.$(date +%Y%m%d_%H%M%S)"
    echo "备份到: $backup_dir"
    sudo cp -r /var/www/canteen "$backup_dir" || echo "备份失败，继续..."
fi

# 3. 部署前端文件
echo ""
echo "ℹ️ 步骤3: 部署前端文件..."
sudo rm -rf /var/www/canteen/*
sudo cp -r frontend/dist/* /var/www/canteen/
sudo chown -R www-data:www-data /var/www/canteen
sudo chmod -R 755 /var/www/canteen

# 验证部署
if [ -f "/var/www/canteen/index.html" ]; then
    echo "✅ 前端文件部署成功"
    file_count=$(sudo find /var/www/canteen -type f | wc -l)
    echo "   部署文件数: $file_count"
else
    echo "❌ 前端文件部署失败"
    exit 1
fi

# 4. 检查 Nginx 配置
echo ""
echo "ℹ️ 步骤4: 检查 Nginx 配置..."
if [ ! -f "/etc/nginx/sites-available/canteen" ]; then
    echo "❌ Nginx 配置文件不存在，创建配置..."
    sudo tee /etc/nginx/sites-available/canteen > /dev/null <<EOF
server {
    listen 80;
    server_name _;
    
    access_log /var/log/nginx/canteen-access.log;
    error_log /var/log/nginx/canteen-error.log;
    
    root /var/www/canteen;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://127.0.0.1:5000/api;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        proxy_set_header Host \$host;
    }
}
EOF
    
    # 启用站点
    if [ ! -L "/etc/nginx/sites-enabled/canteen" ]; then
        sudo ln -s /etc/nginx/sites-available/canteen /etc/nginx/sites-enabled/
    fi
    
    # 删除默认站点（如果存在）
    if [ -L "/etc/nginx/sites-enabled/default" ]; then
        sudo rm /etc/nginx/sites-enabled/default
    fi
fi

# 测试 Nginx 配置
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "✅ Nginx 配置正确"
else
    echo "❌ Nginx 配置错误"
    sudo nginx -t
    exit 1
fi

# 5. 重启服务
echo ""
echo "ℹ️ 步骤5: 重启服务..."
sudo systemctl restart canteen-backend
sleep 2
sudo systemctl reload nginx
sleep 1

# 6. 验证服务状态
echo ""
echo "ℹ️ 步骤6: 验证服务状态..."
if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "❌ 后端服务未运行"
    sudo systemctl status canteen-backend --no-pager -l
fi

if sudo systemctl is-active --quiet nginx; then
    echo "✅ Nginx 服务运行中"
else
    echo "❌ Nginx 服务未运行"
    sudo systemctl status nginx --no-pager -l
fi

# 7. 测试访问
echo ""
echo "ℹ️ 步骤7: 测试访问..."
sleep 2

# 测试前端
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
if [ "$http_code" = "200" ]; then
    echo "✅ 前端访问正常 (HTTP 200)"
else
    echo "⚠️ 前端访问返回 HTTP $http_code"
fi

# 测试 API
api_response=$(curl -s http://localhost/api/v1/dishes/categories)
if echo "$api_response" | grep -q "categories\|error\|\[\]"; then
    echo "✅ API 可访问"
else
    echo "⚠️ API 响应异常"
    echo "   响应: ${api_response:0:100}"
fi

# 8. 显示访问信息
echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "📱 访问地址："
echo "   前端: http://$(hostname -I | awk '{print $1}')"
echo "   或: http://localhost"
echo ""
echo "📋 如果仍有问题，请检查："
echo "1. 浏览器控制台错误 (F12)"
echo "2. Nginx 错误日志: sudo tail -f /var/log/nginx/error.log"
echo "3. 后端日志: sudo journalctl -u canteen-backend -f"
echo "4. 防火墙设置: sudo ufw status"
echo ""

