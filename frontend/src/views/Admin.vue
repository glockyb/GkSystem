<template>
  <div class="admin-container">
    <el-container>
      <!-- 侧边栏 -->
      <el-aside width="250px" class="admin-sidebar">
        <div class="sidebar-header">
          <h2>管理后台</h2>
        </div>
        <el-menu
          :default-active="activeMenu"
          @select="handleMenuSelect"
          class="admin-menu"
        >
          <el-menu-item index="stats">
            <el-icon><DataAnalysis /></el-icon>
            <span>数据统计</span>
          </el-menu-item>
          <el-menu-item index="dishes">
            <el-icon><Food /></el-icon>
            <span>菜品管理</span>
          </el-menu-item>
          <el-menu-item index="users">
            <el-icon><User /></el-icon>
            <span>用户管理</span>
          </el-menu-item>
          <el-menu-item index="ratings">
            <el-icon><Star /></el-icon>
            <span>评分管理</span>
          </el-menu-item>
        </el-menu>
      </el-aside>

      <!-- 主内容区 -->
      <el-main class="admin-main">
        <!-- 数据统计 -->
        <div v-if="activeMenu === 'stats'" class="stats-section">
          <h2 class="section-title">数据统计</h2>
          <el-row :gutter="20">
            <el-col :span="6">
              <el-card class="stat-card">
                <div class="stat-content">
                  <div class="stat-value">{{ stats.total_users || 0 }}</div>
                  <div class="stat-label">总用户数</div>
                </div>
              </el-card>
            </el-col>
            <el-col :span="6">
              <el-card class="stat-card">
                <div class="stat-content">
                  <div class="stat-value">{{ stats.total_dishes || 0 }}</div>
                  <div class="stat-label">总菜品数</div>
                </div>
              </el-card>
            </el-col>
            <el-col :span="6">
              <el-card class="stat-card">
                <div class="stat-content">
                  <div class="stat-value">{{ stats.total_ratings || 0 }}</div>
                  <div class="stat-label">总评分数</div>
                </div>
              </el-card>
            </el-col>
            <el-col :span="6">
              <el-card class="stat-card">
                <div class="stat-content">
                  <div class="stat-value">{{ stats.avg_rating?.toFixed(1) || '0.0' }}</div>
                  <div class="stat-label">平均评分</div>
                </div>
              </el-card>
            </el-col>
          </el-row>

          <el-card class="category-stats" style="margin-top: 20px;">
            <template #header>
              <span>分类统计</span>
            </template>
            <el-table :data="categoryStats" style="width: 100%">
              <el-table-column prop="category" label="分类" width="200" />
              <el-table-column prop="count" label="数量" />
            </el-table>
          </el-card>
        </div>

        <!-- 菜品管理 -->
        <div v-if="activeMenu === 'dishes'" class="dishes-section">
          <div class="section-header">
            <h2 class="section-title">菜品管理</h2>
            <el-button type="primary" @click="showDishDialog = true">
              <el-icon><Plus /></el-icon>
              添加菜品
            </el-button>
          </div>

          <div class="search-bar">
            <el-input
              v-model="dishSearch"
              placeholder="搜索菜品名称..."
              style="width: 300px; margin-right: 10px;"
              clearable
              @input="loadDishes"
            >
              <template #prefix>
                <el-icon><Search /></el-icon>
              </template>
            </el-input>
            <el-select
              v-model="dishCategory"
              placeholder="选择分类"
              style="width: 150px; margin-right: 10px;"
              clearable
              @change="loadDishes"
            >
              <el-option
                v-for="cat in categories"
                :key="cat"
                :label="cat"
                :value="cat"
              />
            </el-select>
          </div>

          <el-table :data="dishes" style="width: 100%; margin-top: 20px;" v-loading="dishesLoading">
            <el-table-column prop="id" label="ID" width="80" />
            <el-table-column prop="name" label="名称" />
            <el-table-column prop="category" label="分类" width="120" />
            <el-table-column prop="price" label="价格" width="100">
              <template #default="{ row }">
                ¥{{ row.price }}
              </template>
            </el-table-column>
            <el-table-column prop="rating_count" label="评分数" width="100" />
            <el-table-column prop="avg_rating" label="平均分" width="100">
              <template #default="{ row }">
                {{ row.avg_rating?.toFixed(1) || '0.0' }}
              </template>
            </el-table-column>
            <el-table-column label="操作" width="200" fixed="right">
              <template #default="{ row }">
                <el-button size="small" @click="editDish(row)">编辑</el-button>
                <el-button size="small" type="danger" @click="deleteDish(row.id)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>

          <el-pagination
            v-model:current-page="dishPage"
            :page-size="dishPageSize"
            :total="dishTotal"
            layout="prev, pager, next, total"
            @current-change="loadDishes"
            style="margin-top: 20px; justify-content: center;"
          />
        </div>

        <!-- 用户管理 -->
        <div v-if="activeMenu === 'users'" class="users-section">
          <div class="section-header">
            <h2 class="section-title">用户管理</h2>
          </div>

          <div class="search-bar">
            <el-input
              v-model="userSearch"
              placeholder="搜索用户名或邮箱..."
              style="width: 300px;"
              clearable
              @input="loadUsers"
            >
              <template #prefix>
                <el-icon><Search /></el-icon>
              </template>
            </el-input>
          </div>

          <el-table :data="users" style="width: 100%; margin-top: 20px;" v-loading="usersLoading">
            <el-table-column prop="id" label="ID" width="80" />
            <el-table-column prop="username" label="用户名" />
            <el-table-column prop="email" label="邮箱" />
            <el-table-column prop="role" label="角色" width="100">
              <template #default="{ row }">
                <el-tag :type="row.is_admin ? 'danger' : 'info'">
                  {{ row.is_admin ? '管理员' : '用户' }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="rating_count" label="评分数" width="100" />
            <el-table-column prop="consumption_count" label="消费次数" width="100" />
            <el-table-column label="操作" width="200" fixed="right">
              <template #default="{ row }">
                <el-button size="small" @click="editUser(row)">编辑</el-button>
                <el-button
                  size="small"
                  type="danger"
                  @click="deleteUser(row.id)"
                  :disabled="row.id == userId"
                >
                  删除
                </el-button>
              </template>
            </el-table-column>
          </el-table>

          <el-pagination
            v-model:current-page="userPage"
            :page-size="userPageSize"
            :total="userTotal"
            layout="prev, pager, next, total"
            @current-change="loadUsers"
            style="margin-top: 20px; justify-content: center;"
          />
        </div>

        <!-- 评分管理 -->
        <div v-if="activeMenu === 'ratings'" class="ratings-section">
          <div class="section-header">
            <h2 class="section-title">评分管理</h2>
          </div>

          <el-table :data="ratings" style="width: 100%; margin-top: 20px;" v-loading="ratingsLoading">
            <el-table-column prop="id" label="ID" width="80" />
            <el-table-column prop="username" label="用户" width="120" />
            <el-table-column prop="dish_name" label="菜品" />
            <el-table-column prop="rating" label="评分" width="100">
              <template #default="{ row }">
                <el-rate :model-value="row.rating" disabled />
              </template>
            </el-table-column>
            <el-table-column prop="comment" label="评论" show-overflow-tooltip />
            <el-table-column prop="created_at" label="时间" width="180" />
            <el-table-column label="操作" width="100" fixed="right">
              <template #default="{ row }">
                <el-button size="small" type="danger" @click="deleteRating(row.id)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>

          <el-pagination
            v-model:current-page="ratingPage"
            :page-size="ratingPageSize"
            :total="ratingTotal"
            layout="prev, pager, next, total"
            @current-change="loadRatings"
            style="margin-top: 20px; justify-content: center;"
          />
        </div>
      </el-main>
    </el-container>

    <!-- 菜品编辑对话框 -->
    <el-dialog
      v-model="showDishDialog"
      :title="editingDish ? '编辑菜品' : '添加菜品'"
      width="600px"
    >
      <el-form :model="dishForm" label-width="100px">
        <el-form-item label="名称" required>
          <el-input v-model="dishForm.name" />
        </el-form-item>
        <el-form-item label="分类">
          <el-select v-model="dishForm.category" placeholder="选择分类" style="width: 100%;">
            <el-option
              v-for="cat in categories"
              :key="cat"
              :label="cat"
              :value="cat"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="价格" required>
          <el-input-number v-model="dishForm.price" :min="0" :precision="2" style="width: 100%;" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="dishForm.description" type="textarea" :rows="3" />
        </el-form-item>
        <el-form-item label="图片URL">
          <el-input v-model="dishForm.image_url" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDishDialog = false">取消</el-button>
        <el-button type="primary" @click="saveDish">保存</el-button>
      </template>
    </el-dialog>

    <!-- 用户编辑对话框 -->
    <el-dialog
      v-model="showUserDialog"
      title="编辑用户"
      width="500px"
    >
      <el-form :model="userForm" label-width="100px">
        <el-form-item label="用户名">
          <el-input v-model="userForm.username" disabled />
        </el-form-item>
        <el-form-item label="邮箱">
          <el-input v-model="userForm.email" />
        </el-form-item>
        <el-form-item label="角色">
          <el-select v-model="userForm.role" style="width: 100%;">
            <el-option label="用户" value="user" />
            <el-option label="管理员" value="admin" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showUserDialog = false">取消</el-button>
        <el-button type="primary" @click="saveUser">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useUserStore } from '../store/user'
import api from '../api'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  DataAnalysis,
  Food,
  User,
  Star,
  Plus,
  Search
} from '@element-plus/icons-vue'

const userStore = useUserStore()
const userId = parseInt(userStore.userId) || 0

// 菜单状态
const activeMenu = ref('stats')

// 统计数据
const stats = ref({})
const categoryStats = computed(() => {
  if (!stats.value.categories) return []
  return Object.entries(stats.value.categories).map(([category, count]) => ({
    category: category || '未知',
    count
  }))
})

// 菜品管理
const dishes = ref([])
const dishesLoading = ref(false)
const dishSearch = ref('')
const dishCategory = ref('')
const categories = ref([])
const dishPage = ref(1)
const dishPageSize = ref(20)
const dishTotal = ref(0)
const showDishDialog = ref(false)
const editingDish = ref(null)
const dishForm = ref({
  name: '',
  category: '',
  price: 0,
  description: '',
  image_url: ''
})

// 用户管理
const users = ref([])
const usersLoading = ref(false)
const userSearch = ref('')
const userPage = ref(1)
const userPageSize = ref(20)
const userTotal = ref(0)
const showUserDialog = ref(false)
const editingUser = ref(null)
const userForm = ref({
  username: '',
  email: '',
  role: 'user'
})

// 评分管理
const ratings = ref([])
const ratingsLoading = ref(false)
const ratingPage = ref(1)
const ratingPageSize = ref(20)
const ratingTotal = ref(0)

// 加载统计数据
const loadStats = async () => {
  try {
    const response = await api.admin.getStats()
    if (response && response.stats) {
      stats.value = response.stats
    } else {
      console.warn('统计数据格式异常', response)
      stats.value = {
        total_users: 0,
        total_dishes: 0,
        total_ratings: 0,
        avg_rating: 0,
        categories: {}
      }
    }
  } catch (error) {
    console.error('加载统计数据失败', error)
    const errorMsg = error.response?.data?.error || error.message || '未知错误'
    console.error('错误详情:', {
      status: error.response?.status,
      error: errorMsg,
      url: error.config?.url
    })
    ElMessage.error(`加载统计数据失败: ${errorMsg}`)
    // 设置默认值，避免页面空白
    stats.value = {
      total_users: 0,
      total_dishes: 0,
      total_ratings: 0,
      avg_rating: 0,
      categories: {}
    }
  }
}

// 加载分类
const loadCategories = async () => {
  try {
    const response = await api.dishes.getCategories()
    categories.value = response.categories || []
  } catch (error) {
    console.error('加载分类失败', error)
  }
}

// 加载菜品
const loadDishes = async () => {
  dishesLoading.value = true
  try {
    const params = {
      page: dishPage.value,
      per_page: dishPageSize.value
    }
    if (dishSearch.value) {
      params.search = dishSearch.value
    }
    if (dishCategory.value) {
      params.category = dishCategory.value
    }
    const response = await api.admin.dishes.getList(params)
    dishes.value = response.dishes || []
    dishTotal.value = response.total || 0
  } catch (error) {
    console.error('加载菜品失败', error)
    ElMessage.error('加载菜品失败')
  } finally {
    dishesLoading.value = false
  }
}

// 编辑菜品
const editDish = (dish) => {
  editingDish.value = dish
  dishForm.value = {
    name: dish.name,
    category: dish.category,
    price: dish.price,
    description: dish.description || '',
    image_url: dish.image_url || ''
  }
  showDishDialog.value = true
}

// 保存菜品
const saveDish = async () => {
  if (!dishForm.value.name || dishForm.value.price === null) {
    ElMessage.warning('请填写必填项')
    return
  }

  try {
    if (editingDish.value) {
      await api.admin.dishes.update(editingDish.value.id, dishForm.value)
      ElMessage.success('更新成功')
    } else {
      await api.admin.dishes.create(dishForm.value)
      ElMessage.success('添加成功')
    }
    showDishDialog.value = false
    editingDish.value = null
    dishForm.value = {
      name: '',
      category: '',
      price: 0,
      description: '',
      image_url: ''
    }
    loadDishes()
  } catch (error) {
    console.error('保存菜品失败', error)
    ElMessage.error('保存菜品失败')
  }
}

// 删除菜品
const deleteDish = async (id) => {
  try {
    await ElMessageBox.confirm('确定要删除这个菜品吗？', '提示', {
      type: 'warning'
    })
    await api.admin.dishes.delete(id)
    ElMessage.success('删除成功')
    loadDishes()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('删除菜品失败', error)
      ElMessage.error('删除菜品失败')
    }
  }
}

// 加载用户
const loadUsers = async () => {
  usersLoading.value = true
  try {
    const params = {
      page: userPage.value,
      per_page: userPageSize.value
    }
    if (userSearch.value) {
      params.search = userSearch.value
    }
    const response = await api.admin.users.getList(params)
    users.value = response.users || []
    userTotal.value = response.total || 0
  } catch (error) {
    console.error('加载用户失败', error)
    ElMessage.error('加载用户失败')
  } finally {
    usersLoading.value = false
  }
}

// 编辑用户
const editUser = (user) => {
  editingUser.value = user
  userForm.value = {
    username: user.username,
    email: user.email || '',
    role: user.role || 'user'
  }
  showUserDialog.value = true
}

// 保存用户
const saveUser = async () => {
  try {
    await api.admin.users.update(editingUser.value.id, userForm.value)
    ElMessage.success('更新成功')
    showUserDialog.value = false
    editingUser.value = null
    loadUsers()
  } catch (error) {
    console.error('保存用户失败', error)
    ElMessage.error('保存用户失败')
  }
}

// 删除用户
const deleteUser = async (id) => {
  try {
    await ElMessageBox.confirm('确定要删除这个用户吗？', '提示', {
      type: 'warning'
    })
    await api.admin.users.delete(id)
    ElMessage.success('删除成功')
    loadUsers()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('删除用户失败', error)
      ElMessage.error('删除用户失败')
    }
  }
}

// 加载评分
const loadRatings = async () => {
  ratingsLoading.value = true
  try {
    const params = {
      page: ratingPage.value,
      per_page: ratingPageSize.value
    }
    const response = await api.admin.ratings.getList(params)
    ratings.value = response.ratings || []
    ratingTotal.value = response.total || 0
  } catch (error) {
    console.error('加载评分失败', error)
    ElMessage.error('加载评分失败')
  } finally {
    ratingsLoading.value = false
  }
}

// 删除评分
const deleteRating = async (id) => {
  try {
    await ElMessageBox.confirm('确定要删除这个评分吗？', '提示', {
      type: 'warning'
    })
    await api.admin.ratings.delete(id)
    ElMessage.success('删除成功')
    loadRatings()
  } catch (error) {
    if (error !== 'cancel') {
      console.error('删除评分失败', error)
      ElMessage.error('删除评分失败')
    }
  }
}

// 菜单选择
const handleMenuSelect = (key) => {
  activeMenu.value = key
  if (key === 'stats') {
    loadStats()
  } else if (key === 'dishes') {
    loadDishes()
    loadCategories()
  } else if (key === 'users') {
    loadUsers()
  } else if (key === 'ratings') {
    loadRatings()
  }
}

onMounted(async () => {
  // 检查登录状态
  if (!userStore.isLoggedIn) {
    ElMessage.error('请先登录')
    window.location.href = '/login'
    return
  }
  
  // 检查管理员权限
  if (!userStore.isAdminUser) {
    ElMessage.error('您没有管理员权限')
    // 延迟跳转，让用户看到错误信息
    setTimeout(() => {
      window.location.href = '/'
    }, 2000)
    return
  }
  
  // 加载数据 - 使用独立的try-catch，避免一个失败影响其他
  try {
    await loadStats()
  } catch (error) {
    console.error('加载统计数据失败', error)
    // 不阻止页面渲染，只显示警告
    ElMessage.warning('加载统计数据失败，部分功能可能不可用')
  }
  
  try {
    await loadCategories()
  } catch (error) {
    console.error('加载分类失败', error)
    // 不阻止页面渲染
    ElMessage.warning('加载分类失败，部分功能可能不可用')
  }
  
  // 如果当前选中的是其他菜单项，也加载对应数据
  if (activeMenu.value === 'dishes') {
    try {
      await loadDishes()
    } catch (error) {
      console.error('加载菜品失败', error)
    }
  } else if (activeMenu.value === 'users') {
    try {
      await loadUsers()
    } catch (error) {
      console.error('加载用户失败', error)
    }
  } else if (activeMenu.value === 'ratings') {
    try {
      await loadRatings()
    } catch (error) {
      console.error('加载评分失败', error)
    }
  }
})
</script>

<style scoped>
.admin-container {
  min-height: 100vh;
  background: #f5f5f5;
}

.admin-sidebar {
  background: #fff;
  border-right: 1px solid #e4e7ed;
  height: 100vh;
  position: fixed;
  left: 0;
  top: 0;
}

.sidebar-header {
  padding: 20px;
  border-bottom: 1px solid #e4e7ed;
}

.sidebar-header h2 {
  margin: 0;
  color: #303133;
  font-size: 20px;
}

.admin-menu {
  border: none;
}

.admin-main {
  margin-left: 250px;
  padding: 20px;
  min-height: 100vh;
}

.section-title {
  margin: 0 0 20px 0;
  color: #303133;
  font-size: 24px;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.search-bar {
  margin-bottom: 20px;
}

.stat-card {
  text-align: center;
}

.stat-content {
  padding: 20px;
}

.stat-value {
  font-size: 36px;
  font-weight: bold;
  color: #409eff;
  margin-bottom: 10px;
}

.stat-label {
  font-size: 14px;
  color: #909399;
}

.category-stats {
  margin-top: 20px;
}
</style>

