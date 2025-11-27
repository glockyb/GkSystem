import { createRouter, createWebHistory } from 'vue-router'
import Home from '../views/Home.vue'
import Login from '../views/Login.vue'
import Profile from '../views/Profile.vue'
import Admin from '../views/Admin.vue'
import DishDetail from '../views/DishDetail.vue'
import { useUserStore } from '../store/user'

const routes = [
  {
    path: '/',
    name: 'Home',
    component: Home
  },
  {
    path: '/login',
    name: 'Login',
    component: Login
  },
  {
    path: '/profile',
    name: 'Profile',
    component: Profile,
    meta: { requiresAuth: true }
  },
  {
    path: '/admin',
    name: 'Admin',
    component: Admin,
    meta: { requiresAuth: true, requiresAdmin: true }
  },
  {
    path: '/dish/:id',
    name: 'DishDetail',
    component: DishDetail
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to, from, next) => {
  const userStore = useUserStore()
  
  // 检查是否需要认证
  if (to.meta.requiresAuth && !userStore.isLoggedIn) {
    // 保存目标路由，登录后可以跳转回来
    next({
      path: '/login',
      query: { redirect: to.fullPath }
    })
    return
  }
  
  // 检查是否需要管理员权限
  if (to.meta.requiresAdmin) {
    if (!userStore.isLoggedIn) {
      next({
        path: '/login',
        query: { redirect: to.fullPath }
      })
      return
    }
    
    if (!userStore.isAdminUser) {
      // 尝试从localStorage重新加载管理员状态
      const storedIsAdmin = localStorage.getItem('isAdmin') === 'true'
      const storedRole = localStorage.getItem('role')
      
      if (!storedIsAdmin && storedRole !== 'admin') {
        ElMessage.error('您没有管理员权限')
        next('/')
        return
      }
    }
  }
  
  next()
})

export default router
