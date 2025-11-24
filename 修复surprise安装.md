# 修复 scikit-surprise 安装问题

## 🔍 问题描述

安装 scikit-surprise 时出现错误：
```
fatal error: Python.h: No such file or directory
error: command '/usr/bin/x86_64-linux-gnu-gcc' failed with exit code 1
```

## ✅ 解决方案

### 方法一：安装 Python 开发头文件（推荐）

```bash
# 运行安装脚本
cd ~/GkSystem
chmod +x install-python-dev.sh
sudo ./install-python-dev.sh
```

### 方法二：手动安装

#### Ubuntu/Debian

```bash
# 安装 Python 3.9 开发头文件
sudo apt-get update
sudo apt-get install -y python3.9-dev

# 或安装通用 Python 3 开发头文件
sudo apt-get install -y python3-dev

# 安装编译工具
sudo apt-get install -y build-essential gcc g++ make
```

#### CentOS/RHEL

```bash
# 安装 Python 3.9 开发头文件
sudo yum install -y python39-devel

# 或安装通用 Python 3 开发头文件
sudo yum install -y python3-devel

# 安装编译工具
sudo yum groupinstall -y "Development Tools"
```

### 方法三：安装后重新安装 scikit-surprise

```bash
cd ~/GkSystem/backend
source venv/bin/activate

# 先安装构建依赖
pip3 install Cython numpy

# 然后安装 scikit-surprise
pip3 install scikit-surprise -i https://pypi.tuna.tsinghua.edu.cn/simple
```

## 🔧 完整修复流程

### 步骤1：安装系统依赖

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y python3-dev build-essential gcc g++

# CentOS/RHEL
sudo yum install -y python3-devel gcc gcc-c++ make
```

### 步骤2：安装 Python 构建依赖

```bash
cd ~/GkSystem/backend
source venv/bin/activate

pip3 install --upgrade pip setuptools wheel
pip3 install Cython numpy
```

### 步骤3：安装 scikit-surprise

```bash
# 尝试安装预编译包（避免编译）
pip3 install scikit-surprise --only-binary :all: -i https://pypi.tuna.tsinghua.edu.cn/simple

# 如果失败，从源码编译
pip3 install scikit-surprise -i https://pypi.tuna.tsinghua.edu.cn/simple
```

### 步骤4：验证安装

```bash
python3 -c "import surprise; print('surprise OK')"
```

## 📋 检查清单

- [ ] Python 开发头文件已安装（python3-dev）
- [ ] 编译工具已安装（gcc, g++, make）
- [ ] Cython 已安装
- [ ] numpy 已安装
- [ ] scikit-surprise 安装成功

## 🚨 如果仍然失败

### 选项1：使用预编译的 wheel 包

```bash
# 查找预编译包
pip3 install scikit-surprise --only-binary :all: -i https://pypi.tuna.tsinghua.edu.cn/simple
```

### 选项2：使用替代实现

如果 scikit-surprise 无法安装，可以：
1. 暂时跳过协同过滤功能
2. 只使用内容推荐功能
3. 系统仍可正常运行

### 选项3：升级 Python 版本

Python 3.9+ 对 scikit-surprise 的支持更好：

```bash
# 检查是否有 Python 3.10
python3.10 --version

# 如果有，重新创建虚拟环境
cd ~/GkSystem/backend
rm -rf venv
python3.10 -m venv venv
source venv/bin/activate
pip3 install -r requirements.txt
```

## 📚 相关脚本

- `install-python-dev.sh` - 安装 Python 开发头文件
- `fix-surprise-install.sh` - 修复 scikit-surprise 安装

---

**记住：安装 scikit-surprise 需要 Python 开发头文件！**

