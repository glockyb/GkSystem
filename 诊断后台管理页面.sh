#!/bin/bash

# 诊断后台管理页面问题

set -e

echo "=========================================="
echo "🔍 诊断后台管理页面问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查用户是否为管理员
echo ""
echo "ℹ️ 步骤1: 检查管理员用户..."
mysql -u root -ppassword canteen_recommendation << 'SQL' 2>/dev/null
SELECT id, username, email, role, is_admin FROM users WHERE is_admin = 1 OR role = 'admin' LIMIT 5;
SQL

# 2. 测试管理员 API（需要 token）
echo ""
echo "ℹ️ 步骤2: 测试管理员 API..."
echo "请提供管理员 token 进行测试，或检查浏览器控制台错误"

# 3. 检查后端 admin 模块
echo ""
echo "ℹ️ 步骤3: 检查后端 admin 模块..."
cd backend
if [ -d "venv" ]; then
    source venv/bin/activate
fi

python3 << 'PYTHON_TEST'
import sys
sys.path.insert(0, '.')

try:
    from api import admin
    print("✅ admin 模块导入成功")
    
    # 检查路由
    routes = [str(rule) for rule in admin.bp.url_map.iter_rules()]
    print(f"✅ admin 路由数量: {len(routes)}")
    for route in routes[:5]:
        print(f"   - {route}")
        
except Exception as e:
    print(f"❌ admin 模块导入失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON_TEST

cd ..

# 4. 检查前端构建
echo ""
echo "ℹ️ 步骤4: 检查前端构建..."
if [ -f "frontend/dist/index.html" ]; then
    echo "✅ 前端已构建"
    
    # 检查 Admin.vue 是否在构建中
    if grep -q "admin" frontend/dist/index.html 2>/dev/null || [ -f "frontend/dist/assets" ]; then
        echo "✅ 前端文件存在"
    fi
else
    echo "⚠️ 前端未构建，请运行: cd frontend && npm run build"
fi

# 5. 检查后端服务状态
echo ""
echo "ℹ️ 步骤5: 检查后端服务状态..."
if systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
    
    # 测试健康检查
    if curl -s http://localhost:5000/health | grep -q "healthy"; then
        echo "✅ 健康检查通过"
    else
        echo "⚠️ 健康检查失败"
    fi
else
    echo "❌ 后端服务未运行"
fi

# 6. 查看最近错误日志
echo ""
echo "ℹ️ 步骤6: 查看最近错误日志（最后 20 行）..."
sudo journalctl -u canteen-backend -n 20 --no-pager | grep -i "error\|exception\|traceback\|admin" || echo "未发现相关错误"

# 7. 检查 Nginx 配置
echo ""
echo "ℹ️ 步骤7: 检查 Nginx 配置..."
if [ -f "/etc/nginx/sites-available/canteen" ]; then
    if grep -q "location /images" /etc/nginx/sites-available/canteen; then
        echo "✅ /images location 已配置"
    else
        echo "⚠️ /images location 未配置"
    fi
    
    if grep -q "location /api" /etc/nginx/sites-available/canteen; then
        echo "✅ /api location 已配置"
    else
        echo "⚠️ /api location 未配置"
    fi
else
    echo "⚠️ Nginx 配置文件不存在"
fi

echo ""
echo "=========================================="
echo "📋 诊断完成"
echo "=========================================="
echo ""
echo "请检查浏览器控制台（F12）是否有以下错误："
echo "1. API 调用失败（401/403/500）"
echo "2. JavaScript 错误"
echo "3. 网络请求失败"
echo ""
echo "如果看到 403 错误，可能是权限问题，请确认："
echo "1. 用户已登录"
echo "2. 用户是管理员（is_admin=1 或 role='admin'）"
echo "3. JWT token 有效"
echo ""

