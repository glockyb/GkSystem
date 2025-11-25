#!/bin/bash
# 立即修复 MySQL 认证 - 简化版

echo "=========================================="
echo "立即修复 MySQL 认证问题"
echo "=========================================="
echo ""

echo "步骤1: 修改 MySQL root 用户..."
sudo mysql <<'EOF'
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';
FLUSH PRIVILEGES;
SELECT user, host, plugin FROM mysql.user WHERE user='root';
EOF

echo ""
echo "步骤2: 更新后端服务配置..."
sudo sed -i '/Environment="FLASK_DEBUG=False"/a\
Environment="MYSQL_HOST=localhost"\
Environment="MYSQL_PORT=3306"\
Environment="MYSQL_USER=root"\
Environment="MYSQL_PASSWORD=password"\
Environment="MYSQL_DATABASE=canteen_recommendation"
' /etc/systemd/system/canteen-backend.service

echo ""
echo "步骤3: 重新加载并重启服务..."
sudo systemctl daemon-reload
sudo systemctl restart canteen-backend
sleep 5

echo ""
echo "步骤4: 测试 API..."
sleep 3
curl -s http://localhost:5000/health
echo ""
curl -s http://localhost:5000/api/v1/dishes/categories
echo ""

echo "=========================================="
echo "修复完成！"
echo "=========================================="

