#!/bin/bash

# 检查前端资源文件

echo "=========================================="
echo "🔍 检查前端资源文件"
echo "=========================================="

cd ~/gksys/GkSystem || exit 1

echo ""
echo "ℹ️ 检查 frontend/dist 目录结构..."
ls -lh frontend/dist/

echo ""
echo "ℹ️ 检查 assets 目录内容..."
if [ -d "frontend/dist/assets" ]; then
    echo "✅ assets 目录存在"
    echo "文件列表："
    ls -lh frontend/dist/assets/
    
    js_files=$(find frontend/dist/assets -name "*.js" | wc -l)
    css_files=$(find frontend/dist/assets -name "*.css" | wc -l)
    
    echo ""
    echo "统计："
    echo "  JS 文件: $js_files"
    echo "  CSS 文件: $css_files"
    
    if [ "$js_files" -gt 0 ]; then
        echo "✅ JS 文件存在，构建正常"
        echo "JS 文件详情："
        find frontend/dist/assets -name "*.js" -exec ls -lh {} \;
    else
        echo "❌ 没有 JS 文件，构建可能失败"
    fi
    
    if [ "$css_files" -gt 0 ]; then
        echo "✅ CSS 文件存在"
        echo "CSS 文件详情："
        find frontend/dist/assets -name "*.css" -exec ls -lh {} \;
    fi
else
    echo "❌ assets 目录不存在"
fi

echo ""
echo "ℹ️ 检查 index.html 内容..."
if [ -f "frontend/dist/index.html" ]; then
    echo "index.html 前20行："
    head -20 frontend/dist/index.html
fi

echo ""
echo "ℹ️ 检查部署目录 /var/www/canteen..."
if [ -d "/var/www/canteen" ]; then
    echo "✅ 部署目录存在"
    echo "文件列表："
    sudo ls -lh /var/www/canteen/
    
    if [ -d "/var/www/canteen/assets" ]; then
        echo ""
        echo "部署的 assets 目录："
        sudo ls -lh /var/www/canteen/assets/ | head -10
    fi
else
    echo "❌ 部署目录不存在"
fi

echo ""
echo "=========================================="
echo "✅ 检查完成"
echo "=========================================="

