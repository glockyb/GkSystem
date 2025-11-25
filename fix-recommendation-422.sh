#!/bin/bash

# 修复推荐功能 422 错误

set -e

echo "=========================================="
echo "🔧 修复推荐功能 422 错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查后端日志
echo ""
echo "ℹ️ 步骤1: 检查后端日志（最近错误）..."
sudo journalctl -u canteen-backend -n 50 --no-pager | grep -i "error\|422\|jwt\|token" || echo "未发现相关错误"

# 2. 检查 JWT 配置
echo ""
echo "ℹ️ 步骤2: 检查 JWT 配置..."
if grep -q "JWT_SECRET_KEY" backend/config.py; then
    echo "✅ JWT_SECRET_KEY 已配置"
else
    echo "⚠️ JWT_SECRET_KEY 未找到"
fi

# 3. 测试推荐 API（需要 token）
echo ""
echo "ℹ️ 步骤3: 测试推荐 API..."
echo "⚠️ 需要有效的 JWT token 才能测试，请在前端浏览器中查看 Network 标签获取 token"

# 4. 检查推荐模型
echo ""
echo "ℹ️ 步骤4: 检查推荐模型..."
if [ -f "backend/models/collaborative_model.pkl" ]; then
    echo "✅ 协同过滤模型存在"
else
    echo "⚠️ 协同过滤模型不存在，需要训练"
fi

if [ -f "backend/models/content_model.pkl" ]; then
    echo "✅ 内容推荐模型存在"
else
    echo "⚠️ 内容推荐模型不存在，需要训练"
fi

# 5. 检查推荐代码
echo ""
echo "ℹ️ 步骤5: 检查推荐代码..."
if grep -q "@jwt_required()" backend/api/recommendations.py; then
    echo "✅ JWT 认证已配置"
else
    echo "❌ JWT 认证未配置"
fi

# 6. 重启后端服务
echo ""
echo "ℹ️ 步骤6: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 2

# 7. 检查服务状态
echo ""
echo "ℹ️ 步骤7: 检查服务状态..."
if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "❌ 后端服务未运行"
    sudo systemctl status canteen-backend --no-pager -l
fi

# 8. 查看最新日志
echo ""
echo "ℹ️ 步骤8: 查看最新日志（最后10行）..."
sudo journalctl -u canteen-backend -n 10 --no-pager

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "📋 下一步操作："
echo "1. 在前端浏览器中打开开发者工具（F12）"
echo "2. 切换到 Network 标签"
echo "3. 点击推荐按钮"
echo "4. 查看请求详情，检查："
echo "   - Authorization header 是否包含 Bearer token"
echo "   - 响应状态码和错误信息"
echo "5. 如果 token 无效，请重新登录"
echo ""
echo "📖 查看实时日志: sudo journalctl -u canteen-backend -f"
echo ""
