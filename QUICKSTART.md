# 快速开始指南

## 5分钟快速启动

### 使用Docker（最简单）

```bash
# 1. 启动所有服务
docker-compose up -d

# 2. 等待MySQL启动（约30秒），然后初始化数据
docker-compose exec backend python data/preprocessor.py
docker-compose exec backend python train_model.py

# 3. 访问系统
# 前端: http://localhost:8080
# 后端: http://localhost:5000
```

### 本地开发

#### 后端

```bash
cd backend
pip install -r requirements.txt
python app.py
```

#### 前端

```bash
cd frontend
npm install
npm run dev
```

## 首次使用

1. 访问 http://localhost:8080
2. 点击"登录/注册"
3. 注册新账号
4. 浏览菜品并进行评分
5. 查看个性化推荐

## 常见问题

**Q: 数据库连接失败？**
A: 确保MySQL服务已启动，检查config.py中的数据库配置

**Q: Redis连接失败？**
A: 确保Redis服务已启动，推荐功能可能受影响但系统仍可运行

**Q: 没有推荐结果？**
A: 首次使用需要先进行数据预处理和模型训练

**Q: 前端无法连接后端？**
A: 检查后端服务是否在5000端口运行，检查CORS配置

## 下一步

- 查看 README.md 了解详细功能
- 查看 INSTALL.md 了解完整安装步骤
- 添加更多菜品数据以提高推荐质量
