#!/bin/bash
# detailed_python_diagnose.sh - 详细Python环境诊断

echo "=== 详细Python环境诊断 ==="

# 系统信息
echo "1. 系统信息:"
lsb_release -a 2>/dev/null || cat /etc/os-release
echo ""

# Python环境
echo "2. Python环境:"
echo "Python3 路径: $(which python3 2>/dev/null || echo '未找到')"
python3 --version 2>/dev/null || echo "无法获取Python版本"
echo ""

# 检查venv模块
echo "3. 检查venv模块:"
python3 -c "import venv; print('venv模块可用'); print('venv路径:', venv.__file__)" 2>/dev/null || echo "venv模块不可用"
echo ""

# 检查pip和setuptools
echo "4. 检查pip和setuptools:"
python3 -c "import pip; print('pip版本:', pip.__version__)" 2>/dev/null || echo "pip不可用"
python3 -c "import setuptools; print('setuptools可用')" 2>/dev/null || echo "setuptools不可用"
echo ""

# 磁盘空间检查
echo "5. 磁盘空间:"
df -h . | tail -1
echo ""

# 权限检查
echo "6. 权限检查:"
echo "当前用户: $(whoami)"
echo "当前目录: $(pwd)"
echo "目录权限:"
ls -la . | head -10
echo ""

# 尝试创建测试虚拟环境并显示详细输出
echo "7. 测试虚拟环境创建:"
mkdir -p test_diagnose
cd test_diagnose
echo "创建测试虚拟环境..."
python3 -m venv test_env 2>&1
RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "✓ 虚拟环境创建成功"
    echo "虚拟环境结构:"
    find test_env -type f -name "activate" -o -name "python" | head -10
else
    echo "✗ 虚拟环境创建失败，退出码: $RESULT"
    echo "详细错误:"
    python3 -m venv test_env 2>&1
fi
cd ..
rm -rf test_diagnose

echo "=== 诊断完成 ==="