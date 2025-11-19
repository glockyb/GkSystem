<template>
  <div class="home">
    <el-tabs v-model="activeTab" @tab-change="handleTabChange">
      <el-tab-pane label="推荐菜品" name="recommendations">
        <div class="dishes-grid" v-loading="recommendationsLoading">
          <el-card
            v-for="dish in recommendedDishes"
            :key="dish.id"
            class="dish-card"
            :body-style="{ padding: '0px' }"
          >
            <img :src="dish.image_url || '/placeholder.jpg'" class="dish-image" />
            <div class="dish-info">
              <h3>{{ dish.name }}</h3>
              <p class="dish-category">{{ dish.category }}</p>
              <p class="dish-price">¥{{ dish.price }}</p>
              <p class="dish-description">{{ dish.description }}</p>
              <div class="dish-actions">
                <el-rate
                  v-model="dish.rating"
                  :max="5"
                  @change="handleRatingChange(dish.id, $event)"
                />
                <el-button type="primary" @click="viewDish(dish.id)">查看详情</el-button>
              </div>
            </div>
          </el-card>
        </div>
      </el-tab-pane>
      <el-tab-pane label="全部菜品" name="all">
        <el-input
          v-model="searchQuery"
          placeholder="搜索菜品..."
          class="search-input"
          @input="handleSearch"
        />
        <el-select v-model="selectedCategory" placeholder="选择分类" @change="loadDishes">
          <el-option label="全部" value="" />
          <el-option
            v-for="cat in categories"
            :key="cat"
            :label="cat"
            :value="cat"
          />
        </el-select>
        <div class="dishes-grid" v-loading="dishesLoading">
          <el-card
            v-for="dish in dishes"
            :key="dish.id"
            class="dish-card"
            :body-style="{ padding: '0px' }"
          >
            <img :src="dish.image_url || '/placeholder.jpg'" class="dish-image" />
            <div class="dish-info">
              <h3>{{ dish.name }}</h3>
              <p class="dish-category">{{ dish.category }}</p>
              <p class="dish-price">¥{{ dish.price }}</p>
              <el-rate
                v-model="dish.rating"
                :max="5"
                @change="handleRatingChange(dish.id, $event)"
              />
            </div>
          </el-card>
        </div>
        <el-pagination
          v-model:current-page="currentPage"
          :page-size="pageSize"
          :total="total"
          layout="prev, pager, next"
          @current-change="loadDishes"
        />
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useUserStore } from '../store/user'
import api from '../api'
import { ElMessage } from 'element-plus'

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
  padding: 20px;
}

.search-input {
  margin-bottom: 20px;
  width: 300px;
}

.dishes-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 20px;
  margin-top: 20px;
}

.dish-card {
  cursor: pointer;
  transition: transform 0.3s;
}

.dish-card:hover {
  transform: translateY(-5px);
}

.dish-image {
  width: 100%;
  height: 200px;
  object-fit: cover;
}

.dish-info {
  padding: 15px;
}

.dish-info h3 {
  margin: 0 0 10px 0;
  font-size: 18px;
}

.dish-category {
  color: #909399;
  font-size: 14px;
  margin: 5px 0;
}

.dish-price {
  color: #f56c6c;
  font-size: 20px;
  font-weight: bold;
  margin: 10px 0;
}

.dish-description {
  color: #606266;
  font-size: 14px;
  margin: 10px 0;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.dish-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 15px;
}
</style>
