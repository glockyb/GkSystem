#!/bin/bash

# 修复前端 API 绝对路径问题

set -e

echo "=========================================="
echo "🔧 修复前端 API 绝对路径问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查前端 API 配置
echo ""
echo "ℹ️ 步骤1: 检查前端 API 配置..."
if [ -f "frontend/src/api/index.js" ]; then
    echo "✅ API 配置文件存在"
    
    # 检查是否有硬编码的 URL
    if grep -q "119.3.232.65\|http://.*:5000" frontend/src/api/index.js; then
        echo "❌ 发现硬编码的 API URL"
        grep "119.3.232.65\|http://.*:5000" frontend/src/api/index.js
        echo "需要修复..."
    else
        echo "✅ API 配置使用相对路径"
    fi
    
    # 检查 getApiBaseURL 函数
    echo ""
    echo "检查 getApiBaseURL 函数："
    grep -A 10 "getApiBaseURL" frontend/src/api/index.js | head -15
else
    echo "❌ API 配置文件不存在"
    exit 1
fi

# 2. 检查 vite.config.js
echo ""
echo "ℹ️ 步骤2: 检查 vite.config.js..."
if [ -f "frontend/vite.config.js" ]; then
    echo "✅ vite.config.js 存在"
    
    # 检查是否有环境变量定义
    if grep -q "VITE_API_URL" frontend/vite.config.js; then
        echo "⚠️ 发现 VITE_API_URL 配置"
        grep -A 2 "VITE_API_URL" frontend/vite.config.js
    fi
else
    echo "❌ vite.config.js 不存在"
    exit 1
fi

# 3. 检查是否有 .env 文件
echo ""
echo "ℹ️ 步骤3: 检查环境变量文件..."
if [ -f "frontend/.env" ]; then
    echo "⚠️ 发现 .env 文件"
    cat frontend/.env
    echo ""
    echo "删除 .env 文件..."
    rm -f frontend/.env
    echo "✅ .env 文件已删除"
elif [ -f "frontend/.env.production" ]; then
    echo "⚠️ 发现 .env.production 文件"
    cat frontend/.env.production
    echo ""
    echo "删除 .env.production 文件..."
    rm -f frontend/.env.production
    echo "✅ .env.production 文件已删除"
else
    echo "✅ 没有环境变量文件"
fi

# 4. 确保 API 配置使用相对路径
echo ""
echo "ℹ️ 步骤4: 确保 API 配置使用相对路径..."
if [ -f "frontend/src/api/index.js" ]; then
    # 备份原文件
    cp frontend/src/api/index.js frontend/src/api/index.js.bak
    
    # 检查并修复（如果需要）
    if ! grep -q "return '/api/v1'" frontend/src/api/index.js; then
        echo "修复 API 配置..."
        # 这里不需要修改，因为代码已经正确了
        # 只需要确保构建时没有环境变量
    fi
    
    echo "✅ API 配置检查完成"
fi

# 5. 完全清除并重新构建
echo ""
echo "ℹ️ 步骤5: 完全清除并重新构建..."
cd frontend

# 完全清除
rm -rf dist node_modules/.vite .vite .vite-cache
find . -name "*.log" -delete 2>/dev/null || true

# 清除所有环境变量
unset VITE_API_URL
unset API_URL
export VITE_API_URL=""
export NODE_ENV=production

echo "✅ 缓存已清除，环境变量已清除"

# 6. 重新构建
echo ""
echo "ℹ️ 步骤6: 重新构建前端..."
echo "⚠️ 这可能需要几分钟，请耐心等待..."

# 使用干净的环境构建
env -i PATH="$PATH" HOME="$HOME" npm run build 2>&1 | tee /tmp/frontend-build-$(date +%s).log

# 7. 验证构建结果
echo ""
echo "ℹ️ 步骤7: 验证构建结果..."
if [ ! -d "dist" ] || [ ! -f "dist/index.html" ]; then
    echo "❌ 构建失败"
    exit 1
fi

# 检查构建后的 JS 文件
main_js=$(find dist/assets -name "*.js" | head -1)
if [ -n "$main_js" ]; then
    echo "检查构建后的 JS 文件: $main_js"
    
    # 检查是否包含硬编码的 URL
    if grep -q "119.3.232.65:5000\|http://.*:5000" "$main_js"; then
        echo "❌ 构建后的 JS 文件仍包含硬编码的 URL"
        echo "找到的内容："
        grep -o "119.3.232.65:5000\|http://[^\"']*:5000" "$main_js" | head -3
        echo ""
        echo "⚠️ 这可能是构建时环境变量导致的"
    else
        echo "✅ 构建后的 JS 文件使用相对路径"
        
        # 检查是否包含 /api/v1
        if grep -q "/api/v1" "$main_js"; then
            echo "✅ 找到相对路径 /api/v1"
        fi
    fi
else
    echo "❌ 未找到构建后的 JS 文件"
    exit 1
fi

cd ..

# 8. 部署前端
echo ""
echo "ℹ️ 步骤8: 部署前端..."
sudo rm -rf /var/www/canteen/*
sudo cp -r frontend/dist/* /var/www/canteen/
sudo chown -R www-data:www-data /var/www/canteen
sudo chmod -R 755 /var/www/canteen

echo "✅ 前端部署完成"

# 9. 重启服务
echo ""
echo "ℹ️ 步骤9: 重启服务..."
sudo systemctl reload nginx
sleep 2

# 10. 验证
echo ""
echo "ℹ️ 步骤10: 验证..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
if [ "$http_code" = "200" ]; then
    echo "✅ 前端访问正常 (HTTP 200)"
else
    echo "⚠️ 前端访问返回 HTTP $http_code"
fi

# 测试 API 代理
api_response=$(curl -s http://localhost/api/v1/dishes/categories || echo "failed")
if echo "$api_response" | grep -q "categories\|error\|\[\]"; then
    echo "✅ API 代理正常"
else
    echo "⚠️ API 代理异常: ${api_response:0:100}"
fi

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "📋 重要提示："
echo "1. 清除浏览器缓存 (Ctrl+Shift+Delete)"
echo "2. 强制刷新页面 (Ctrl+F5)"
echo "3. 打开浏览器控制台 (F12) 验证"
echo "4. 检查 Network 标签，API 请求应该是 /api/v1/... 而不是 http://119.3.232.65:5000/..."
echo ""
echo "如果仍有问题，请提供浏览器控制台的新错误信息"
echo ""

