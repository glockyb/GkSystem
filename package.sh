#!/bin/bash

# 打包脚本 - 用于分享项目

echo "开始打包项目..."

# 项目名称
PROJECT_NAME="canteen-recommendation-system"
OUTPUT_FILE="${PROJECT_NAME}.tar.gz"

# 排除的文件和目录
EXCLUDE_LIST=(
    "node_modules"
    "__pycache__"
    "*.pyc"
    ".git"
    ".env"
    "venv"
    "*.log"
    "models/*.pkl"
    "dist"
    ".DS_Store"
)

# 构建排除参数
EXCLUDE_ARGS=""
for item in "${EXCLUDE_LIST[@]}"; do
    EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=$item"
done

# 创建压缩包
tar -czf "$OUTPUT_FILE" $EXCLUDE_ARGS "$PROJECT_NAME"

echo "打包完成: $OUTPUT_FILE"
echo "文件大小: $(du -h $OUTPUT_FILE | cut -f1)"
