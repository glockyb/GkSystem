#!/bin/bash

# 修复 422 JWT 认证错误

set -e

echo "=========================================="
echo "🔧 修复 422 JWT 认证错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查后端日志中的 JWT 错误
echo ""
echo "ℹ️ 步骤1: 检查后端日志中的 JWT 错误..."
recent_jwt_errors=$(sudo journalctl -u canteen-backend -n 100 --no-pager | grep -i "jwt\|token\|422\|invalid" | head -20 || echo "无错误")
if [ "$recent_jwt_errors" != "无错误" ]; then
    echo "⚠️ 发现 JWT 相关错误："
    echo "$recent_jwt_errors"
else
    echo "✅ 未发现 JWT 错误"
fi

# 2. 测试推荐 API（需要 token）
echo ""
echo "ℹ️ 步骤2: 测试推荐 API..."
echo "⚠️ 需要有效的 JWT token 才能测试"
echo "请在前端浏览器中："
echo "1. 打开开发者工具 (F12)"
echo "2. 切换到 Application/Storage 标签"
echo "3. 查看 localStorage 中的 'token' 值"
echo "4. 复制 token 值，然后运行："
echo "   curl -H 'Authorization: Bearer YOUR_TOKEN' http://localhost:5000/api/v1/recommendations"

# 3. 检查 JWT 配置
echo ""
echo "ℹ️ 步骤3: 检查 JWT 配置..."
if grep -q "JWT_SECRET_KEY" backend/config.py; then
    echo "✅ JWT_SECRET_KEY 已配置"
else
    echo "⚠️ JWT_SECRET_KEY 未找到"
fi

# 4. 检查后端代码中的 JWT 错误处理
echo ""
echo "ℹ️ 步骤4: 检查 JWT 错误处理..."
if grep -q "invalid_token_loader\|expired_token_loader" backend/app.py; then
    echo "✅ JWT 错误处理已配置"
else
    echo "⚠️ JWT 错误处理可能未配置"
fi

# 5. 检查前端 token 存储
echo ""
echo "ℹ️ 步骤5: 检查前端 token 存储..."
if [ -f "frontend/src/store/user.js" ]; then
    if grep -q "localStorage.getItem('token')\|localStorage.setItem('token'" frontend/src/store/user.js; then
        echo "✅ 前端 token 存储已配置"
    else
        echo "⚠️ 前端 token 存储可能未配置"
    fi
fi

# 6. 检查 API 请求拦截器
echo ""
echo "ℹ️ 步骤6: 检查 API 请求拦截器..."
if [ -f "frontend/src/api/index.js" ]; then
    if grep -q "Authorization.*Bearer" frontend/src/api/index.js; then
        echo "✅ API 请求拦截器已配置"
        echo "Token 设置代码："
        grep -A 3 "Authorization.*Bearer" frontend/src/api/index.js | head -5
    else
        echo "⚠️ API 请求拦截器可能未配置"
    fi
fi

# 7. 重启后端服务
echo ""
echo "ℹ️ 步骤7: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 3

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "❌ 后端服务未运行"
    sudo systemctl status canteen-backend --no-pager -l | head -20
fi

# 8. 查看最新日志
echo ""
echo "ℹ️ 步骤8: 查看最新日志（最后20行）..."
sudo journalctl -u canteen-backend -n 20 --no-pager

echo ""
echo "=========================================="
echo "✅ 检查完成"
echo "=========================================="
echo ""
echo "📋 问题分析："
echo "422 错误通常表示 JWT token 无效或格式错误"
echo ""
echo "📋 解决方案："
echo "1. 清除浏览器 localStorage："
echo "   - 打开开发者工具 (F12)"
echo "   - Application/Storage → Local Storage"
echo "   - 删除 'token' 键"
echo "   - 重新登录"
echo ""
echo "2. 检查 token 是否正确传递："
echo "   - 打开开发者工具 (F12) → Network 标签"
echo "   - 点击推荐或评分按钮"
echo "   - 查看请求的 Headers"
echo "   - 检查 Authorization header 是否包含 'Bearer <token>'"
echo ""
echo "3. 如果 token 存在但无效，重新登录："
echo "   - 退出登录"
echo "   - 清除浏览器缓存"
echo "   - 重新登录"
echo ""
echo "4. 查看后端详细错误："
echo "   sudo journalctl -u canteen-backend -f"
echo ""

