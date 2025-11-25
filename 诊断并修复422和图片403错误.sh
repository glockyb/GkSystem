#!/bin/bash

# 诊断并修复 422 错误和图片 403 错误

set -e

echo "=========================================="
echo "🔧 诊断并修复 422 和图片 403 错误"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查后端日志中的 JWT 错误
echo ""
echo "ℹ️ 步骤1: 检查后端日志中的 JWT 错误..."
echo "最近 50 行日志："
sudo journalctl -u canteen-backend -n 50 --no-pager | grep -i "jwt\|422\|token\|unauthorized" || echo "未发现相关错误"

# 2. 测试后端 API（不带 token）
echo ""
echo "ℹ️ 步骤2: 测试后端 API（不带 token）..."
echo "测试 /api/v1/recommendations:"
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:5000/api/v1/recommendations || echo "请求失败"

# 3. 检查 JWT 配置
echo ""
echo "ℹ️ 步骤3: 检查 JWT 配置..."
if [ -f "backend/config.py" ]; then
    echo "JWT_SECRET_KEY 是否设置:"
    grep -q "JWT_SECRET_KEY" backend/config.py && echo "✅ 已设置" || echo "❌ 未设置"
    echo "JWT_ACCESS_TOKEN_EXPIRES:"
    grep "JWT_ACCESS_TOKEN_EXPIRES" backend/config.py || echo "未找到"
fi

# 4. 检查图片目录和权限
echo ""
echo "ℹ️ 步骤4: 检查图片目录和权限..."
if [ -d "backend/static/images" ]; then
    echo "✅ 图片目录存在: backend/static/images"
    image_count=$(find backend/static/images -type f 2>/dev/null | wc -l)
    echo "   图片文件数量: $image_count"
    
    # 检查权限
    echo "   目录权限:"
    ls -ld backend/static/images
    
    # 检查 Nginx 是否可以访问
    if [ -L "/var/www/canteen/images" ] || [ -d "/var/www/canteen/images" ]; then
        echo "✅ Nginx 图片目录存在: /var/www/canteen/images"
        echo "   权限:"
        ls -ld /var/www/canteen/images
        
        # 检查 www-data 是否可以访问
        if sudo -u www-data test -r /var/www/canteen/images 2>/dev/null; then
            echo "✅ www-data 可以读取图片目录"
        else
            echo "❌ www-data 无法读取图片目录，修复权限..."
            sudo chown -R www-data:www-data /var/www/canteen/images 2>/dev/null || true
            sudo chmod -R 755 /var/www/canteen/images 2>/dev/null || true
        fi
    else
        echo "⚠️ Nginx 图片目录不存在，创建符号链接..."
        if [ -d "backend/static/images" ]; then
            sudo mkdir -p /var/www/canteen
            sudo ln -sf "$(pwd)/backend/static/images" /var/www/canteen/images
            sudo chown -R www-data:www-data /var/www/canteen/images
            sudo chmod -R 755 /var/www/canteen/images
            echo "✅ 已创建符号链接并设置权限"
        fi
    fi
else
    echo "⚠️ 图片目录不存在，创建..."
    mkdir -p backend/static/images
    echo "✅ 图片目录已创建"
fi

# 5. 检查并修复 Nginx 配置
echo ""
echo "ℹ️ 步骤5: 检查并修复 Nginx 配置..."
if [ -f "/etc/nginx/sites-available/canteen" ]; then
    if grep -q "location /images" /etc/nginx/sites-available/canteen; then
        echo "✅ Nginx 图片配置存在"
        
        # 检查配置是否正确（不在 location /api 内）
        if grep -A 10 "location /api" /etc/nginx/sites-available/canteen | grep -q "location /images"; then
            echo "❌ 发现错误的嵌套配置，修复..."
            # 删除错误的嵌套配置
            sudo sed -i '/location \/images/,/}/d' /etc/nginx/sites-available/canteen
            
            # 正确添加配置
            sudo awk '
            /location \/api {/ {
                in_api = 1
                print
                next
            }
            in_api && /^[[:space:]]*}/ {
                in_api = 0
                print
                print ""
                print "    location /images {"
                print "        alias /var/www/canteen/images;"
                print "        expires 30d;"
                print "        add_header Cache-Control \"public, immutable\";"
                print "    }"
                next
            }
            { print }
            ' /etc/nginx/sites-available/canteen | sudo tee /etc/nginx/sites-available/canteen.new > /dev/null
            sudo mv /etc/nginx/sites-available/canteen.new /etc/nginx/sites-available/canteen
        fi
    else
        echo "⚠️ Nginx 图片配置不存在，添加..."
        # 使用 awk 正确添加配置
        sudo awk '
        /location \/api {/ {
            in_api = 1
            print
            next
        }
        in_api && /^[[:space:]]*}/ {
            in_api = 0
            print
            print ""
            print "    location /images {"
            print "        alias /var/www/canteen/images;"
            print "        expires 30d;"
            print "        add_header Cache-Control \"public, immutable\";"
            print "    }"
            next
        }
        { print }
        ' /etc/nginx/sites-available/canteen | sudo tee /etc/nginx/sites-available/canteen.new > /dev/null
        sudo mv /etc/nginx/sites-available/canteen.new /etc/nginx/sites-available/canteen
    fi
    
    # 验证配置
    if sudo nginx -t 2>&1 | grep -q "successful"; then
        echo "✅ Nginx 配置正确"
        sudo systemctl reload nginx
    else
        echo "❌ Nginx 配置错误"
        sudo nginx -t
    fi
fi

# 6. 重启后端服务（确保 JWT 配置生效）
echo ""
echo "ℹ️ 步骤6: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 2

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "❌ 后端服务未运行"
    sudo systemctl status canteen-backend --no-pager -l | head -20
fi

# 7. 测试图片访问
echo ""
echo "ℹ️ 步骤7: 测试图片访问..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/images/ 2>/dev/null || echo "000")
if [ "$http_code" = "403" ] || [ "$http_code" = "404" ]; then
    echo "⚠️ 图片路径返回 HTTP $http_code（这是正常的，如果目录为空）"
else
    echo "✅ 图片路径返回 HTTP $http_code"
fi

# 8. 提供解决 422 错误的建议
echo ""
echo "=========================================="
echo "📋 关于 422 错误的解决方案"
echo "=========================================="
echo ""
echo "422 错误通常表示 JWT token 无效或过期。请按以下步骤操作："
echo ""
echo "1. 清除浏览器缓存和 localStorage："
echo "   - 打开开发者工具 (F12)"
echo "   - Application/Storage → Local Storage"
echo "   - 删除所有项目（特别是 token、userId、username）"
echo ""
echo "2. 重新登录获取新的 token"
echo ""
echo "3. 如果问题仍然存在，检查后端日志："
echo "   sudo journalctl -u canteen-backend -f"
echo ""
echo "4. 验证 JWT 配置："
echo "   - 检查 backend/config.py 中的 JWT_SECRET_KEY"
echo "   - 确保前后端使用相同的密钥"
echo ""
echo "=========================================="
echo "✅ 诊断完成"
echo "=========================================="

