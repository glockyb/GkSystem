import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '../api'

export const useUserStore = defineStore('user', () => {
  const token = ref(localStorage.getItem('token') || '')
  const userId = ref(localStorage.getItem('userId') || '')
  const username = ref(localStorage.getItem('username') || '')
  const role = ref(localStorage.getItem('role') || 'user')
  const isAdmin = ref(localStorage.getItem('isAdmin') === 'true')

  const isLoggedIn = computed(() => !!token.value)
  const isAdminUser = computed(() => isAdmin.value || role.value === 'admin')

  function login(userData) {
    token.value = userData.access_token
    userId.value = userData.user_id
    username.value = userData.username || ''
    role.value = userData.role || 'user'
    isAdmin.value = userData.is_admin === true || userData.is_admin === 1 || userData.role === 'admin'
    
    localStorage.setItem('token', token.value)
    localStorage.setItem('userId', userId.value)
    if (userData.username) {
      localStorage.setItem('username', userData.username)
    }
    localStorage.setItem('role', role.value)
    localStorage.setItem('isAdmin', isAdmin.value.toString())
    
    api.setToken(token.value)
  }

  function logout() {
    token.value = ''
    userId.value = ''
    username.value = ''
    role.value = 'user'
    isAdmin.value = false
    localStorage.removeItem('token')
    localStorage.removeItem('userId')
    localStorage.removeItem('username')
    localStorage.removeItem('role')
    localStorage.removeItem('isAdmin')
    api.setToken('')
  }

  return {
    token,
    userId,
    username,
    role,
    isAdmin,
    isLoggedIn,
    isAdminUser,
    login,
    logout
  }
})
