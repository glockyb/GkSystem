#!/bin/bash
# ubuntu_20_04_deps_fixed.sh - 修复版 Ubuntu 20.04 依赖安装

echo "=== Ubuntu 20.04 依赖安装 (修复版) ==="

cd /root/gksys/backend

# 删除旧的虚拟环境
echo "1. 清理旧环境..."
rm -rf venv

# 创建新的虚拟环境
echo "2. 创建虚拟环境..."
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate

echo "3. 升级基础工具..."
pip3 install --upgrade pip setuptools wheel

# 修复：创建 pip 配置目录
echo "4. 配置pip镜像..."
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << 'EOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
timeout = 120
retries = 5
EOF

echo "✓ Pip 配置已创建"

echo "5. 安装兼容的包版本..."

# Ubuntu 20.04 (Python 3.8) 兼容的版本
COMPATIBLE_PACKAGES=(
    "numpy==1.21.6"
    "pandas==1.3.5"
    "flask==2.0.3"
    "sqlalchemy==1.4.46"
    "pymysql==1.0.3"
    "redis==4.5.4"
    "scikit-learn==1.0.2"
    "werkzeug==2.0.3"
    "jinja2==3.0.3"
)

# 逐个安装兼容包
for package in "${COMPATIBLE_PACKAGES[@]}"; do
    echo "安装: $package"
    if pip3 install --no-cache-dir "$package"; then
        echo "✓ $package 安装成功"
    else
        echo "✗ $package 安装失败，尝试替代版本..."
        # 尝试不指定版本
        package_name=$(echo "$package" | cut -d'=' -f1)
        pip3 install --no-cache-dir "$package_name"
    fi
    # 添加短暂延迟避免请求过快
    sleep 1
done

echo "6. 验证安装..."
python3 -c "
import sys
print(f'Python版本: {sys.version}')

packages = [
    ('numpy', 'numpy'),
    ('pandas', 'pandas'), 
    ('flask', 'flask'),
    ('sqlalchemy', 'sqlalchemy'),
    ('pymysql', 'pymysql'),
    ('redis', 'redis'),
    ('scikit-learn', 'sklearn')
]

for name, import_name in packages:
    try:
        if import_name == 'sklearn':
            module = __import__('sklearn')
            version = getattr(module, '__version__', '版本未知')
        else:
            module = __import__(import_name)
            version = getattr(module, '__version__', '版本未知')
        print(f'✓ {name}: {version}')
    except ImportError as e:
        print(f'✗ {name}: 导入失败')
    except Exception as e:
        print(f'⚠ {name}: 错误 - {str(e)[:50]}')
"

echo "=== 依赖安装完成 ==="