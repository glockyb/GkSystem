#!/bin/bash

# 添加假数据并修复图片加载问题

set -e

echo "=========================================="
echo "🔧 添加假数据并修复图片加载问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 添加更多假数据
echo ""
echo "ℹ️ 步骤1: 添加更多假数据到数据库..."
if [ -f "添加更多假数据.py" ]; then
    # 激活虚拟环境
    if [ -d "venv" ]; then
        source venv/bin/activate
    elif [ -d "backend/venv" ]; then
        source backend/venv/bin/activate
    fi
    
    python3 添加更多假数据.py
    
    if [ $? -eq 0 ]; then
        echo "✅ 假数据添加成功"
    else
        echo "⚠️ 假数据添加可能有问题，继续..."
    fi
else
    echo "⚠️ 未找到 添加更多假数据.py，跳过..."
fi

# 2. 运行图片修复脚本
echo ""
echo "ℹ️ 步骤2: 修复图片加载问题..."
if [ -f "修复图片加载问题.sh" ]; then
    chmod +x 修复图片加载问题.sh
    ./修复图片加载问题.sh
else
    echo "⚠️ 未找到 修复图片加载问题.sh，手动执行修复..."
    
    # 手动修复图片
    BACKEND_IMAGES_DIR="backend/static/images"
    NGINX_IMAGES_DIR="/var/www/canteen/images"
    
    mkdir -p "$BACKEND_IMAGES_DIR"
    
    # 创建占位图片
    cat > "$BACKEND_IMAGES_DIR/hongshaorou.jpg" << 'EOF'
<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="400" height="300" fill="url(#grad)"/>
  <circle cx="200" cy="120" r="40" fill="rgba(255,255,255,0.3)"/>
  <path d="M 180 120 L 200 100 L 220 120 L 200 140 Z" fill="rgba(255,255,255,0.5)"/>
  <text x="200" y="200" font-family="Arial" font-size="16" fill="rgba(255,255,255,0.8)" text-anchor="middle">菜品图片</text>
</svg>
EOF
    
    # 复制到 Nginx
    sudo mkdir -p "$NGINX_IMAGES_DIR"
    sudo cp -r "$BACKEND_IMAGES_DIR"/* "$NGINX_IMAGES_DIR/" 2>/dev/null || true
    sudo chown -R www-data:www-data "$NGINX_IMAGES_DIR"
    sudo chmod -R 755 "$NGINX_IMAGES_DIR"
    sudo find "$NGINX_IMAGES_DIR" -type f -exec chmod 644 {} \;
    
    # 重载 Nginx
    sudo systemctl reload nginx
fi

# 3. 重启后端服务
echo ""
echo "ℹ️ 步骤3: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 3

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务已重启"
else
    echo "❌ 后端服务启动失败"
    sudo journalctl -u canteen-backend -n 20 --no-pager | tail -10
fi

# 4. 验证数据
echo ""
echo "ℹ️ 步骤4: 验证数据..."
dish_count=$(mysql -u root -ppassword canteen_recommendation -N -e "SELECT COUNT(*) FROM dishes;" 2>/dev/null || echo "0")
echo "数据库中的菜品数量: $dish_count"

# 5. 测试图片
echo ""
echo "ℹ️ 步骤5: 测试图片访问..."
img_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/images/hongshaorou.jpg" 2>&1 || echo "000")
echo "图片访问测试: HTTP $img_code"

# 6. 总结
echo ""
echo "=========================================="
echo "✅ 完成"
echo "=========================================="
echo ""
echo "📊 数据统计:"
echo "   菜品数量: $dish_count"
echo ""
echo "🖼️ 图片配置:"
echo "   图片访问: http://119.3.232.65/images/hongshaorou.jpg"
echo "   状态: $([ "$img_code" = "200" ] && echo "✅ 正常" || echo "⚠️ 异常 (HTTP $img_code)")"
echo ""
echo "💡 如果图片仍不显示，请："
echo "   1. 清除浏览器缓存 (Ctrl+Shift+R)"
echo "   2. 检查浏览器控制台 (F12 → Console)"
echo "   3. 查看 Network 标签页中的图片请求"
echo "   4. 检查图片 URL 是否正确"
echo ""

