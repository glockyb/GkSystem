#!/bin/bash

# 完整修复 422 JWT 认证错误

set -e

echo "=========================================="
echo "🔧 完整修复 422 JWT 认证错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查后端日志
echo ""
echo "ℹ️ 步骤1: 检查后端日志（最近50行，包含错误）..."
sudo journalctl -u canteen-backend -n 50 --no-pager | grep -i "error\|jwt\|token\|422\|invalid" || echo "未发现相关错误"

# 2. 检查 JWT 配置
echo ""
echo "ℹ️ 步骤2: 检查 JWT 配置..."
if grep -q "JWT_SECRET_KEY" backend/config.py; then
    echo "✅ JWT_SECRET_KEY 已配置"
    # 检查是否有默认值
    if grep -q "jwt-secret-key-change-in-production" backend/config.py; then
        echo "⚠️ 使用默认 JWT_SECRET_KEY，建议在生产环境修改"
    fi
else
    echo "❌ JWT_SECRET_KEY 未找到"
fi

# 3. 检查前端 token 处理
echo ""
echo "ℹ️ 步骤3: 检查前端 token 处理..."
if [ -f "frontend/src/store/user.js" ]; then
    echo "✅ user store 存在"
    if grep -q "localStorage.getItem('token')" frontend/src/store/user.js; then
        echo "✅ token 从 localStorage 读取"
    fi
    if grep -q "localStorage.setItem('token')" frontend/src/store/user.js; then
        echo "✅ token 保存到 localStorage"
    fi
fi

if [ -f "frontend/src/api/index.js" ]; then
    echo "✅ API 配置文件存在"
    if grep -q "Authorization.*Bearer" frontend/src/api/index.js; then
        echo "✅ Authorization header 已配置"
        echo "Token 设置代码："
        grep -B 2 -A 2 "Authorization.*Bearer" frontend/src/api/index.js | head -8
    else
        echo "❌ Authorization header 未配置"
    fi
fi

# 4. 测试登录 API（获取新 token）
echo ""
echo "ℹ️ 步骤4: 测试登录 API..."
echo "⚠️ 需要有效的用户名和密码"
echo "请在前端登录，或使用 curl 测试："
echo "curl -X POST http://localhost:5000/api/v1/login \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"username\":\"test\",\"password\":\"test123\"}'"

# 5. 检查后端 JWT 错误处理
echo ""
echo "ℹ️ 步骤5: 检查后端 JWT 错误处理..."
if grep -q "invalid_token_loader" backend/app.py; then
    echo "✅ JWT 错误处理已配置"
    echo "错误处理代码："
    grep -A 3 "invalid_token_loader\|expired_token_loader" backend/app.py
else
    echo "⚠️ JWT 错误处理可能未配置"
fi

# 6. 重启后端服务
echo ""
echo "ℹ️ 步骤6: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 3

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "❌ 后端服务未运行"
    sudo systemctl status canteen-backend --no-pager -l | head -20
fi

# 7. 查看实时日志
echo ""
echo "ℹ️ 步骤7: 查看最新日志（最后30行）..."
sudo journalctl -u canteen-backend -n 30 --no-pager

echo ""
echo "=========================================="
echo "✅ 检查完成"
echo "=========================================="
echo ""
echo "📋 422 错误通常的原因和解决方案："
echo ""
echo "1. Token 未传递："
echo "   - 打开浏览器开发者工具 (F12)"
echo "   - Application/Storage → Local Storage"
echo "   - 检查是否有 'token' 键"
echo "   - 如果没有，需要重新登录"
echo ""
echo "2. Token 格式错误："
echo "   - 检查 Network 标签中的请求 Headers"
echo "   - Authorization header 应该是: 'Bearer <token>'"
echo "   - 如果格式不对，清除 localStorage 并重新登录"
echo ""
echo "3. Token 已过期："
echo "   - JWT token 默认24小时过期"
echo "   - 如果过期，需要重新登录"
echo ""
echo "4. Token 无效："
echo "   - 清除浏览器 localStorage"
echo "   - 重新登录获取新 token"
echo ""
echo "📋 快速修复步骤："
echo "1. 打开浏览器开发者工具 (F12)"
echo "2. Application/Storage → Local Storage"
echo "3. 删除 'token' 键（如果存在）"
echo "4. 刷新页面"
echo "5. 重新登录"
echo "6. 再次尝试推荐和评分功能"
echo ""
echo "📖 查看实时日志: sudo journalctl -u canteen-backend -f"
echo ""

