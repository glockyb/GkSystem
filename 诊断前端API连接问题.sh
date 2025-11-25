#!/bin/bash

# 诊断前端 API 连接问题

set -e

echo "=========================================="
echo "🔍 诊断前端 API 连接问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查前端构建文件
echo ""
echo "ℹ️ 步骤1: 检查前端构建文件..."
if [ -f "/var/www/canteen/index.html" ]; then
    echo "✅ index.html 存在"
    
    # 检查 index.html 内容
    echo "检查 index.html 中的脚本引用..."
    if sudo grep -q "assets.*\.js" /var/www/canteen/index.html; then
        echo "✅ 找到 JS 文件引用"
        sudo grep -o 'src="[^"]*\.js"' /var/www/canteen/index.html | head -3
    else
        echo "❌ 未找到 JS 文件引用"
        echo "index.html 内容："
        sudo head -30 /var/www/canteen/index.html
    fi
    
    # 检查 assets 目录
    if [ -d "/var/www/canteen/assets" ]; then
        js_files=$(sudo find /var/www/canteen/assets -name "*.js" | wc -l)
        css_files=$(sudo find /var/www/canteen/assets -name "*.css" | wc -l)
        echo "✅ assets 目录存在"
        echo "   JS 文件: $js_files"
        echo "   CSS 文件: $css_files"
        
        if [ "$js_files" -gt 0 ]; then
            echo "JS 文件列表："
            sudo ls -lh /var/www/canteen/assets/*.js | head -5
        else
            echo "❌ 没有 JS 文件"
        fi
    else
        echo "❌ assets 目录不存在"
    fi
else
    echo "❌ index.html 不存在"
fi

# 2. 检查前端 API 配置
echo ""
echo "ℹ️ 步骤2: 检查前端 API 配置..."
if [ -f "frontend/src/api/index.js" ]; then
    echo "✅ API 配置文件存在"
    
    # 检查 API baseURL
    if grep -q "baseURL.*'/api/v1'" frontend/src/api/index.js || grep -q "baseURL.*getApiBaseURL" frontend/src/api/index.js; then
        echo "✅ API 使用相对路径（通过 Nginx 代理）"
    else
        echo "⚠️ API 配置可能有问题"
        echo "API 配置内容："
        grep -A 5 "baseURL\|create\|axios" frontend/src/api/index.js | head -10
    fi
    
    # 检查是否有硬编码的 API URL
    if grep -q "http://.*:5000" frontend/src/api/index.js; then
        echo "⚠️ 发现硬编码的 API URL，可能有问题"
        grep "http://.*:5000" frontend/src/api/index.js
    fi
else
    echo "❌ API 配置文件不存在"
fi

# 3. 检查构建后的 JS 文件中的 API 配置
echo ""
echo "ℹ️ 步骤3: 检查构建后的 JS 文件..."
if [ -d "/var/www/canteen/assets" ]; then
    main_js=$(sudo find /var/www/canteen/assets -name "*.js" | head -1)
    if [ -n "$main_js" ]; then
        echo "检查主 JS 文件: $main_js"
        
        # 检查是否包含 API URL
        if sudo grep -q "/api/v1" "$main_js"; then
            echo "✅ JS 文件中包含 /api/v1"
        else
            echo "⚠️ JS 文件中未找到 /api/v1"
        fi
        
        # 检查是否有硬编码的 localhost:5000
        if sudo grep -q "localhost:5000\|127.0.0.1:5000" "$main_js"; then
            echo "⚠️ JS 文件中包含硬编码的 localhost:5000，这可能导致问题"
            sudo grep -o "localhost:5000\|127.0.0.1:5000" "$main_js" | head -3
        fi
    fi
fi

# 4. 测试 API 访问
echo ""
echo "ℹ️ 步骤4: 测试 API 访问..."
echo "测试后端直接访问："
backend_response=$(curl -s http://localhost:5000/api/v1/dishes/categories || echo "failed")
if echo "$backend_response" | grep -q "categories\|error\|\[\]"; then
    echo "✅ 后端 API 正常: ${backend_response:0:100}"
else
    echo "❌ 后端 API 异常: $backend_response"
fi

echo ""
echo "测试通过 Nginx 代理访问："
nginx_response=$(curl -s http://localhost/api/v1/dishes/categories || echo "failed")
if echo "$nginx_response" | grep -q "categories\|error\|\[\]"; then
    echo "✅ Nginx 代理正常: ${nginx_response:0:100}"
else
    echo "❌ Nginx 代理异常: $nginx_response"
    echo "检查 Nginx 配置..."
    sudo cat /etc/nginx/sites-available/canteen | grep -A 5 "location /api"
fi

# 5. 检查 Nginx 配置
echo ""
echo "ℹ️ 步骤5: 检查 Nginx 配置..."
if [ -f "/etc/nginx/sites-available/canteen" ]; then
    echo "✅ Nginx 配置文件存在"
    
    # 检查 API 代理配置
    if sudo grep -q "location /api" /etc/nginx/sites-available/canteen; then
        echo "✅ API 代理配置存在"
        echo "API 代理配置："
        sudo grep -A 10 "location /api" /etc/nginx/sites-available/canteen
    else
        echo "❌ API 代理配置不存在"
    fi
else
    echo "❌ Nginx 配置文件不存在"
fi

# 6. 检查 CORS 配置
echo ""
echo "ℹ️ 步骤6: 检查 CORS 配置..."
if [ -f "backend/app.py" ]; then
    if grep -q "CORS\|cors" backend/app.py; then
        echo "✅ CORS 已配置"
        grep -A 2 "CORS\|cors" backend/app.py
    else
        echo "⚠️ CORS 可能未配置"
    fi
fi

# 7. 检查浏览器可能的问题
echo ""
echo "ℹ️ 步骤7: 浏览器问题排查建议..."
echo "如果后端和 Nginx 都正常，问题可能在前端代码或浏览器："
echo ""
echo "1. 清除浏览器缓存："
echo "   - Chrome/Edge: Ctrl+Shift+Delete"
echo "   - 选择'缓存的图片和文件'"
echo "   - 时间范围选择'全部时间'"
echo ""
echo "2. 强制刷新："
echo "   - Windows/Linux: Ctrl+F5 或 Ctrl+Shift+R"
echo "   - Mac: Cmd+Shift+R"
echo ""
echo "3. 检查浏览器控制台（F12 → Console）："
echo "   - 查看是否有 JavaScript 错误"
echo "   - 查看是否有网络请求失败"
echo "   - 查看 Network 标签中的 API 请求状态"
echo ""
echo "4. 检查 API 请求："
echo "   - 打开浏览器开发者工具（F12）"
echo "   - 切换到 Network 标签"
echo "   - 刷新页面"
echo "   - 查看 /api/v1/dishes 请求"
echo "   - 检查请求 URL、状态码、响应内容"

# 8. 重新构建和部署建议
echo ""
echo "ℹ️ 步骤8: 重新构建和部署建议..."
echo "如果问题仍然存在，尝试完全重新构建："
echo ""
echo "cd ~/gksys/GkSystem/frontend"
echo "rm -rf dist node_modules/.vite .vite"
echo "unset VITE_API_URL"
echo "npm run build"
echo "cd .."
echo "sudo rm -rf /var/www/canteen/*"
echo "sudo cp -r frontend/dist/* /var/www/canteen/"
echo "sudo chown -R www-data:www-data /var/www/canteen"
echo "sudo chmod -R 755 /var/www/canteen"
echo "sudo systemctl reload nginx"

echo ""
echo "=========================================="
echo "✅ 诊断完成"
echo "=========================================="
echo ""
echo "📋 下一步："
echo "1. 查看上面的检查结果"
echo "2. 如果后端和 Nginx 都正常，问题在前端或浏览器"
echo "3. 清除浏览器缓存并强制刷新"
echo "4. 查看浏览器控制台错误"
echo "5. 如果仍有问题，提供浏览器控制台的错误信息"
echo ""

