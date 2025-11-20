<template>
  <div class="profile fade-in">
    <el-card class="profile-card modern-card">
      <template #header>
        <div class="profile-header">
          <el-avatar :size="80" class="profile-avatar">
            {{ userInfo.username?.charAt(0).toUpperCase() }}
          </el-avatar>
          <div class="profile-title">
            <h2>个人中心</h2>
            <p class="welcome-text">欢迎回来，{{ userInfo.username || '用户' }}</p>
          </div>
        </div>
      </template>
      <el-tabs v-model="activeTab" class="profile-tabs">
        <el-tab-pane label="个人信息" name="info">
          <div class="info-section">
            <el-descriptions :column="1" border class="modern-descriptions">
              <el-descriptions-item label="用户名">
                <el-icon><User /></el-icon>
                {{ userInfo.username }}
              </el-descriptions-item>
              <el-descriptions-item label="邮箱">
                <el-icon><Message /></el-icon>
                {{ userInfo.email || '未设置' }}
              </el-descriptions-item>
              <el-descriptions-item label="注册时间">
                <el-icon><Clock /></el-icon>
                {{ userInfo.created_at || '未知' }}
              </el-descriptions-item>
            </el-descriptions>
          </div>
        </el-tab-pane>
        <el-tab-pane label="消费历史" name="history">
          <div v-loading="historyLoading" class="history-section">
            <div v-if="history.length === 0 && !historyLoading" class="empty-history">
              <el-icon class="empty-icon"><DocumentDelete /></el-icon>
              <p>暂无消费历史记录</p>
            </div>
            <el-table 
              :data="history" 
              style="width: 100%"
              class="modern-table"
              v-else
            >
              <el-table-column prop="dish_name" label="菜品名称" width="200">
                <template #default="{ row }">
                  <div class="dish-name-cell">
                    <el-icon><Food /></el-icon>
                    {{ row.dish_name }}
                  </div>
                </template>
              </el-table-column>
              <el-table-column prop="category" label="分类" width="120" />
              <el-table-column prop="price" label="价格" width="100">
                <template #default="{ row }">
                  <span class="price-cell">¥{{ row.price }}</span>
                </template>
              </el-table-column>
              <el-table-column prop="rating" label="评分" width="180">
                <template #default="{ row }">
                  <el-rate 
                    v-model="row.rating" 
                    disabled 
                    :colors="['#99A9BF', '#F7BA2A', '#FF9900']"
                  />
                  <span class="rating-value">{{ row.rating }}分</span>
                </template>
              </el-table-column>
              <el-table-column prop="consumption_time" label="消费时间" />
            </el-table>
            <div class="pagination-wrapper" v-if="historyTotal > historyPageSize">
              <el-pagination
                v-model:current-page="historyPage"
                :page-size="historyPageSize"
                :total="historyTotal"
                layout="prev, pager, next, total"
                @current-change="loadHistory"
                class="modern-pagination"
              />
            </div>
          </div>
        </el-tab-pane>
      </el-tabs>
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useUserStore } from '../store/user'
import api from '../api'
import { ElMessage } from 'element-plus'
import { User, Message, Clock, Food, DocumentDelete } from '@element-plus/icons-vue'

const userStore = useUserStore()
const activeTab = ref('info')
const userInfo = ref({})
const history = ref([])
const historyLoading = ref(false)
const historyPage = ref(1)
const historyPageSize = ref(20)
const historyTotal = ref(0)

const loadUserInfo = async () => {
  try {
    const response = await api.auth.getProfile()
    userInfo.value = response
  } catch (error) {
    ElMessage.error('加载用户信息失败')
  }
}

const loadHistory = async () => {
  historyLoading.value = true
  try {
    const response = await api.ratings.getHistory({
      page: historyPage.value,
      per_page: historyPageSize.value
    })
    history.value = response.history || []
    historyTotal.value = response.total || history.value.length
  } catch (error) {
    ElMessage.error('加载历史记录失败')
  } finally {
    historyLoading.value = false
  }
}

onMounted(() => {
  loadUserInfo()
  loadHistory()
})
</script>

<style scoped>
.profile {
  padding: 0;
}

.profile-card {
  border: none;
}

.profile-header {
  display: flex;
  align-items: center;
  gap: 24px;
  padding: 10px 0;
}

.profile-avatar {
  background: var(--gradient-primary);
  color: #fff;
  font-size: 32px;
  font-weight: 600;
  flex-shrink: 0;
  box-shadow: var(--shadow-md);
}

.profile-title h2 {
  margin: 0 0 8px 0;
  font-size: 24px;
  font-weight: 600;
  color: #303133;
}

.welcome-text {
  margin: 0;
  color: #909399;
  font-size: 14px;
}

.profile-tabs {
  margin-top: 10px;
}

.info-section {
  padding: 20px 0;
}

.modern-descriptions {
  border-radius: var(--radius-md);
  overflow: hidden;
}

:deep(.el-descriptions__label) {
  font-weight: 500;
  color: #606266;
}

:deep(.el-descriptions__content) {
  color: #303133;
  display: flex;
  align-items: center;
  gap: 8px;
}

.history-section {
  padding: 20px 0;
}

.empty-history {
  text-align: center;
  padding: 60px 20px;
  color: #909399;
}

.empty-icon {
  font-size: 64px;
  margin-bottom: 16px;
  opacity: 0.5;
}

.modern-table {
  border-radius: var(--radius-md);
  overflow: hidden;
}

.dish-name-cell {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 500;
}

.price-cell {
  color: #f56c6c;
  font-weight: 600;
  font-size: 16px;
}

.rating-value {
  margin-left: 12px;
  color: #909399;
  font-size: 14px;
}

.pagination-wrapper {
  margin-top: 24px;
  display: flex;
  justify-content: center;
}

.modern-pagination {
  background: #fff;
  padding: 16px;
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
}

@media (max-width: 768px) {
  .profile-header {
    flex-direction: column;
    text-align: center;
  }
  
  .modern-table {
    font-size: 12px;
  }
}
</style>
