<template>
  <div class="home fade-in">
    <el-tabs v-model="activeTab" @tab-change="handleTabChange" class="modern-tabs">
      <el-tab-pane label="推荐菜品" name="recommendations">
        <div v-if="recommendedDishes.length === 0 && !recommendationsLoading" class="empty-state">
          <el-icon class="empty-icon"><Box /></el-icon>
          <p>暂无推荐菜品，请先登录并评分一些菜品</p>
          <el-button type="primary" @click="activeTab = 'all'" class="goto-dishes-btn">
            去浏览菜品
          </el-button>
        </div>
        <!-- 骨架屏加载 -->
        <div v-if="recommendationsLoading" class="dishes-grid skeleton-grid">
          <el-skeleton v-for="n in 6" :key="n" animated class="skeleton-card">
            <template #template>
              <el-skeleton-item variant="rect" style="width: 100%; height: 220px;" />
              <div style="padding: 20px;">
                <el-skeleton-item variant="h3" style="width: 60%; margin-bottom: 12px;" />
                <el-skeleton-item variant="text" style="width: 40%; margin-bottom: 8px;" />
                <el-skeleton-item variant="text" style="width: 100%;" />
                <el-skeleton-item variant="text" style="width: 80%; margin-top: 16px;" />
              </div>
            </template>
          </el-skeleton>
        </div>
        <div class="dishes-grid" v-show="!recommendationsLoading">
          <el-card
            v-for="(dish, index) in recommendedDishes"
            :key="dish.id"
            class="dish-card modern-card"
            :body-style="{ padding: '0px' }"
            :style="{ animationDelay: `${index * 0.1}s` }"
          >
            <div class="dish-image-wrapper">
              <img 
                :src="dish.image_url || '/placeholder.jpg'" 
                class="dish-image"
                @error="handleImageError"
              />
              <div class="dish-badge" v-if="dish.category">
                {{ dish.category }}
              </div>
            </div>
            <div class="dish-info">
              <h3 class="dish-name">{{ dish.name }}</h3>
              <p class="dish-price">
                <span class="price-symbol">¥</span>
                <span class="price-value">{{ dish.price }}</span>
              </p>
              <p class="dish-description" v-if="dish.description">
                {{ dish.description }}
              </p>
              <div class="dish-rating">
                <el-rate
                  v-model="dish.rating"
                  :max="5"
                  :colors="['#99A9BF', '#F7BA2A', '#FF9900']"
                  @change="handleRatingChange(dish.id, $event)"
                />
                <span class="rating-text" v-if="dish.rating">
                  {{ dish.rating }}分
                </span>
              </div>
              <div class="dish-actions">
                <el-button 
                  type="primary" 
                  @click="viewDish(dish.id)"
                  class="view-btn"
                  :icon="View"
                >
                  查看详情
                </el-button>
              </div>
            </div>
          </el-card>
        </div>
      </el-tab-pane>
      <el-tab-pane label="全部菜品" name="all">
        <div class="search-section">
          <el-input
            v-model="searchQuery"
            placeholder="搜索菜品名称..."
            class="search-input"
            @input="handleSearch"
            clearable
          >
            <template #prefix>
              <el-icon><Search /></el-icon>
            </template>
          </el-input>
          <el-select 
            v-model="selectedCategory" 
            placeholder="选择分类" 
            @change="loadDishes"
            class="category-select"
            clearable
          >
            <el-option label="全部" value="" />
            <el-option
              v-for="cat in categories"
              :key="cat"
              :label="cat"
              :value="cat"
            />
          </el-select>
        </div>
        <!-- 骨架屏加载 -->
        <div v-if="dishesLoading" class="dishes-grid skeleton-grid">
          <el-skeleton v-for="n in 8" :key="n" animated class="skeleton-card">
            <template #template>
              <el-skeleton-item variant="rect" style="width: 100%; height: 220px;" />
              <div style="padding: 20px;">
                <el-skeleton-item variant="h3" style="width: 60%; margin-bottom: 12px;" />
                <el-skeleton-item variant="text" style="width: 40%; margin-bottom: 8px;" />
                <el-skeleton-item variant="text" style="width: 100%;" />
              </div>
            </template>
          </el-skeleton>
        </div>
        <div class="dishes-grid" v-show="!dishesLoading">
          <el-card
            v-for="(dish, index) in dishes"
            :key="dish.id"
            class="dish-card modern-card"
            :body-style="{ padding: '0px' }"
            :style="{ animationDelay: `${index * 0.05}s` }"
          >
            <div class="dish-image-wrapper">
              <img 
                :src="dish.image_url || '/placeholder.jpg'" 
                class="dish-image"
                @error="handleImageError"
              />
              <div class="dish-badge" v-if="dish.category">
                {{ dish.category }}
              </div>
            </div>
            <div class="dish-info">
              <h3 class="dish-name">{{ dish.name }}</h3>
              <p class="dish-price">
                <span class="price-symbol">¥</span>
                <span class="price-value">{{ dish.price }}</span>
              </p>
              <div class="dish-rating">
                <el-rate
                  v-model="dish.rating"
                  :max="5"
                  :colors="['#99A9BF', '#F7BA2A', '#FF9900']"
                  @change="handleRatingChange(dish.id, $event)"
                />
              </div>
            </div>
          </el-card>
        </div>
        <div class="pagination-wrapper" v-if="total > pageSize">
          <el-pagination
            v-model:current-page="currentPage"
            :page-size="pageSize"
            :total="total"
            layout="prev, pager, next, total"
            @current-change="loadDishes"
            class="modern-pagination"
          />
        </div>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useUserStore } from '../store/user'
import api from '../api'
import { ElMessage } from 'element-plus'
import { Search, View, Box } from '@element-plus/icons-vue'

const userStore = useUserStore()
const activeTab = ref('recommendations')
const recommendedDishes = ref([])
const dishes = ref([])
const categories = ref([])
const searchQuery = ref('')
const selectedCategory = ref('')
const currentPage = ref(1)
const pageSize = ref(20)
const total = ref(0)
const recommendationsLoading = ref(false)
const dishesLoading = ref(false)

const loadRecommendations = async () => {
  if (!userStore.isLoggedIn) {
    ElMessage.warning('请先登录以查看推荐')
    return
  }
  recommendationsLoading.value = true
  try {
    const response = await api.recommendations.getList()
    recommendedDishes.value = response.dishes || []
  } catch (error) {
    ElMessage.error('加载推荐失败')
  } finally {
    recommendationsLoading.value = false
  }
}

const loadDishes = async () => {
  dishesLoading.value = true
  try {
    const params = {
      page: currentPage.value,
      per_page: pageSize.value
    }
    if (selectedCategory.value) {
      params.category = selectedCategory.value
    }
    if (searchQuery.value) {
      params.search = searchQuery.value
    }
    const response = await api.dishes.getList(params)
    dishes.value = response.dishes || []
    total.value = response.total || dishes.value.length
  } catch (error) {
    ElMessage.error('加载菜品失败')
  } finally {
    dishesLoading.value = false
  }
}

const loadCategories = async () => {
  try {
    const response = await api.dishes.getCategories()
    categories.value = response.categories || []
  } catch (error) {
    console.error('加载分类失败', error)
  }
}

const handleTabChange = (tab) => {
  if (tab === 'recommendations') {
    loadRecommendations()
  } else {
    loadDishes()
  }
}

const handleSearch = () => {
  currentPage.value = 1
  loadDishes()
}

const handleRatingChange = async (dishId, rating) => {
  if (!userStore.isLoggedIn) {
    ElMessage.warning('请先登录')
    return
  }
  try {
    await api.ratings.create({ dish_id: dishId, rating })
    ElMessage.success('评分成功')
  } catch (error) {
    ElMessage.error('评分失败')
  }
}

const viewDish = (dishId) => {
  // 可以跳转到详情页
  console.log('View dish:', dishId)
  ElMessage.info('查看详情功能开发中...')
}

const handleImageError = (event) => {
  // 图片加载失败时使用占位符
  event.target.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjgwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMjgwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iIzY2N2VlYSIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiNmZmYiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj7lm77niYfliqDovb3lpLHotKU8L3RleHQ+PC9zdmc+'
}

onMounted(() => {
  if (userStore.isLoggedIn) {
    loadRecommendations()
  }
  loadCategories()
  loadDishes()
})
</script>

<style scoped>
.home {
  padding: 0;
}

.modern-tabs {
  background: #fff;
  border-radius: var(--radius-lg);
  padding: 20px;
  box-shadow: var(--shadow-md);
}

.search-section {
  display: flex;
  gap: 16px;
  margin-bottom: 24px;
  flex-wrap: wrap;
}

.search-input {
  flex: 1;
  min-width: 250px;
  max-width: 400px;
}

.category-select {
  width: 200px;
}

.dishes-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 24px;
  margin-top: 20px;
}

.dish-card {
  cursor: pointer;
  animation: fadeInUp 0.6s ease-out backwards;
  border: none;
  overflow: hidden;
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(30px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.dish-image-wrapper {
  position: relative;
  width: 100%;
  height: 220px;
  overflow: hidden;
  background: var(--gradient-primary);
}

.dish-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.5s ease;
}

.dish-card:hover .dish-image {
  transform: scale(1.1);
}

.dish-badge {
  position: absolute;
  top: 12px;
  right: 12px;
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(10px);
  padding: 4px 12px;
  border-radius: var(--radius-md);
  font-size: 12px;
  font-weight: 500;
  color: var(--primary-color);
  box-shadow: var(--shadow-sm);
}

.dish-info {
  padding: 20px;
}

.dish-name {
  margin: 0 0 12px 0;
  font-size: 20px;
  font-weight: 600;
  color: #303133;
  line-height: 1.4;
}

.dish-price {
  margin: 12px 0;
  display: flex;
  align-items: baseline;
  gap: 2px;
}

.price-symbol {
  color: #f56c6c;
  font-size: 16px;
  font-weight: 600;
}

.price-value {
  color: #f56c6c;
  font-size: 24px;
  font-weight: 700;
}

.dish-description {
  color: #606266;
  font-size: 14px;
  margin: 12px 0;
  line-height: 1.6;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  min-height: 44px;
}

.dish-rating {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 16px 0;
}

.rating-text {
  color: #909399;
  font-size: 14px;
  font-weight: 500;
}

.dish-actions {
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid #f0f0f0;
}

.view-btn {
  width: 100%;
  border-radius: var(--radius-md);
  font-weight: 500;
}

.empty-state {
  text-align: center;
  padding: 80px 20px;
  color: #909399;
  background: #fff;
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-sm);
}

.empty-icon {
  font-size: 80px;
  margin-bottom: 24px;
  opacity: 0.3;
  color: var(--primary-color);
}

.empty-state p {
  font-size: 16px;
  margin-bottom: 24px;
  color: #606266;
}

.goto-dishes-btn {
  margin-top: 8px;
}

.pagination-wrapper {
  margin-top: 32px;
  display: flex;
  justify-content: center;
}

.modern-pagination {
  background: #fff;
  padding: 16px;
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
}

.skeleton-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 24px;
  margin-top: 20px;
}

.skeleton-card {
  background: #fff;
  border-radius: var(--radius-lg);
  overflow: hidden;
  box-shadow: var(--shadow-md);
}

/* 骨架屏动画 */
:deep(.el-skeleton__item) {
  background: linear-gradient(90deg, #f2f2f2 25%, #e6e6e6 50%, #f2f2f2 75%);
  background-size: 400% 100%;
  animation: skeleton-loading 1.4s ease infinite;
}

@keyframes skeleton-loading {
  0% {
    background-position: 100% 50%;
  }
  100% {
    background-position: -100% 50%;
  }
}

@media (max-width: 768px) {
  .dishes-grid,
  .skeleton-grid {
    grid-template-columns: 1fr;
    gap: 16px;
  }
  
  .search-section {
    flex-direction: column;
  }
  
  .search-input,
  .category-select {
    width: 100%;
    max-width: 100%;
  }
}
</style>
