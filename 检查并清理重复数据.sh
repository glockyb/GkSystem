#!/bin/bash

# 检查并清理数据库中的重复数据

set -e

echo "=========================================="
echo "🔍 检查并清理重复数据"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

# 1. 检查重复的菜品名称
echo ""
echo "ℹ️ 步骤1: 检查重复的菜品名称..."
echo "----------------------------------------"
mysql -u root -ppassword canteen_recommendation << 'EOF'
SELECT name, COUNT(*) as count 
FROM dishes 
GROUP BY name 
HAVING count > 1 
ORDER BY count DESC;
EOF

echo ""
echo "----------------------------------------"

# 2. 显示重复数据的详细信息
echo ""
echo "ℹ️ 步骤2: 显示重复数据的详细信息..."
mysql -u root -ppassword canteen_recommendation << 'EOF'
SELECT d1.id, d1.name, d1.category, d1.price, d1.created_at
FROM dishes d1
INNER JOIN (
    SELECT name, COUNT(*) as count
    FROM dishes
    GROUP BY name
    HAVING count > 1
) d2 ON d1.name = d2.name
ORDER BY d1.name, d1.id;
EOF

# 3. 询问是否清理
echo ""
echo "=========================================="
echo "⚠️  发现重复数据"
echo "=========================================="
echo ""
echo "是否要清理重复数据？"
echo "将保留每个菜品名称中 ID 最小的记录，删除其他重复记录"
echo ""
read -p "输入 'yes' 继续清理，其他任意键取消: " confirm

if [ "$confirm" != "yes" ]; then
    echo "已取消清理操作"
    exit 0
fi

# 4. 清理重复数据（保留 ID 最小的记录）
echo ""
echo "ℹ️ 步骤3: 清理重复数据..."
mysql -u root -ppassword canteen_recommendation << 'EOF'
-- 删除重复数据，保留每个名称中 ID 最小的记录
DELETE d1 FROM dishes d1
INNER JOIN dishes d2 
WHERE d1.id > d2.id 
AND d1.name = d2.name;
EOF

if [ $? -eq 0 ]; then
    echo "✅ 重复数据清理完成"
else
    echo "❌ 清理失败"
    exit 1
fi

# 5. 验证清理结果
echo ""
echo "ℹ️ 步骤4: 验证清理结果..."
remaining_duplicates=$(mysql -u root -ppassword canteen_recommendation -N -e "SELECT COUNT(*) FROM (SELECT name, COUNT(*) as count FROM dishes GROUP BY name HAVING count > 1) as t;" 2>/dev/null || echo "0")

if [ "$remaining_duplicates" = "0" ]; then
    echo "✅ 没有重复数据了"
else
    echo "⚠️ 仍有 $remaining_duplicates 组重复数据"
fi

# 6. 显示清理后的统计
echo ""
echo "ℹ️ 步骤5: 显示清理后的统计..."
mysql -u root -ppassword canteen_recommendation << 'EOF'
SELECT 
    COUNT(*) as total_dishes,
    COUNT(DISTINCT name) as unique_names,
    COUNT(*) - COUNT(DISTINCT name) as duplicates_removed
FROM dishes;
EOF

# 7. 重启后端服务
echo ""
echo "ℹ️ 步骤6: 重启后端服务..."
sudo systemctl restart canteen-backend
sleep 2

if sudo systemctl is-active --quiet canteen-backend; then
    echo "✅ 后端服务已重启"
else
    echo "❌ 后端服务启动失败"
    sudo journalctl -u canteen-backend -n 20 --no-pager | tail -10
fi

# 8. 测试搜索
echo ""
echo "ℹ️ 步骤7: 测试搜索功能..."
echo "搜索关键词: 红"
search_result=$(curl -s "http://localhost:5000/api/v1/dishes?page=1&per_page=20&search=红" 2>&1)
dish_count=$(echo "$search_result" | python3 -c "import sys, json; data=json.load(sys.stdin); dishes=data.get('dishes', []); print(len(dishes))" 2>/dev/null || echo "0")
unique_names=$(echo "$search_result" | python3 -c "import sys, json; data=json.load(sys.stdin); dishes=data.get('dishes', []); names=[d.get('name') for d in dishes]; print(len(set(names)))" 2>/dev/null || echo "0")

echo "返回菜品数量: $dish_count"
echo "唯一菜品名称数量: $unique_names"

if [ "$dish_count" -eq "$unique_names" ]; then
    echo "✅ 搜索结果没有重复"
else
    echo "⚠️ 搜索结果仍有重复（$dish_count 条记录，$unique_names 个唯一名称）"
    echo "重复的菜品名称:"
    echo "$search_result" | python3 -c "import sys, json; from collections import Counter; data=json.load(sys.stdin); dishes=data.get('dishes', []); names=[d.get('name') for d in dishes]; duplicates=[name for name, count in Counter(names).items() if count > 1]; print('\n'.join(duplicates))" 2>/dev/null || echo "无法解析"
fi

echo ""
echo "=========================================="
echo "✅ 清理完成"
echo "=========================================="
echo ""
echo "💡 如果前端仍有重复，请："
echo "   1. 清除浏览器缓存 (Ctrl+Shift+R)"
echo "   2. 重新搜索测试"
echo ""

