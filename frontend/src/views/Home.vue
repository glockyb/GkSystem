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
            :data-dish-id="dish.id"
            :body-style="{ padding: '0px' }"
            :style="{ animationDelay: `${index * 0.1}s` }"
          >
            <div class="dish-image-wrapper">
              <div class="image-container">
                <img 
                  :src="getImageUrl(dish.image_url)" 
                  class="dish-image"
                  @error="handleImageError"
                  @load="handleImageLoad"
                  loading="lazy"
                  :class="{ 'image-error': imageErrors.has(dish.id) }"
                />
                <div v-if="imageErrors.has(dish.id)" class="image-placeholder-overlay">
                  <el-icon class="placeholder-icon"><Picture /></el-icon>
                  <span class="placeholder-text">图片加载失败</span>
                </div>
                <div v-if="imageLoading.has(dish.id)" class="image-loading-overlay">
                  <el-icon class="loading-icon is-loading"><Loading /></el-icon>
                </div>
              </div>
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
            :data-dish-id="dish.id"
            :body-style="{ padding: '0px' }"
            :style="{ animationDelay: `${index * 0.05}s` }"
          >
            <div class="dish-image-wrapper">
              <div class="image-container">
                <img 
                  :src="getImageUrl(dish.image_url)" 
                  class="dish-image"
                  @error="handleImageError"
                  @load="handleImageLoad"
                  loading="lazy"
                  :class="{ 'image-error': imageErrors.has(dish.id) }"
                />
                <div v-if="imageErrors.has(dish.id)" class="image-placeholder-overlay">
                  <el-icon class="placeholder-icon"><Picture /></el-icon>
                  <span class="placeholder-text">图片加载失败</span>
                </div>
                <div v-if="imageLoading.has(dish.id)" class="image-loading-overlay">
                  <el-icon class="loading-icon is-loading"><Loading /></el-icon>
                </div>
              </div>
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
import { Search, View, Box, Picture, Loading } from '@element-plus/icons-vue'

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
const imageErrors = ref(new Set())
const imageLoading = ref(new Set())

const loadRecommendations = async () => {
  if (!userStore.isLoggedIn) {
    ElMessage.warning('请先登录以查看推荐')
    return
  }
  recommendationsLoading.value = true
  try {
    const response = await api.recommendations.getList()
    recommendedDishes.value = response.dishes || []
    
    // 重置图片加载状态
    imageErrors.value.clear()
    imageLoading.value.clear()
    // 标记所有图片为加载中
    recommendedDishes.value.forEach(dish => {
      if (dish.image_url) {
        imageLoading.value.add(dish.id)
      }
    })
    
    // 加载每个推荐菜品的用户评分
    if (recommendedDishes.value.length > 0) {
      for (const dish of recommendedDishes.value) {
        try {
          const ratingResponse = await api.ratings.get(dish.id)
          if (ratingResponse.rating) {
            dish.rating = ratingResponse.rating
          } else {
            dish.rating = 0
          }
        } catch (error) {
          dish.rating = 0
        }
      }
    }
  } catch (error) {
    console.error('加载推荐失败', error)
    const errorMsg = error.response?.data?.error || error.message || '加载推荐失败'
    ElMessage.error(`加载推荐失败: ${errorMsg}`)
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
    let dishesList = response.dishes || []
    
    // 去重处理（按名称去重，避免重复显示）
    const seenNames = new Set()
    const seenIds = new Set()
    dishesList = dishesList.filter(dish => {
      const dishName = (dish.name || '').trim()
      const dishId = dish.id
      
      // 如果名称为空，按 ID 去重
      if (!dishName) {
        if (seenIds.has(dishId)) {
          return false
        }
        seenIds.add(dishId)
        return true
      }
      
      // 按名称去重
      if (seenNames.has(dishName)) {
        return false
      }
      seenNames.add(dishName)
      return true
    })
    
    dishes.value = dishesList
    total.value = response.total || dishes.value.length
    
    // 重置图片加载状态
    imageErrors.value.clear()
    imageLoading.value.clear()
    // 标记所有图片为加载中
    dishesList.forEach(dish => {
      if (dish.image_url) {
        imageLoading.value.add(dish.id)
      }
    })
    
    // 如果用户已登录，加载每个菜品的用户评分
    if (userStore.isLoggedIn && dishes.value.length > 0) {
      await loadUserRatings()
    }
  } catch (error) {
    console.error('加载菜品失败', error)
    ElMessage.error('加载菜品失败')
  } finally {
    dishesLoading.value = false
  }
}

const loadUserRatings = async () => {
  // 为每个菜品加载用户评分
  for (const dish of dishes.value) {
    try {
      const ratingResponse = await api.ratings.get(dish.id)
      if (ratingResponse.rating) {
        dish.rating = ratingResponse.rating
      } else {
        dish.rating = 0
      }
    } catch (error) {
      // 如果获取评分失败，设置为0
      dish.rating = 0
    }
  }
}

const loadCategories = async () => {
  try {
    const response = await api.dishes.getCategories()
    if (response && response.categories) {
      categories.value = response.categories
    } else {
      categories.value = []
      console.warn('加载分类失败: 响应格式不正确', response)
    }
  } catch (error) {
    console.error('加载分类失败', error)
    // 设置空数组，避免后续错误
    categories.value = []
    // 只在开发环境显示错误消息
    if (import.meta.env.DEV) {
      ElMessage.warning('加载分类失败，请刷新页面重试')
    }
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
  
  if (!rating || rating < 1 || rating > 5) {
    ElMessage.warning('请选择1-5星的评分')
    return
  }
  
  try {
    const response = await api.ratings.create({ dish_id: dishId, rating })
    ElMessage.success('评分成功')
    
    // 更新本地数据
    const dish = dishes.value.find(d => d.id === dishId)
    if (dish) {
      dish.rating = rating
    }
    
    // 更新推荐列表中的评分
    const recDish = recommendedDishes.value.find(d => d.id === dishId)
    if (recDish) {
      recDish.rating = rating
    }
  } catch (error) {
    console.error('评分失败', error)
    const errorMsg = error.response?.data?.error || error.message || '评分失败'
    ElMessage.error(`评分失败: ${errorMsg}`)
    
    // 恢复原来的评分
    try {
      const ratingResponse = await api.ratings.get(dishId)
      const dish = dishes.value.find(d => d.id === dishId)
      if (dish) {
        dish.rating = ratingResponse.rating || 0
      }
    } catch (e) {
      // 如果获取失败，设置为0
      const dish = dishes.value.find(d => d.id === dishId)
      if (dish) {
        dish.rating = 0
      }
    }
  }
}

const viewDish = (dishId) => {
  // 可以跳转到详情页
  console.log('View dish:', dishId)
  ElMessage.info('查看详情功能开发中...')
}

// 处理图片URL，确保路径正确
const getImageUrl = (imageUrl) => {
  if (!imageUrl) {
    // 返回占位符
    return 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZGVmcz48bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPjxzdG9wIG9mZnNldD0iMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiM2NjdlZWE7c3RvcC1vcGFjaXR5OjEiIC8+PHN0b3Agb2Zmc2V0PSIxMDAlIiBzdHlsZT0ic3RvcC1jb2xvcjojNzY0YmEyO3N0b3Atb3BhY2l0eToxIiAvPjwvbGluZWFyR3JhZGllbnQ+PC9kZWZzPjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSJ1cmwoI2dyYWQpIi8+PGNpcmNsZSBjeD0iMjAwIiBjeT0iMTIwIiByPSI0MCIgZmlsbD0icmdiYSgyNTUsMjU1LDI1NSwwLjMpIi8+PHBhdGggZD0iTSAxODAgMTIwIEwgMjAwIDEwMCBMIDIyMCAxMjAgTCAyMDAgMTQwIFoiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC41KSIvPjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTYiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC44KSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+56eR5oqA5Zu+54mHPC90ZXh0Pjwvc3ZnPg=='
  }
  // 如果已经是完整URL，直接返回
  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
    return imageUrl
  }
  // 如果以 / 开头，直接使用（相对路径，通过 Nginx 代理）
  if (imageUrl.startsWith('/')) {
    return imageUrl
  }
  // 否则添加 /images/ 前缀
  return `/images/${imageUrl}`
}

const handleImageLoad = (event) => {
  // 图片加载成功，移除加载状态和错误状态
  const img = event.target
  const dishCard = img.closest('.dish-card')
  if (dishCard) {
    const dishId = dishCard.dataset?.dishId
    if (dishId) {
      imageLoading.value.delete(parseInt(dishId))
      imageErrors.value.delete(parseInt(dishId))
    }
  }
}

const handleImageError = (event) => {
  const img = event.target
  const dishCard = img.closest('.dish-card')
  
  if (dishCard) {
    const dishId = dishCard.dataset?.dishId
    if (dishId) {
      // 标记为错误
      imageErrors.value.add(parseInt(dishId))
      imageLoading.value.delete(parseInt(dishId))
      // 隐藏图片，显示占位符
      img.style.display = 'none'
    }
  }
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
  padding: 20px;
  background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.search-input {
  flex: 1;
  min-width: 250px;
  max-width: 400px;
}

.search-input :deep(.el-input__wrapper) {
  border-radius: 10px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  transition: all 0.3s ease;
}

.search-input :deep(.el-input__wrapper:hover) {
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
}

.category-select {
  width: 200px;
}

.category-select :deep(.el-input__wrapper) {
  border-radius: 10px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
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
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  background: #fff;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

.dish-card:hover {
  transform: translateY(-8px);
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.15);
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
  height: 240px;
  overflow: hidden;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 12px 12px 0 0;
}

.image-container {
  position: relative;
  width: 100%;
  height: 100%;
  overflow: hidden;
}

.dish-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.6s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.3s ease;
  background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
  display: block;
}

.dish-image.image-error {
  opacity: 0;
  display: none;
}

.dish-card:hover .dish-image:not(.image-error) {
  transform: scale(1.08);
}

.image-placeholder-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
  color: #909399;
  z-index: 1;
}

.placeholder-icon {
  font-size: 48px;
  margin-bottom: 12px;
  opacity: 0.6;
  color: #c0c4cc;
}

.placeholder-text {
  font-size: 14px;
  color: #909399;
  font-weight: 500;
}

.image-loading-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.8);
  backdrop-filter: blur(4px);
  z-index: 2;
}

.loading-icon {
  font-size: 32px;
  color: #667eea;
  animation: rotate 1s linear infinite;
}

@keyframes rotate {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.dish-badge {
  position: absolute;
  top: 12px;
  right: 12px;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(12px);
  padding: 6px 14px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;
  color: #667eea;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.8);
  transition: all 0.3s ease;
}

.dish-card:hover .dish-badge {
  background: rgba(255, 255, 255, 1);
  transform: scale(1.05);
}

.dish-info {
  padding: 24px;
  background: #fff;
}

.dish-name {
  margin: 0 0 12px 0;
  font-size: 20px;
  font-weight: 700;
  color: #1a1a1a;
  line-height: 1.4;
  transition: color 0.3s ease;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-overflow: ellipsis;
  min-height: 56px;
}

.dish-card:hover .dish-name {
  color: #667eea;
}

.dish-price {
  margin: 12px 0;
  display: flex;
  align-items: baseline;
  gap: 2px;
}

.price-symbol {
  color: #ff6b6b;
  font-size: 18px;
  font-weight: 700;
}

.price-value {
  color: #ff6b6b;
  font-size: 28px;
  font-weight: 800;
  background: linear-gradient(135deg, #ff6b6b 0%, #ee5a6f 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
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
  background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
  border-radius: 16px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
  margin: 20px 0;
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
