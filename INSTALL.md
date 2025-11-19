# 安装和部署指南

## 系统要求

- Docker 20.10+ 和 Docker Compose 2.0+ (推荐方式)
- 或 Python 3.8+, Node.js 16+, MySQL 8.0+, Redis 6.0+ (本地开发)

## 方式一：Docker部署（推荐）

### 1. 克隆或下载项目

```bash
# 如果是压缩包，解压
tar -xzf canteen-recommendation-system.tar.gz
cd canteen-recommendation-system
```

### 2. 启动服务

```bash
docker-compose up -d
```

### 3. 初始化数据

等待MySQL启动完成后（约30秒），初始化数据：

```bash
# 数据已通过init.sql自动初始化
# 运行数据预处理
docker-compose exec backend python data/preprocessor.py

# 训练模型
docker-compose exec backend python train_model.py
```

### 4. 访问系统

- 前端: http://localhost:8080
- 后端API: http://localhost:5000
- API文档: http://localhost:5000/health

### 5. 停止服务

```bash
docker-compose down
```

## 方式二：本地开发

### 后端设置

1. 安装Python依赖

```bash
cd backend
pip install -r requirements.txt
# 或使用虚拟环境
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

2. 配置MySQL

```bash
# 启动MySQL服务
# 创建数据库
mysql -u root -p < database/init.sql
```

3. 配置Redis

```bash
# 启动Redis服务
redis-server
```

4. 配置环境变量（可选）

创建 `backend/.env` 文件：

```env
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=your_password
MYSQL_DATABASE=canteen_recommendation
REDIS_HOST=localhost
REDIS_PORT=6379
```

5. 数据预处理和模型训练

```bash
python data/preprocessor.py
python train_model.py
```

6. 启动后端服务

```bash
python app.py
# 或使用启动脚本
./start.sh
```

### 前端设置

1. 安装Node.js依赖

```bash
cd frontend
npm install
```

2. 启动开发服务器

```bash
npm run dev
```

3. 构建生产版本

```bash
npm run build
```

## 故障排查

### 数据库连接失败

- 检查MySQL服务是否启动
- 检查数据库配置是否正确
- 检查数据库用户权限

### Redis连接失败

- 检查Redis服务是否启动
- 检查Redis配置是否正确
- 推荐功能可能受影响，但系统仍可运行

### 模型训练失败

- 确保数据库中有足够的评分数据
- 检查dish_features表是否有数据
- 可以跳过模型训练，系统会使用默认推荐

### 前端无法连接后端

- 检查后端服务是否启动
- 检查端口是否被占用
- 检查CORS配置

## 生产环境部署

### 安全建议

1. 修改默认密码和密钥
2. 使用环境变量管理敏感信息
3. 启用HTTPS
4. 配置防火墙规则
5. 定期备份数据库

### 性能优化

1. 配置Nginx反向代理
2. 启用Redis缓存
3. 使用CDN加速静态资源
4. 优化数据库索引
5. 定期更新推荐模型

## 技术支持

如有问题，请查看README.md或提交Issue。
