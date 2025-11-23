#!/bin/bash
# project_structure_diagnose.sh - 项目结构诊断

echo "=== 项目结构诊断 ==="

# 当前目录
echo "1. 当前工作目录: $(pwd)"
echo ""

# 检查项目根目录结构
echo "2. 项目根目录结构:"
ls -la
echo ""

# 检查backend目录
echo "3. backend目录检查:"
if [ -d "backend" ]; then
    echo "✓ backend目录存在"
    echo "backend目录内容:"
    ls -la backend/
    echo ""
    
    # 检查backend目录中的venv
    echo "4. backend/venv 检查:"
    if [ -d "backend/venv" ]; then
        echo "✓ backend/venv 目录存在"
        echo "venv目录内容:"
        ls -la backend/venv/
        echo ""
        echo "venv/bin 目录内容:"
        ls -la backend/venv/bin/ 2>/dev/null || echo "venv/bin 目录不存在或无法访问"
        echo ""
        echo "activate 脚本检查:"
        find backend/venv -name "activate" -type f 2>/dev/null
    else
        echo "✗ backend/venv 目录不存在"
    fi
else
    echo "✗ backend 目录不存在"
fi

echo ""

# 检查脚本执行位置
echo "5. 脚本执行位置检查:"
echo "启动脚本路径: $0"
echo "启动脚本目录: $(dirname "$0")"
echo ""

# 检查相对路径
echo "6. 相对路径检查:"
echo "从当前目录到backend/venv/bin/activate:"
if [ -f "backend/venv/bin/activate" ]; then
    echo "✓ backend/venv/bin/activate 存在"
else
    echo "✗ backend/venv/bin/activate 不存在"
    
    # 查找所有activate文件
    echo "在整个项目中查找activate文件:"
    find . -name "activate" -type f 2>/dev/null
fi

echo "=== 诊断完成 ==="