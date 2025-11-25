#!/bin/bash

# 修复 JWT 422 错误和图片 404 错误

set -e

echo "=========================================="
echo "🔧 修复 JWT 422 错误和图片 404 错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查后端日志中的 JWT 错误
echo ""
echo "ℹ️ 步骤1: 检查后端日志中的 JWT 错误..."
recent_jwt_errors=$(sudo journalctl -u canteen-backend -n 100 --no-pager | grep -i "jwt\|token\|422\|invalid\|error" | head -30 || echo "无错误")
if [ "$recent_jwt_errors" != "无错误" ]; then
    echo "⚠️ 发现 JWT 相关错误："
    echo "$recent_jwt_errors"
else
    echo "✅ 未发现 JWT 错误"
fi

# 2. 重启后端服务（应用 JWT 错误处理改进）
echo ""
echo "ℹ️ 步骤2: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 3

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "❌ 后端服务未运行"
    sudo systemctl status canteen-backend --no-pager -l | head -20
fi

# 3. 检查图片目录
echo ""
echo "ℹ️ 步骤3: 检查图片目录..."
if [ -d "backend/static/images" ]; then
    image_count=$(find backend/static/images -type f | wc -l)
    echo "✅ 图片目录存在，包含 $image_count 个文件"
    
    # 检查是否需要创建图片目录的符号链接
    if [ ! -L "/var/www/canteen/images" ] && [ ! -d "/var/www/canteen/images" ]; then
        echo "创建图片目录符号链接..."
        sudo ln -s "$(pwd)/backend/static/images" /var/www/canteen/images
        echo "✅ 图片目录符号链接已创建"
    fi
else
    echo "⚠️ 图片目录不存在"
    echo "创建图片目录..."
    mkdir -p backend/static/images
    echo "✅ 图片目录已创建"
fi

# 4. 检查 Nginx 配置中的图片路径
echo ""
echo "ℹ️ 步骤4: 检查 Nginx 配置..."
if [ -f "/etc/nginx/sites-available/canteen" ]; then
    if grep -q "location /images" /etc/nginx/sites-available/canteen; then
        echo "✅ Nginx 图片路径配置存在"
    else
        echo "⚠️ Nginx 图片路径配置不存在，添加配置..."
        
        # 备份配置
        sudo cp /etc/nginx/sites-available/canteen /etc/nginx/sites-available/canteen.backup.$(date +%Y%m%d_%H%M%S)
        
        # 添加图片路径配置
        sudo sed -i '/location \/api/a\
    location /images {\
        alias /var/www/canteen/images;\
        expires 30d;\
        add_header Cache-Control "public, immutable";\
    }' /etc/nginx/sites-available/canteen
        
        # 测试配置
        if sudo nginx -t 2>&1 | grep -q "successful"; then
            echo "✅ Nginx 配置正确"
            sudo systemctl reload nginx
        else
            echo "❌ Nginx 配置错误"
            sudo nginx -t
            # 恢复备份
            sudo cp /etc/nginx/sites-available/canteen.backup.* /etc/nginx/sites-available/canteen
        fi
    fi
fi

# 5. 查看最新日志
echo ""
echo "ℹ️ 步骤5: 查看最新日志（最后20行）..."
sudo journalctl -u canteen-backend -n 20 --no-pager

echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "📋 422 错误解决方案："
echo ""
echo "1. 清除浏览器 localStorage："
echo "   - 打开开发者工具 (F12)"
echo "   - Application/Storage → Local Storage"
echo "   - 删除 'token' 键"
echo "   - 刷新页面"
echo "   - 重新登录"
echo ""
echo "2. 检查 token 是否正确传递："
echo "   - 打开开发者工具 (F12) → Network 标签"
echo "   - 点击推荐或评分按钮"
echo "   - 查看请求的 Headers"
echo "   - 检查 Authorization header 是否包含 'Bearer <token>'"
echo ""
echo "3. 如果 token 存在但无效："
echo "   - 退出登录"
echo "   - 清除浏览器缓存 (Ctrl+Shift+Delete)"
echo "   - 重新登录"
echo ""
echo "4. 查看后端详细错误："
echo "   sudo journalctl -u canteen-backend -f"
echo ""
echo "📋 图片 404 错误："
echo "图片文件应该位于: backend/static/images/"
echo "如果图片不存在，这是正常的（不影响功能）"
echo ""

