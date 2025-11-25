#!/bin/bash

# 紧急诊断所有功能问题

set -e

echo "=========================================="
echo "🚨 紧急诊断所有功能"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查服务状态
echo ""
echo "ℹ️ 步骤1: 检查所有服务状态..."
services_ok=true

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "❌ 后端服务未运行"
    services_ok=false
    echo "尝试启动..."
    sudo systemctl start canteen-backend
    sleep 2
    if sudo systemctl is-active --quiet canteen-backend; then
        echo "✅ 后端服务已启动"
    else
        echo "❌ 后端服务启动失败"
        sudo systemctl status canteen-backend --no-pager -l | head -20
    fi
fi

if sudo systemctl is-active --quiet nginx; then
    echo "✅ Nginx 运行中"
else
    echo "❌ Nginx 未运行"
    services_ok=false
    sudo systemctl start nginx
fi

# 2. 检查前端文件
echo ""
echo "ℹ️ 步骤2: 检查前端文件..."
if [ -f "/var/www/canteen/index.html" ]; then
    index_size=$(sudo stat -c%s /var/www/canteen/index.html)
    echo "✅ index.html 存在 (${index_size} 字节)"
    
    if [ -d "/var/www/canteen/assets" ]; then
        js_count=$(sudo find /var/www/canteen/assets -name "*.js" | wc -l)
        css_count=$(sudo find /var/www/canteen/assets -name "*.css" | wc -l)
        echo "✅ assets 目录存在"
        echo "   JS 文件: $js_count"
        echo "   CSS 文件: $css_count"
        
        if [ "$js_count" -eq 0 ]; then
            echo "❌ 没有 JS 文件，前端无法工作"
            echo "需要重新构建前端"
        fi
    else
        echo "❌ assets 目录不存在"
    fi
else
    echo "❌ index.html 不存在"
fi

# 3. 检查文件权限
echo ""
echo "ℹ️ 步骤3: 检查文件权限..."
owner=$(sudo stat -c '%U:%G' /var/www/canteen 2>/dev/null || echo "unknown")
if [ "$owner" = "www-data:www-data" ]; then
    echo "✅ 文件权限正确"
else
    echo "⚠️ 文件权限可能不正确: $owner"
    echo "修复权限..."
    sudo chown -R www-data:www-data /var/www/canteen
    sudo chmod -R 755 /var/www/canteen
fi

# 4. 测试本地访问
echo ""
echo "ℹ️ 步骤4: 测试本地访问..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
if [ "$http_code" = "200" ]; then
    echo "✅ 前端访问正常 (HTTP 200)"
    
    # 检查页面内容
    page_content=$(curl -s http://localhost/ | head -c 1000)
    if echo "$page_content" | grep -q "app\|vue\|script"; then
        echo "✅ 页面内容正常"
    else
        echo "⚠️ 页面内容异常"
        echo "页面开头："
        echo "$page_content" | head -20
    fi
else
    echo "❌ 前端访问失败 (HTTP $http_code)"
fi

# 5. 测试 API
echo ""
echo "ℹ️ 步骤5: 测试后端 API..."
api_endpoints=(
    "/health"
    "/api/v1/dishes/categories"
)

for endpoint in "${api_endpoints[@]}"; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost$endpoint" || echo "000")
    if [ "$response" = "200" ] || [ "$response" = "401" ]; then
        echo "✅ $endpoint 可访问 (HTTP $response)"
    else
        echo "❌ $endpoint 不可访问 (HTTP $response)"
        
        # 尝试直接访问后端
        if [ "$endpoint" = "/health" ]; then
            backend_response=$(curl -s "http://localhost:5000/health" || echo "failed")
            if echo "$backend_response" | grep -q "healthy"; then
                echo "   ⚠️ 后端直接访问正常，可能是 Nginx 代理问题"
            else
                echo "   ❌ 后端直接访问也失败"
            fi
        fi
    fi
done

# 6. 检查 Nginx 配置
echo ""
echo "ℹ️ 步骤6: 检查 Nginx 配置..."
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "✅ Nginx 配置正确"
else
    echo "❌ Nginx 配置错误"
    sudo nginx -t
fi

# 7. 检查 Nginx 错误日志
echo ""
echo "ℹ️ 步骤7: 检查 Nginx 错误日志（最近10行）..."
if [ -f "/var/log/nginx/error.log" ]; then
    recent_errors=$(sudo tail -10 /var/log/nginx/error.log | grep -v "^$" || echo "无错误")
    if [ "$recent_errors" != "无错误" ]; then
        echo "⚠️ 发现错误："
        echo "$recent_errors"
    else
        echo "✅ 无错误日志"
    fi
fi

# 8. 检查后端日志
echo ""
echo "ℹ️ 步骤8: 检查后端日志（最近10行）..."
recent_backend_logs=$(sudo journalctl -u canteen-backend -n 10 --no-pager 2>/dev/null || echo "无法获取日志")
if echo "$recent_backend_logs" | grep -qi "error\|exception\|traceback"; then
    echo "⚠️ 发现后端错误："
    echo "$recent_backend_logs" | grep -i "error\|exception\|traceback" | head -5
else
    echo "✅ 后端日志正常"
fi

# 9. 检查数据库连接
echo ""
echo "ℹ️ 步骤9: 检查数据库连接..."
if mysql -u root -ppassword -e "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ MySQL 连接正常"
    
    # 检查数据库和表
    db_exists=$(mysql -u root -ppassword -e "SHOW DATABASES LIKE 'canteen_recommendation';" 2>/dev/null | grep -c "canteen_recommendation" || echo "0")
    if [ "$db_exists" -gt 0 ]; then
        echo "✅ 数据库存在"
        
        table_count=$(mysql -u root -ppassword -e "USE canteen_recommendation; SHOW TABLES;" 2>/dev/null | wc -l)
        if [ "$table_count" -gt 1 ]; then
            echo "✅ 数据库表存在 ($((table_count-1)) 个表)"
        else
            echo "⚠️ 数据库表可能不存在"
        fi
    else
        echo "❌ 数据库不存在"
    fi
else
    echo "❌ MySQL 连接失败"
fi

# 10. 快速修复建议
echo ""
echo "=========================================="
echo "📋 诊断结果和建议"
echo "=========================================="

if [ "$services_ok" = false ]; then
    echo ""
    echo "⚠️ 发现服务问题，建议执行："
    echo "  sudo systemctl restart canteen-backend"
    echo "  sudo systemctl restart nginx"
fi

echo ""
echo "📋 如果前端无法加载，尝试："
echo "1. 重新构建前端："
echo "   cd ~/gksys/GkSystem/frontend"
echo "   rm -rf dist node_modules/.vite"
echo "   npm run build"
echo "   cd .."
echo "   sudo rm -rf /var/www/canteen/*"
echo "   sudo cp -r frontend/dist/* /var/www/canteen/"
echo "   sudo chown -R www-data:www-data /var/www/canteen"
echo ""
echo "2. 重启所有服务："
echo "   sudo systemctl restart canteen-backend"
echo "   sudo systemctl restart nginx"
echo ""
echo "3. 清除浏览器缓存并强制刷新 (Ctrl+Shift+Delete, Ctrl+F5)"
echo ""
echo "4. 查看实时日志："
echo "   sudo journalctl -u canteen-backend -f"
echo "   sudo tail -f /var/log/nginx/error.log"
echo ""

