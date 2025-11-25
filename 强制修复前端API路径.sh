#!/bin/bash

# 强制修复前端 API 路径问题

set -e

echo "=========================================="
echo "🔧 强制修复前端 API 路径问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查源代码中是否有硬编码的 URL
echo ""
echo "ℹ️ 步骤1: 检查源代码..."
if grep -r "119.3.232.65\|http://.*:5000" frontend/src/ 2>/dev/null; then
    echo "❌ 源代码中发现硬编码的 URL，需要修复"
    exit 1
else
    echo "✅ 源代码中没有硬编码的 URL"
fi

# 2. 删除所有环境变量文件
echo ""
echo "ℹ️ 步骤2: 删除所有环境变量文件..."
cd frontend
rm -f .env .env.production .env.local .env.development .env.*.local
echo "✅ 环境变量文件已删除"

# 3. 检查是否有环境变量
echo ""
echo "ℹ️ 步骤3: 检查环境变量..."
if [ -n "$VITE_API_URL" ]; then
    echo "⚠️ 发现 VITE_API_URL 环境变量: $VITE_API_URL"
    echo "清除环境变量..."
    unset VITE_API_URL
fi
unset VITE_API_URL
unset API_URL
export VITE_API_URL=""
export NODE_ENV=production
echo "✅ 环境变量已清除"

# 4. 完全清除所有缓存
echo ""
echo "ℹ️ 步骤4: 完全清除所有缓存..."
rm -rf dist
rm -rf node_modules/.vite
rm -rf .vite
rm -rf .vite-cache
rm -rf .cache
find . -name "*.log" -delete 2>/dev/null || true
echo "✅ 缓存已清除"

# 5. 验证 API 配置文件
echo ""
echo "ℹ️ 步骤5: 验证 API 配置文件..."
if [ -f "src/api/index.js" ]; then
    echo "检查 getApiBaseURL 函数..."
    if grep -A 10 "getApiBaseURL" src/api/index.js | grep -q "return '/api/v1'"; then
        echo "✅ API 配置正确，使用相对路径"
    else
        echo "⚠️ API 配置可能有问题"
        echo "当前配置："
        grep -A 10 "getApiBaseURL" src/api/index.js
    fi
else
    echo "❌ API 配置文件不存在"
    exit 1
fi

# 6. 使用完全干净的环境构建
echo ""
echo "ℹ️ 步骤6: 使用完全干净的环境构建..."
echo "⚠️ 这可能需要几分钟，请耐心等待..."

# 使用 env -i 创建完全干净的环境，只保留必要的变量
env -i \
    PATH="$PATH" \
    HOME="$HOME" \
    USER="$USER" \
    SHELL="$SHELL" \
    npm run build 2>&1 | tee /tmp/frontend-build-$(date +%s).log

# 7. 验证构建结果
echo ""
echo "ℹ️ 步骤7: 验证构建结果..."
if [ ! -d "dist" ] || [ ! -f "dist/index.html" ]; then
    echo "❌ 构建失败"
    exit 1
fi

# 检查构建后的 JS 文件
main_js=$(find dist/assets -name "*.js" | head -1)
if [ -z "$main_js" ]; then
    echo "❌ 未找到构建后的 JS 文件"
    exit 1
fi

echo "检查构建后的 JS 文件: $main_js"

# 检查是否包含硬编码的 URL
if grep -q "119.3.232.65:5000\|http://119.3.232.65:5000" "$main_js"; then
    echo "❌ 构建后的 JS 文件仍包含硬编码的 URL"
    echo "找到的内容："
    grep -o "119.3.232.65:5000\|http://119.3.232.65:5000" "$main_js" | head -5
    echo ""
    echo "⚠️ 这可能是构建时环境变量导致的，尝试另一种方法..."
    
    # 尝试直接修改构建后的文件（临时方案）
    echo "尝试修复构建后的文件..."
    sudo sed -i 's|http://119.3.232.65:5000/api/v1|/api/v1|g' "$main_js" 2>/dev/null || \
    sed -i 's|http://119.3.232.65:5000/api/v1|/api/v1|g' "$main_js" 2>/dev/null || true
    
    # 再次检查
    if grep -q "119.3.232.65:5000" "$main_js"; then
        echo "❌ 修复失败，需要检查构建过程"
    else
        echo "✅ 已修复构建后的文件"
    fi
else
    echo "✅ 构建后的 JS 文件使用相对路径"
    
    # 检查是否包含 /api/v1
    if grep -q "/api/v1" "$main_js"; then
        echo "✅ 找到相对路径 /api/v1"
    else
        echo "⚠️ 未找到 /api/v1，检查其他可能的路径..."
        grep -o '"[^"]*api[^"]*"' "$main_js" | head -5
    fi
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

# 9. 验证部署的文件
echo ""
echo "ℹ️ 步骤9: 验证部署的文件..."
deployed_js=$(sudo find /var/www/canteen/assets -name "*.js" | head -1)
if [ -n "$deployed_js" ]; then
    if sudo grep -q "119.3.232.65:5000" "$deployed_js" 2>/dev/null; then
        echo "⚠️ 部署的文件仍包含硬编码的 URL，尝试修复..."
        sudo sed -i 's|http://119.3.232.65:5000/api/v1|/api/v1|g' "$deployed_js"
        echo "✅ 已修复部署的文件"
    else
        echo "✅ 部署的文件使用相对路径"
    fi
fi

# 10. 重启服务
echo ""
echo "ℹ️ 步骤10: 重启服务..."
sudo systemctl reload nginx
sleep 2

# 11. 最终验证
echo ""
echo "ℹ️ 步骤11: 最终验证..."
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
echo "1. 必须清除浏览器缓存 (Ctrl+Shift+Delete)"
echo "2. 强制刷新页面 (Ctrl+F5)"
echo "3. 或者使用隐私模式/无痕模式打开浏览器"
echo "4. 打开浏览器控制台 (F12) → Network 标签"
echo "5. 刷新页面，检查 API 请求应该是 /api/v1/... 而不是 http://119.3.232.65:5000/..."
echo ""
echo "如果仍然看到 http://119.3.232.65:5000，说明浏览器缓存了旧版本"
echo "请使用隐私模式测试，或完全清除浏览器缓存"
echo ""

