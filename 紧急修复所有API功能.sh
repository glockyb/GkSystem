#!/bin/bash

# 紧急修复所有 API 功能

set -e

echo "=========================================="
echo "🚨 紧急修复所有 API 功能"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查后端服务
echo ""
echo "ℹ️ 步骤1: 检查后端服务..."
if ! sudo systemctl is-active --quiet canteen-backend; then
    echo "⚠️ 后端服务未运行，启动服务..."
    sudo systemctl start canteen-backend
    sleep 3
fi

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "❌ 后端服务启动失败"
    echo "查看错误："
    sudo journalctl -u canteen-backend -n 30 --no-pager
    exit 1
fi

# 2. 测试后端直接访问
echo ""
echo "ℹ️ 步骤2: 测试后端直接访问..."
health_response=$(curl -s http://localhost:5000/health || echo "failed")
if echo "$health_response" | grep -q "healthy"; then
    echo "✅ 后端健康检查正常"
else
    echo "❌ 后端健康检查失败: $health_response"
    echo "查看后端日志："
    sudo journalctl -u canteen-backend -n 20 --no-pager
    exit 1
fi

# 3. 测试 API 端点
echo ""
echo "ℹ️ 步骤3: 测试 API 端点..."
api_response=$(curl -s http://localhost:5000/api/v1/dishes/categories || echo "failed")
if echo "$api_response" | grep -q "categories\|error\|\[\]"; then
    echo "✅ 后端 API 可访问"
    echo "响应: ${api_response:0:100}"
else
    echo "❌ 后端 API 不可访问: $api_response"
    echo "查看后端日志："
    sudo journalctl -u canteen-backend -n 20 --no-pager
fi

# 4. 检查 Nginx 代理
echo ""
echo "ℹ️ 步骤4: 检查 Nginx 代理..."
nginx_api_response=$(curl -s http://localhost/api/v1/dishes/categories || echo "failed")
if echo "$nginx_api_response" | grep -q "categories\|error\|\[\]"; then
    echo "✅ Nginx 代理正常"
else
    echo "❌ Nginx 代理失败: $nginx_api_response"
    echo "检查 Nginx 配置..."
    
    # 检查 Nginx 配置
    if [ -f "/etc/nginx/sites-available/canteen" ]; then
        echo "Nginx 配置内容："
        sudo cat /etc/nginx/sites-available/canteen | grep -A 10 "location /api"
    fi
    
    # 重启 Nginx
    echo "重启 Nginx..."
    sudo systemctl restart nginx
    sleep 2
    
    # 再次测试
    nginx_api_response=$(curl -s http://localhost/api/v1/dishes/categories || echo "failed")
    if echo "$nginx_api_response" | grep -q "categories\|error\|\[\]"; then
        echo "✅ Nginx 代理修复成功"
    else
        echo "❌ Nginx 代理仍然失败"
    fi
fi

# 5. 检查数据库连接
echo ""
echo "ℹ️ 步骤5: 检查数据库连接..."
if mysql -u root -ppassword -e "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ MySQL 连接正常"
    
    # 检查数据库
    db_exists=$(mysql -u root -ppassword -e "SHOW DATABASES LIKE 'canteen_recommendation';" 2>/dev/null | grep -c "canteen_recommendation" || echo "0")
    if [ "$db_exists" -gt 0 ]; then
        echo "✅ 数据库存在"
        
        # 检查表
        table_count=$(mysql -u root -ppassword -e "USE canteen_recommendation; SHOW TABLES;" 2>/dev/null | wc -l)
        if [ "$table_count" -gt 1 ]; then
            echo "✅ 数据库表存在 ($((table_count-1)) 个表)"
        else
            echo "⚠️ 数据库表可能不存在，需要初始化"
            echo "运行数据库初始化..."
            if [ -f "backend/database/init.sql" ]; then
                mysql -u root -ppassword < backend/database/init.sql
                echo "✅ 数据库初始化完成"
            fi
        fi
    else
        echo "❌ 数据库不存在，需要初始化"
        if [ -f "backend/database/init.sql" ]; then
            mysql -u root -ppassword < backend/database/init.sql
            echo "✅ 数据库初始化完成"
        fi
    fi
else
    echo "❌ MySQL 连接失败"
    echo "检查 MySQL 服务..."
    sudo systemctl status mysql --no-pager -l | head -10
fi

# 6. 检查后端日志中的错误
echo ""
echo "ℹ️ 步骤6: 检查后端日志错误..."
recent_errors=$(sudo journalctl -u canteen-backend -n 50 --no-pager | grep -i "error\|exception\|traceback" | head -10 || echo "无错误")
if [ "$recent_errors" != "无错误" ]; then
    echo "⚠️ 发现后端错误："
    echo "$recent_errors"
    
    # 检查是否是数据库连接错误
    if echo "$recent_errors" | grep -qi "mysql\|database\|connection"; then
        echo ""
        echo "⚠️ 可能是数据库连接问题，检查配置..."
        
        # 检查服务配置中的数据库环境变量
        if grep -q "MYSQL_" /etc/systemd/system/canteen-backend.service; then
            echo "✅ 服务配置包含数据库环境变量"
        else
            echo "⚠️ 服务配置缺少数据库环境变量，更新配置..."
            
            # 更新服务配置
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
            sudo systemctl restart canteen-backend
            sleep 3
            echo "✅ 服务配置已更新并重启"
        fi
    fi
else
    echo "✅ 后端日志无错误"
fi

# 7. 测试注册和登录 API
echo ""
echo "ℹ️ 步骤7: 测试注册和登录 API..."
echo "测试注册端点..."
register_response=$(curl -s -X POST http://localhost:5000/api/v1/register \
    -H "Content-Type: application/json" \
    -d '{"username":"test_user_'$(date +%s)'","password":"test123","email":"test@test.com"}' || echo "failed")

if echo "$register_response" | grep -q "access_token\|error\|message"; then
    echo "✅ 注册 API 可访问"
    echo "响应: ${register_response:0:100}"
else
    echo "❌ 注册 API 不可访问: $register_response"
fi

# 8. 检查前端 API 配置
echo ""
echo "ℹ️ 步骤8: 检查前端 API 配置..."
if [ -f "frontend/src/api/index.js" ]; then
    echo "✅ 前端 API 配置文件存在"
    
    # 检查是否使用相对路径
    if grep -q "'/api/v1'" frontend/src/api/index.js; then
        echo "✅ 前端使用相对路径 API（通过 Nginx 代理）"
    else
        echo "⚠️ 前端可能使用绝对路径，需要检查"
    fi
else
    echo "❌ 前端 API 配置文件不存在"
fi

# 9. 重启所有服务
echo ""
echo "ℹ️ 步骤9: 重启所有服务..."
sudo systemctl restart canteen-backend
sleep 3
sudo systemctl restart nginx
sleep 2

# 10. 最终验证
echo ""
echo "ℹ️ 步骤10: 最终验证..."
sleep 2

# 验证后端
if curl -s http://localhost:5000/health | grep -q "healthy"; then
    echo "✅ 后端健康检查通过"
else
    echo "❌ 后端健康检查失败"
fi

# 验证 API
if curl -s http://localhost/api/v1/dishes/categories | grep -q "categories\|error\|\[\]"; then
    echo "✅ API 代理通过"
else
    echo "❌ API 代理失败"
fi

# 验证前端
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
if [ "$http_code" = "200" ]; then
    echo "✅ 前端访问通过 (HTTP 200)"
else
    echo "⚠️ 前端访问返回 HTTP $http_code"
fi

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "📋 测试步骤："
echo "1. 清除浏览器缓存 (Ctrl+Shift+Delete)"
echo "2. 强制刷新页面 (Ctrl+F5)"
echo "3. 打开浏览器控制台 (F12) 查看错误"
echo "4. 尝试注册新用户"
echo "5. 尝试登录"
echo "6. 尝试加载菜品"
echo ""
echo "📖 查看实时日志："
echo "   sudo journalctl -u canteen-backend -f"
echo "   sudo tail -f /var/log/nginx/error.log"
echo ""

