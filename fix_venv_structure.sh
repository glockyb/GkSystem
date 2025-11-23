#!/bin/bash
# fix_venv_structure.sh - 修复虚拟环境目录结构

echo "=== 修复虚拟环境目录结构 ==="

cd backend

# 检查当前虚拟环境结构
echo "当前虚拟环境结构:"
find venv -type d -name "bin" -o -name "Scripts" | head -10

# 如果存在Scripts目录但不存在bin目录，创建符号链接
if [ -d "venv/Scripts" ] && [ ! -d "venv/bin" ]; then
    echo "检测到Windows风格的虚拟环境结构，创建兼容性链接..."
    
    # 创建bin目录的符号链接指向Scripts
    ln -s Scripts venv/bin
    echo "已创建 venv/bin -> Scripts 符号链接"
    
    # 验证修复
    if [ -f "venv/bin/activate" ]; then
        echo "✓ 修复成功: venv/bin/activate 现在可访问"
    else
        echo "✗ 修复失败"
    fi
elif [ -d "venv/bin" ]; then
    echo "✓ 虚拟环境结构正常"
else
    echo "✗ 虚拟环境结构异常，无法修复"
fi

echo "=== 修复完成 ==="