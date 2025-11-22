#!/bin/bash
# diagnose_python.sh - Python环境诊断脚本

echo "=== Python环境诊断 ==="

# 检查Python
echo "1. 检查Python:"
command -v python3 && python3 --version || echo "Python3 未安装"

# 检查pip
echo -e "\n2. 检查pip:"
command -v pip3 && pip3 --version || echo "pip3 未安装"

# 检查venv模块
echo -e "\n3. 检查venv模块:"
python3 -c "import venv; print('venv模块可用')" 2>/dev/null || echo "venv模块不可用"

# 检查当前目录
echo -e "\n4. 当前目录: $(pwd)"
echo "目录内容:"
ls -la

# 检查backend目录
echo -e "\n5. 检查backend目录:"
if [ -d "backend" ]; then
    echo "backend目录存在"
    ls -la backend/
else
    echo "backend目录不存在"
fi

# 尝试创建测试虚拟环境
echo -e "\n6. 测试虚拟环境创建:"
mkdir -p test_venv
cd test_venv
python3 -m venv test_env 2>&1
if [ $? -eq 0 ]; then
    echo "虚拟环境创建成功"
    echo "虚拟环境结构:"
    find test_env -name "activate" -type f
else
    echo "虚拟环境创建失败"
fi
cd ..
rm -rf test_venv

echo -e "\n=== 诊断完成 ==="