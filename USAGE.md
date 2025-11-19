# 使用说明

## 系统功能

### 1. 用户注册和登录
- 支持用户名和密码注册
- JWT Token认证
- 自动保存登录状态

### 2. 菜品浏览
- 查看所有菜品
- 按分类筛选
- 关键词搜索
- 菜品详情查看

### 3. 个性化推荐
- 基于用户历史行为的协同过滤推荐
- 基于菜品特征的内容推荐
- 混合推荐算法

### 4. 评分功能
- 对菜品进行1-5星评分
- 查看平均评分
- 评分历史记录

### 5. 个人中心
- 查看个人信息
- 查看消费历史
- 查看评分记录

## API使用示例

### 用户注册
```bash
curl -X POST http://localhost:5000/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "password123",
    "email": "test@example.com"
  }'
```

### 用户登录
```bash
curl -X POST http://localhost:5000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "password123"
  }'
```

### 获取推荐
```bash
curl -X GET http://localhost:5000/api/v1/recommendations \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 创建评分
```bash
curl -X POST http://localhost:5000/api/v1/ratings \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "dish_id": 1,
    "rating": 5,
    "comment": "很好吃"
  }'
```

## 数据导入

### 导入菜品数据
```sql
INSERT INTO dishes (name, category, price, description) VALUES
('菜品名称', '分类', 价格, '描述');
```

### 导入消费记录
```sql
INSERT INTO consumption_records (user_id, dish_id, consumption_time, price, rating) VALUES
(1, 1, NOW(), 12.00, 5);
```

## 模型训练

### 手动训练模型
```bash
# 数据预处理
python backend/data/preprocessor.py

# 训练模型
python backend/train_model.py
```

### 自动训练（定时任务）
系统支持定时自动训练模型，可在config.py中配置训练时间。

## 性能调优

### 数据库优化
- 为常用查询字段添加索引
- 定期清理历史数据
- 使用连接池管理数据库连接

### Redis缓存
- 推荐结果缓存1小时
- 热门菜品缓存
- 用户会话缓存

### 算法优化
- 调整推荐算法参数
- 增加训练数据量
- 优化特征工程

## 故障处理

### 推荐结果为空
1. 检查是否有足够的评分数据
2. 检查模型是否已训练
3. 检查用户是否有历史行为

### 数据库连接失败
1. 检查MySQL服务状态
2. 检查数据库配置
3. 检查网络连接

### 前端无法加载
1. 检查后端服务是否启动
2. 检查端口是否被占用
3. 检查浏览器控制台错误

## 扩展功能

### 添加新功能
1. 在后端api目录添加新的API路由
2. 在前端views目录添加新的页面
3. 更新路由配置

### 自定义推荐算法
1. 在models目录实现新算法
2. 在HybridRecommender中集成
3. 调整权重参数

## 技术支持

如有问题，请查看：
- README.md - 项目概述
- INSTALL.md - 安装指南
- QUICKSTART.md - 快速开始
- PROJECT_SUMMARY.md - 项目总结
