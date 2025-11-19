import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '../api'

export const useUserStore = defineStore('user', () => {
  const token = ref(localStorage.getItem('token') || '')
  const userId = ref(localStorage.getItem('userId') || '')
  const username = ref(localStorage.getItem('username') || '')

  const isLoggedIn = computed(() => !!token.value)

  function login(userData) {
    token.value = userData.access_token
    userId.value = userData.user_id
    username.value = userData.username || ''
    localStorage.setItem('token', token.value)
    localStorage.setItem('userId', userId.value)
    if (userData.username) {
      localStorage.setItem('username', userData.username)
    }
    api.setToken(token.value)
  }

  function logout() {
    token.value = ''
    userId.value = ''
    username.value = ''
    localStorage.removeItem('token')
    localStorage.removeItem('userId')
    localStorage.removeItem('username')
    api.setToken('')
  }

  return {
    token,
    userId,
    username,
    isLoggedIn,
    login,
    logout
  }
})
