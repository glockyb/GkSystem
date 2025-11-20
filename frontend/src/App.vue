<template>
  <el-container class="app-container">
    <el-header class="app-header">
      <div class="header-content">
        <div class="logo-section">
          <el-icon class="logo-icon"><Food /></el-icon>
          <h1>校园食堂菜品推荐系统</h1>
        </div>
        <div class="header-actions">
          <el-button 
            v-if="!userStore.isLoggedIn" 
            type="primary" 
            @click="$router.push('/login')"
            class="login-btn"
          >
            <el-icon><User /></el-icon>
            登录
          </el-button>
          <el-dropdown v-else class="user-dropdown">
            <span class="user-info">
              <el-avatar :size="32" class="user-avatar">
                {{ userStore.username?.charAt(0).toUpperCase() }}
              </el-avatar>
              <span class="username">{{ userStore.username }}</span>
              <el-icon><ArrowDown /></el-icon>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item @click="$router.push('/profile')">
                  <el-icon><User /></el-icon>
                  个人中心
                </el-dropdown-item>
                <el-dropdown-item @click="handleLogout" divided>
                  <el-icon><SwitchButton /></el-icon>
                  退出登录
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </div>
    </el-header>
    <el-main class="app-main">
      <router-view v-slot="{ Component }">
        <transition name="fade" mode="out-in">
          <component :is="Component" />
        </transition>
      </router-view>
    </el-main>
  </el-container>
</template>

<script setup>
import { useUserStore } from './store/user'
import { useRouter } from 'vue-router'
import { User, Food, ArrowDown, SwitchButton } from '@element-plus/icons-vue'

const userStore = useUserStore()
const router = useRouter()

const handleLogout = () => {
  userStore.logout()
  router.push('/login')
}
</script>

<style scoped>
.app-container {
  min-height: 100vh;
  background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
}

.app-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  box-shadow: var(--shadow-lg);
  padding: 0 40px;
  height: 70px !important;
  line-height: 70px;
}

.header-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
  height: 100%;
  max-width: 1400px;
  margin: 0 auto;
}

.logo-section {
  display: flex;
  align-items: center;
  gap: 12px;
}

.logo-icon {
  font-size: 28px;
  color: #fff;
  animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% {
    transform: scale(1);
  }
  50% {
    transform: scale(1.1);
  }
}

.header-content h1 {
  margin: 0;
  color: #fff;
  font-size: 24px;
  font-weight: 600;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 16px;
}

.login-btn {
  border-radius: var(--radius-md);
  padding: 10px 20px;
  font-weight: 500;
}

.user-dropdown {
  cursor: pointer;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 16px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: var(--radius-lg);
  transition: all 0.3s ease;
  color: #fff;
}

.user-info:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: translateY(-2px);
}

.user-avatar {
  background: rgba(255, 255, 255, 0.3);
  color: #fff;
  font-weight: 600;
}

.username {
  font-weight: 500;
  font-size: 14px;
}

.app-main {
  padding: 30px;
  max-width: 1400px;
  margin: 0 auto;
  width: 100%;
}

/* 路由过渡动画 */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease, transform 0.3s ease;
}

.fade-enter-from {
  opacity: 0;
  transform: translateY(10px);
}

.fade-leave-to {
  opacity: 0;
  transform: translateY(-10px);
}

@media (max-width: 768px) {
  .app-header {
    padding: 0 20px;
  }
  
  .header-content h1 {
    font-size: 18px;
  }
  
  .app-main {
    padding: 20px;
  }
  
  .username {
    display: none;
  }
}
</style>
