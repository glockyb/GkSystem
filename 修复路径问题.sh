#!/bin/bash

# 修复所有脚本中的路径问题
# 自动检测项目路径并更新脚本

set -e

echo "=========================================="
echo "🔧 修复脚本路径问题"
echo "=========================================="

# 获取脚本所在目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo "检测到项目路径: $PROJECT_DIR"
echo ""

# 检查是否是有效的项目目录
if [ ! -d "$PROJECT_DIR/frontend" ] || [ ! -d "$PROJECT_DIR/backend" ]; then
    echo "❌ 当前目录不是有效的项目根目录"
    echo "请确保在项目根目录运行此脚本"
    exit 1
fi

echo "✅ 项目目录验证通过"
echo ""

# 需要修复的脚本列表
SCRIPTS_TO_FIX=(
    "修复登录和图片问题.sh"
    "重新部署前端修复.sh"
    "修复后台管理系统.sh"
    "诊断后台管理页面.sh"
    "修复所有问题.sh"
    "初始化管理员账户.sh"
    "快速创建管理员账户.sh"
)

# 修复脚本中的路径
FIXED_COUNT=0
for script in "${SCRIPTS_TO_FIX[@]}"; do
    if [ -f "$PROJECT_DIR/$script" ]; then
        echo "修复: $script"
        # 替换硬编码路径为自动检测
        sed -i.bak "s|cd ~/gksys/GkSystem |||g" "$PROJECT_DIR/$script" 2>/dev/null || true
        sed -i.bak "s|cd ~/gksys/GkSystem||g" "$PROJECT_DIR/$script" 2>/dev/null || true
        
        # 在脚本开头添加自动检测路径的代码（如果还没有）
        if ! grep -q "SCRIPT_DIR=" "$PROJECT_DIR/$script"; then
            # 在 set -e 之后添加路径检测
            sed -i.bak '/^set -e$/a\
# 自动检测项目路径\
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"\
cd "$SCRIPT_DIR" || exit 1
' "$PROJECT_DIR/$script" 2>/dev/null || true
        fi
        
        # 删除备份文件
        rm -f "$PROJECT_DIR/$script.bak" 2>/dev/null || true
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
done

echo ""
echo "✅ 已修复 $FIXED_COUNT 个脚本"
echo ""
echo "现在所有脚本都会自动检测项目路径，不再依赖硬编码路径"
echo ""

