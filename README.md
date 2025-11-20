# 校园食堂菜品推荐系统

一个基于机器学习的智能食堂菜品推荐系统，帮助用户发现符合个人口味的菜品。

## ✨ 特性

- 🎯 **智能推荐**: 基于协同过滤算法的个性化菜品推荐
- 🍽️ **菜品浏览**: 丰富的菜品展示和分类浏览
- ⭐ **评分系统**: 用户可以对菜品进行评分，提升推荐准确性
- 📊 **个人中心**: 查看个人信息和消费历史
- 🎨 **现代化UI**: 美观流畅的用户界面
- 🐳 **Docker部署**: 一键部署，开箱即用

## 🛠️ 技术栈

### 前端
- Vue 3 + Vite
- Element Plus
- Vue Router
- Pinia
- Axios

### 后端
- Python Flask
- MySQL
- Redis
- 协同过滤推荐算法

### 部署
- Docker & Docker Compose
- Nginx

## 🚀 快速开始

### 本地开发

#### 前端
```bash
cd frontend
npm install
npm run dev
```

#### 后端
```bash
cd backend
pip install -r requirements.txt
python app.py
```

### Docker 部署（推荐）

#### 本地部署
```bash
# 启动所有服务
./start-docker.sh

# 或使用 docker-compose
docker-compose up -d --build
```

访问地址：
- 前端: http://localhost:8080
- 后端 API: http://localhost:5000

#### 远端服务器部署

1. **上传项目到服务器**
```bash
# 使用 Git
git clone <your-repo-url> GkSystem
cd GkSystem

# 或使用 SCP
scp -r GkSystem username@server-ip:/path/to/
```

2. **运行部署脚本**
```bash
chmod +x deploy-remote.sh
./deploy-remote.sh
```

3. **手动部署**
```bash
# 构建并启动
docker-compose up -d --build

# 初始化数据
docker-compose exec backend python data/preprocessor.py
docker-compose exec backend python train_model.py
```

详细部署文档请查看 [DOCKER_DEPLOY.md](./DOCKER_DEPLOY.md)

## 📁 项目结构

```
GkSystem/
├── frontend/          # 前端项目
│   ├── src/
│   │   ├── api/      # API 接口
│   │   ├── components/ # 组件
│   │   ├── views/     # 页面
│   │   ├── router/    # 路由
│   │   └── store/     # 状态管理
│   ├── Dockerfile
│   └── nginx.conf
├── backend/           # 后端项目
│   ├── api/          # API 路由
│   ├── models/       # 推荐模型
│   ├── database/     # 数据库脚本
│   ├── data/         # 数据处理
│   ├── Dockerfile
│   └── app.py
├── docker-compose.yml # Docker 编排文件
├── deploy-remote.sh   # 远端部署脚本
└── DOCKER_DEPLOY.md   # 部署文档
```

## 🔧 配置说明

### 环境变量

创建 `.env` 文件（可选）：
```env
# 前端 API 地址
VITE_API_URL=http://localhost:5000

# MySQL 配置
MYSQL_ROOT_PASSWORD=your-password
MYSQL_DATABASE=canteen_recommendation
```

### 端口配置

默认端口：
- 前端: 8080
- 后端: 5000
- MySQL: 3306
- Redis: 6379

修改端口请编辑 `docker-compose.yml`

## 📖 使用指南

1. **注册/登录**: 首次使用需要注册账号
2. **浏览菜品**: 在"全部菜品"标签页浏览所有菜品
3. **评分菜品**: 对品尝过的菜品进行评分
4. **查看推荐**: 登录后在"推荐菜品"标签页查看个性化推荐
5. **个人中心**: 查看个人信息和消费历史

## 🔍 常用命令

```bash
# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 进入容器
docker-compose exec backend bash
docker-compose exec frontend sh
```

## 🐛 故障排查

### 常见问题

1. **端口被占用**
   - 修改 `docker-compose.yml` 中的端口映射
   - 或停止占用端口的服务

2. **数据库连接失败**
   - 检查 MySQL 容器是否正常运行
   - 检查环境变量配置

3. **前端无法连接后端**
   - 检查后端服务是否启动
   - 检查 nginx 配置
   - 查看浏览器控制台错误信息

详细故障排查请查看 [DOCKER_DEPLOY.md](./DOCKER_DEPLOY.md#-故障排查)

## 🔒 安全建议

- 生产环境请修改默认密码
- 配置防火墙规则
- 使用 HTTPS（配置 SSL 证书）
- 定期备份数据
- 监控系统资源

## 📝 开发计划

- [ ] 添加菜品详情页
- [ ] 优化推荐算法
- [ ] 添加收藏功能
- [ ] 支持多语言
- [ ] 移动端适配

## 📄 许可证

MIT License

## 👥 贡献

欢迎提交 Issue 和 Pull Request！

---

**如有问题，请查看 [DOCKER_DEPLOY.md](./DOCKER_DEPLOY.md) 获取详细帮助**
