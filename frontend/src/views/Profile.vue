<template>
  <div class="profile">
    <el-card>
      <template #header>
        <h2>个人中心</h2>
      </template>
      <el-tabs v-model="activeTab">
        <el-tab-pane label="个人信息" name="info">
          <el-descriptions :column="1" border>
            <el-descriptions-item label="用户名">{{ userInfo.username }}</el-descriptions-item>
            <el-descriptions-item label="邮箱">{{ userInfo.email || '未设置' }}</el-descriptions-item>
            <el-descriptions-item label="注册时间">{{ userInfo.created_at }}</el-descriptions-item>
          </el-descriptions>
        </el-tab-pane>
        <el-tab-pane label="消费历史" name="history">
          <div v-loading="historyLoading">
            <el-table :data="history" style="width: 100%">
              <el-table-column prop="dish_name" label="菜品名称" />
              <el-table-column prop="category" label="分类" />
              <el-table-column prop="price" label="价格" />
              <el-table-column prop="rating" label="评分">
                <template #default="{ row }">
                  <el-rate v-model="row.rating" disabled />
                </template>
              </el-table-column>
              <el-table-column prop="consumption_time" label="消费时间" />
            </el-table>
            <el-pagination
              v-model:current-page="historyPage"
              :page-size="historyPageSize"
              :total="historyTotal"
              layout="prev, pager, next"
              @current-change="loadHistory"
            />
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
  padding: 20px;
}
</style>
