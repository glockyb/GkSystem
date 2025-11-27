<template>
  <div class="dish-detail fade-in">
    <el-card class="detail-card" v-loading="loading">
      <!-- 返回按钮 -->
      <div class="back-button">
        <el-button @click="goBack" :icon="ArrowLeft" circle />
      </div>

      <div v-if="!loading && dish" class="detail-content">
        <!-- 图片和基本信息 -->
        <div class="detail-header">
          <div class="dish-image-section">
            <div class="image-wrapper">
              <img 
                :src="getImageUrl(dish.image_url)" 
                :alt="dish.name"
                class="detail-image"
                @error="handleImageError"
              />
              <div v-if="imageError" class="image-placeholder">
                <el-icon class="placeholder-icon"><Picture /></el-icon>
                <span>图片加载失败</span>
              </div>
            </div>
          </div>
          
          <div class="dish-info-section">
            <div class="dish-badge" v-if="dish.category">
              {{ dish.category }}
            </div>
            <h1 class="dish-title">{{ dish.name }}</h1>
            
            <div class="price-section">
              <span class="price-label">价格：</span>
              <span class="price-value">
                <span class="price-symbol">¥</span>
                <span class="price-number">{{ dish.price }}</span>
              </span>
            </div>

            <div class="rating-section">
              <div class="rating-label">平均评分：</div>
              <el-rate
                :model-value="dish.avg_rating || 0"
                disabled
                :max="5"
                :colors="['#99A9BF', '#F7BA2A', '#FF9900']"
                show-score
                :score-template="`${dish.avg_rating?.toFixed(1) || '0.0'}分`"
              />
            </div>

            <!-- 用户评分（如果已登录） -->
            <div v-if="userStore.isLoggedIn" class="user-rating-section">
              <div class="rating-label">我的评分：</div>
              <el-rate
                v-model="userRating"
                :max="5"
                :colors="['#99A9BF', '#F7BA2A', '#FF9900']"
                @change="handleRatingChange"
              />
              <span v-if="userRating" class="rating-text">{{ userRating }}分</span>
            </div>
          </div>
        </div>

        <!-- 描述 -->
        <div v-if="dish.description" class="description-section">
          <h2 class="section-title">菜品介绍</h2>
          <p class="description-text">{{ dish.description }}</p>
        </div>

        <!-- 营养信息（如果有） -->
        <div v-if="dish.nutrition_info" class="nutrition-section">
          <h2 class="section-title">营养信息</h2>
          <div class="nutrition-content">
            <el-descriptions :column="2" border>
              <el-descriptions-item 
                v-for="(value, key) in nutritionInfo" 
                :key="key"
                :label="key"
              >
                {{ value }}
              </el-descriptions-item>
            </el-descriptions>
          </div>
        </div>
      </div>

      <!-- 加载失败 -->
      <div v-if="!loading && !dish" class="error-state">
        <el-icon class="error-icon"><Warning /></el-icon>
        <p>菜品不存在或加载失败</p>
        <el-button @click="goBack" type="primary">返回</el-button>
      </div>
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useUserStore } from '../store/user'
import api from '../api'
import { ElMessage } from 'element-plus'
import { ArrowLeft, Picture, Warning } from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()

const dish = ref(null)
const loading = ref(true)
const imageError = ref(false)
const userRating = ref(0)

// 解析营养信息
const nutritionInfo = computed(() => {
  if (!dish.value?.nutrition_info) return {}
  
  try {
    if (typeof dish.value.nutrition_info === 'string') {
      return JSON.parse(dish.value.nutrition_info)
    }
    return dish.value.nutrition_info
  } catch (e) {
    return {}
  }
})

// 加载菜品详情
const loadDishDetail = async () => {
  const dishId = route.params.id
  if (!dishId) {
    ElMessage.error('菜品ID无效')
    router.push('/')
    return
  }

  loading.value = true
  try {
    const response = await api.dishes.getDetail(dishId)
    dish.value = response
    
    // 如果用户已登录，加载用户评分
    if (userStore.isLoggedIn) {
      try {
        const ratingResponse = await api.ratings.get(dishId)
        if (ratingResponse && ratingResponse.rating) {
          userRating.value = ratingResponse.rating
        }
      } catch (error) {
        // 没有评分是正常的，不显示错误
        userRating.value = 0
      }
    }
  } catch (error) {
    console.error('加载菜品详情失败', error)
    ElMessage.error('加载菜品详情失败')
    dish.value = null
  } finally {
    loading.value = false
  }
}

// 处理图片URL
const getImageUrl = (imageUrl) => {
  if (!imageUrl || imageUrl.trim() === '') {
    return 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZGVmcz48bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPjxzdG9wIG9mZnNldD0iMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiM2NjdlZWE7c3RvcC1vcGFjaXR5OjEiIC8+PHN0b3Agb2Zmc2V0PSIxMDAlIiBzdHlsZT0ic3RvcC1jb2xvcjojNzY0YmEyO3N0b3Atb3BhY2l0eToxIiAvPjwvbGluZWFyR3JhZGllbnQ+PC9kZWZzPjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSJ1cmwoI2dyYWQpIi8+PGNpcmNsZSBjeD0iMjAwIiBjeT0iMTIwIiByPSI0MCIgZmlsbD0icmdiYSgyNTUsMjU1LDI1NSwwLjMpIi8+PHBhdGggZD0iTSAxODAgMTIwIEwgMjAwIDEwMCBMIDIyMCAxMjAgTCAyMDAgMTQwIFoiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC41KSIvPjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTYiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC44KSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+56eR5oqA5Zu+54mHPC90ZXh0Pjwvc3ZnPg=='
  }
  
  imageUrl = imageUrl.trim()
  
  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
    return imageUrl
  }
  
  if (imageUrl.startsWith('/')) {
    if (imageUrl.startsWith('/images/')) {
      return imageUrl
    }
    const filename = imageUrl.split('/').pop()
    if (filename) {
      return `/images/${filename}`
    }
    return imageUrl
  }
  
  return `/images/${imageUrl}`
}

// 处理图片加载错误
const handleImageError = () => {
  imageError.value = true
}

// 处理评分变化
const handleRatingChange = async (rating) => {
  if (!userStore.isLoggedIn) {
    ElMessage.warning('请先登录')
    userRating.value = 0
    return
  }
  
  if (!rating || rating < 1 || rating > 5) {
    return
  }
  
  try {
    await api.ratings.create({ dish_id: dish.value.id, rating })
    ElMessage.success('评分成功')
    userRating.value = rating
    
    // 更新平均评分（简单处理，重新加载详情）
    await loadDishDetail()
  } catch (error) {
    console.error('评分失败', error)
    ElMessage.error(error.response?.data?.error || '评分失败')
    // 恢复原来的评分
    try {
      const ratingResponse = await api.ratings.get(dish.value.id)
      userRating.value = ratingResponse?.rating || 0
    } catch (e) {
      userRating.value = 0
    }
  }
}

// 返回
const goBack = () => {
  router.back()
}

onMounted(() => {
  loadDishDetail()
})
</script>

<style scoped>
.dish-detail {
  padding: 0;
}

.detail-card {
  border: none;
  box-shadow: var(--shadow-lg);
  border-radius: var(--radius-lg);
  overflow: hidden;
  position: relative;
}

.back-button {
  position: absolute;
  top: 20px;
  left: 20px;
  z-index: 10;
}

.back-button .el-button {
  background: rgba(255, 255, 255, 0.9);
  border: none;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
}

.detail-content {
  padding: 20px;
}

.detail-header {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 40px;
  margin-bottom: 40px;
}

.dish-image-section {
  position: relative;
}

.image-wrapper {
  position: relative;
  width: 100%;
  height: 400px;
  border-radius: var(--radius-lg);
  overflow: hidden;
  background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
}

.detail-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.image-placeholder {
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
}

.placeholder-icon {
  font-size: 64px;
  margin-bottom: 16px;
  opacity: 0.5;
}

.dish-info-section {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.dish-badge {
  display: inline-block;
  background: rgba(102, 126, 234, 0.1);
  color: #667eea;
  padding: 8px 16px;
  border-radius: 20px;
  font-size: 14px;
  font-weight: 600;
  width: fit-content;
}

.dish-title {
  margin: 0;
  font-size: 36px;
  font-weight: 700;
  color: #1a1a1a;
  line-height: 1.3;
}

.price-section {
  display: flex;
  align-items: baseline;
  gap: 12px;
}

.price-label {
  font-size: 18px;
  color: #606266;
  font-weight: 500;
}

.price-value {
  display: flex;
  align-items: baseline;
  gap: 4px;
}

.price-symbol {
  color: #ff6b6b;
  font-size: 24px;
  font-weight: 700;
}

.price-number {
  color: #ff6b6b;
  font-size: 36px;
  font-weight: 800;
  background: linear-gradient(135deg, #ff6b6b 0%, #ee5a6f 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.rating-section,
.user-rating-section {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
  background: #f5f7fa;
  border-radius: var(--radius-md);
}

.rating-label {
  font-size: 16px;
  color: #606266;
  font-weight: 500;
  min-width: 80px;
}

.rating-text {
  color: #909399;
  font-size: 14px;
  font-weight: 500;
}

.description-section,
.nutrition-section {
  margin-top: 40px;
  padding-top: 40px;
  border-top: 1px solid #e4e7ed;
}

.section-title {
  margin: 0 0 20px 0;
  font-size: 24px;
  font-weight: 700;
  color: #1a1a1a;
}

.description-text {
  font-size: 16px;
  line-height: 1.8;
  color: #606266;
  margin: 0;
}

.nutrition-content {
  margin-top: 20px;
}

.error-state {
  text-align: center;
  padding: 80px 20px;
  color: #909399;
}

.error-icon {
  font-size: 80px;
  margin-bottom: 24px;
  opacity: 0.3;
  color: var(--primary-color);
}

.error-state p {
  font-size: 16px;
  margin-bottom: 24px;
}

@media (max-width: 768px) {
  .detail-header {
    grid-template-columns: 1fr;
    gap: 24px;
  }

  .image-wrapper {
    height: 300px;
  }

  .dish-title {
    font-size: 28px;
  }

  .price-number {
    font-size: 28px;
  }

  .rating-section,
  .user-rating-section {
    flex-direction: column;
    align-items: flex-start;
    gap: 12px;
  }
}
</style>

