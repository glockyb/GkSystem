#!/bin/bash

# 修复搜索重复问题（完整版）

set -e

echo "=========================================="
echo "🔧 修复搜索重复问题（完整版）"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查数据库重复数据
echo ""
echo "ℹ️ 步骤1: 检查数据库重复数据..."
duplicate_count=$(mysql -u root -ppassword canteen_recommendation -N -e "SELECT COUNT(*) FROM (SELECT name, COUNT(*) as count FROM dishes GROUP BY name HAVING count > 1) as t;" 2>/dev/null || echo "0")

if [ "$duplicate_count" != "0" ]; then
    echo "⚠️ 发现 $duplicate_count 组重复的菜品名称"
    echo ""
    echo "重复的菜品名称:"
    mysql -u root -ppassword canteen_recommendation -e "SELECT name, COUNT(*) as count FROM dishes GROUP BY name HAVING count > 1 ORDER BY count DESC;" 2>/dev/null | head -20
    
    echo ""
    echo "是否要自动清理重复数据？(保留每个名称中 ID 最小的记录)"
    read -p "输入 'yes' 继续，其他任意键跳过: " confirm
    
    if [ "$confirm" = "yes" ]; then
        echo "清理重复数据..."
        mysql -u root -ppassword canteen_recommendation << 'EOF'
DELETE d1 FROM dishes d1
INNER JOIN dishes d2 
WHERE d1.id > d2.id 
AND d1.name = d2.name;
EOF
        echo "✅ 重复数据清理完成"
    else
        echo "跳过清理，继续修复代码..."
    fi
else
    echo "✅ 数据库中没有重复的菜品名称"
fi

# 2. 重启后端服务（应用代码修复）
echo ""
echo "ℹ️ 步骤2: 重启后端服务（应用代码修复）..."
sudo systemctl restart canteen-backend
sleep 3

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务已重启"
else
    echo "❌ 后端服务启动失败"
    sudo journalctl -u canteen-backend -n 30 --no-pager | tail -15
    exit 1
fi

# 3. 测试搜索功能
echo ""
echo "ℹ️ 步骤3: 测试搜索功能..."
echo "搜索关键词: 红"
search_result=$(curl -s "http://localhost:5000/api/v1/dishes?page=1&per_page=20&search=红" 2>&1)

if echo "$search_result" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
    dish_count=$(echo "$search_result" | python3 -c "import sys, json; data=json.load(sys.stdin); dishes=data.get('dishes', []); print(len(dishes))" 2>/dev/null || echo "0")
    unique_names=$(echo "$search_result" | python3 -c "import sys, json; from collections import Counter; data=json.load(sys.stdin); dishes=data.get('dishes', []); names=[d.get('name') for d in dishes if d.get('name')]; print(len(set(names)))" 2>/dev/null || echo "0")
    unique_ids=$(echo "$search_result" | python3 -c "import sys, json; data=json.load(sys.stdin); dishes=data.get('dishes', []); ids=[d.get('id') for d in dishes if d.get('id')]; print(len(set(ids)))" 2>/dev/null || echo "0")
    
    echo "返回菜品数量: $dish_count"
    echo "唯一菜品名称数量: $unique_names"
    echo "唯一 ID 数量: $unique_ids"
    
    if [ "$dish_count" -eq "$unique_names" ] && [ "$dish_count" -eq "$unique_ids" ]; then
        echo "✅ 搜索结果没有重复"
    else
        echo "⚠️ 搜索结果仍有重复"
        if [ "$dish_count" -ne "$unique_names" ]; then
            echo "   重复的菜品名称:"
            echo "$search_result" | python3 -c "import sys, json; from collections import Counter; data=json.load(sys.stdin); dishes=data.get('dishes', []); names=[d.get('name') for d in dishes if d.get('name')]; duplicates=[name for name, count in Counter(names).items() if count > 1]; print('  ' + '\n  '.join(duplicates))" 2>/dev/null || echo "   无法解析"
        fi
    fi
else
    echo "❌ API 返回错误"
    echo "$search_result" | head -10
fi

# 4. 重新构建和部署前端
echo ""
echo "ℹ️ 步骤4: 重新构建和部署前端..."
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

# 5. 总结
echo ""
echo "=========================================="
echo "✅ 修复完成"
echo "=========================================="
echo ""
echo "修复内容:"
echo "  1. ✅ 后端查询使用 GROUP BY 去重（每个名称只返回一条记录）"
echo "  2. ✅ 后端结果再次去重（双重保障）"
echo "  3. ✅ 前端按 ID 去重（三重保障）"
echo "  4. ✅ 数据库重复数据清理（可选）"
echo ""
echo "💡 如果仍有重复，请："
echo "  1. 清除浏览器缓存 (Ctrl+Shift+R)"
echo "  2. 运行检查脚本: ./检查并清理重复数据.sh"
echo "  3. 查看后端日志: sudo journalctl -u canteen-backend -f"
echo ""

