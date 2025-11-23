#!/bin/bash
# final_test_and_start.sh - 最终测试和启动

echo "=== 最终测试和启动 ==="

cd /root/gksys/backend

# 激活虚拟环境
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
else
    echo "错误: 虚拟环境不存在"
    exit 1
fi

echo "环境检查:"
echo "Python路径: $(which python3)"
echo "虚拟环境: $VIRTUAL_ENV"

echo "依赖检查:"
python3 << 'EOF'
import sys

required_packages = [
    ('flask', 'Flask'),
    ('pymysql', 'PyMySQL'),
    ('sqlalchemy', 'SQLAlchemy'), 
    ('redis', 'Redis')
]

optional_packages = [
    ('numpy', 'NumPy'),
    ('pandas', 'Pandas'),
    ('sklearn', 'Scikit-learn')
]

print("必要依赖:")
missing_required = []
for module, name in required_packages:
    try:
        __import__(module)
        print(f"  ✓ {name}")
    except ImportError:
        print(f"  ✗ {name}")
        missing_required.append(name)

print("\n可选依赖:")
for module, name in optional_packages:
    try:
        __import__(module)
        print(f"  ✓ {name}")
    except ImportError:
        print(f"  ✗ {name}")

if missing_required:
    print(f"\n错误: 缺少必要依赖: {', '.join(missing_required)}")
    sys.exit(1)
else:
    print("\n✓ 所有必要依赖都已安装")
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "启动后端服务..."
    echo "服务将在 http://localhost:5000 启动"
    echo "按 Ctrl+C 停止服务"
    echo ""
    python3 app.py
else
    echo "依赖检查失败，无法启动服务"
    exit 1
fi