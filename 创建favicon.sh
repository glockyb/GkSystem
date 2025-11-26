#!/bin/bash

# 创建 favicon.ico

cd ~/gksys/GkSystem || exit 1

echo "创建 favicon.ico..."

# 检查 frontend/public 目录
mkdir -p frontend/public

# 如果有 ImageMagick，创建简单的 favicon
if command -v convert >/dev/null 2>&1; then
    convert -size 32x32 xc:#409EFF \
            -fill white \
            -pointsize 24 \
            -gravity center \
            -annotate +0+0 "G" \
            frontend/public/favicon.ico
    echo "✅ 使用 ImageMagick 创建 favicon.ico"
elif command -v python3 >/dev/null 2>&1; then
    # 使用 Python PIL 创建
    python3 << 'PYTHON'
from PIL import Image, ImageDraw, ImageFont
import os

# 创建 32x32 的图片
img = Image.new('RGB', (32, 32), color='#409EFF')
draw = ImageDraw.Draw(img)

# 尝试绘制字母 G
try:
    # 尝试使用默认字体
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
except:
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 20)
    except:
        font = ImageFont.load_default()

# 绘制字母 G
draw.text((16, 16), "G", fill="white", font=font, anchor="mm")

# 保存
os.makedirs("frontend/public", exist_ok=True)
img.save("frontend/public/favicon.ico", "ICO")
print("✅ 使用 Python PIL 创建 favicon.ico")
PYTHON
else
    # 创建一个简单的 SVG favicon（浏览器可能不支持，但至少不会 404）
    cat > frontend/public/favicon.ico << 'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32">
  <rect width="32" height="32" fill="#409EFF"/>
  <text x="16" y="22" font-family="Arial" font-size="20" font-weight="bold" fill="white" text-anchor="middle">G</text>
</svg>
SVG
    echo "⚠️ 创建了 SVG 格式的 favicon（可能不是标准 ICO 格式）"
    echo "建议手动添加 favicon.ico 文件到 frontend/public/"
fi

echo ""
echo "✅ favicon.ico 已创建在 frontend/public/"
echo "重新构建前端后，favicon 将生效"

