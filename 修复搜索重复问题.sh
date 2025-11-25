#!/bin/bash

# 修复搜索重复问题

set -e

echo "=========================================="
echo "🔧 修复搜索重复问题"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查数据库是否有重复数据
echo ""
echo "ℹ️ 步骤1: 检查数据库是否有重复数据..."
if mysql -u root -ppassword -e "SELECT name, COUNT(*) as count FROM dishes GROUP BY name HAVING count > 1;" canteen_recommendation 2>/dev/null | grep -v "count"; then
    echo "⚠️ 发现重复的菜品名称:"
    mysql -u root -ppassword -e "SELECT name, COUNT(*) as count FROM dishes GROUP BY name HAVING count > 1;" canteen_recommendation 2>/dev/null
    echo ""
    echo "建议清理重复数据（可选）:"
    echo "  mysql -u root -ppassword canteen_recommendation -e \"DELETE d1 FROM dishes d1 INNER JOIN dishes d2 WHERE d1.id > d2.id AND d1.name = d2.name;\""
else
    echo "✅ 未发现重复的菜品名称"
fi

# 2. 检查后端服务
echo ""
echo "ℹ️ 步骤2: 检查后端服务..."
if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务运行中"
else
    echo "⚠️ 后端服务未运行，启动服务..."
    sudo systemctl start canteen-backend
    sleep 3
fi

# 3. 重启后端服务（应用代码修复）
echo ""
echo "ℹ️ 步骤3: 重启后端服务（应用代码修复）..."
sudo systemctl restart canteen-backend
sleep 3

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务已重启"
else
    echo "❌ 后端服务启动失败"
    sudo journalctl -u canteen-backend -n 30 --no-pager | tail -15
    exit 1
fi

# 4. 测试搜索功能
echo ""
echo "ℹ️ 步骤4: 测试搜索功能..."
echo "搜索关键词: 红"
search_response=$(curl -s "http://localhost:5000/api/v1/dishes?page=1&per_page=20&search=红" 2>&1)
dish_count=$(echo "$search_response" | python3 -c "import sys, json; data=json.load(sys.stdin); dishes=data.get('dishes', []); print(len(dishes))" 2>/dev/null || echo "0")

echo "返回菜品数量: $dish_count"

# 检查是否有重复的 id
if [ "$dish_count" -gt 0 ]; then
    unique_ids=$(echo "$search_response" | python3 -c "import sys, json; data=json.load(sys.stdin); dishes=data.get('dishes', []); ids=[d.get('id') for d in dishes if d.get('id')]; print(len(set(ids)))" 2>/dev/null || echo "0")
    echo "唯一 ID 数量: $unique_ids"
    
    if [ "$dish_count" -gt "$unique_ids" ]; then
        echo "⚠️ 发现重复的菜品 ID"
        echo "重复的 ID:"
        echo "$search_response" | python3 -c "import sys, json; from collections import Counter; data=json.load(sys.stdin); dishes=data.get('dishes', []); ids=[d.get('id') for d in dishes if d.get('id')]; duplicates=[id for id, count in Counter(ids).items() if count > 1]; print('\n'.join(map(str, duplicates)))" 2>/dev/null || echo "无法解析"
    else
        echo "✅ 没有重复的菜品 ID"
    fi
fi

# 5. 重新构建和部署前端
echo ""
echo "ℹ️ 步骤5: 重新构建和部署前端..."
cd frontend

if [ -d "dist" ]; then
    rm -rf dist
fi

unset VITE_API_URL
export VITE_API_URL=""
npm run build

if [ ! -d "dist" ] || [ ! -f "dist/index.html" ]; then
    echo "❌ 前端构建失败"
    exit 1
fi

echo "✅ 前端构建成功"

# 部署到 Nginx
sudo rm -rf /var/www/canteen/*
sudo cp -r dist/* /var/www/canteen/
sudo chown -R www-data:www-data /var/www/canteen
sudo chmod -R 755 /var/www/canteen

echo "✅ 前端已部署"

# 重载 Nginx
sudo systemctl reload nginx

cd ..

# 6. 总结
echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "修复内容:"
echo "  1. ✅ 后端查询添加 DISTINCT 去重"
echo "  2. ✅ 前端添加按 ID 去重逻辑"
echo ""
echo "💡 如果仍有重复，请："
echo "  1. 清除浏览器缓存 (Ctrl+Shift+R)"
echo "  2. 检查数据库是否有重复数据"
echo "  3. 查看后端日志: sudo journalctl -u canteen-backend -f"
echo ""

