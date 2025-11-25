import axios from 'axios'

// 获取 API 地址
// 开发环境：使用相对路径（通过 Vite proxy）
// 生产环境：使用环境变量或相对路径（通过 Nginx proxy）
const getApiBaseURL = () => {
  // 如果设置了环境变量，使用环境变量
  if (import.meta.env.VITE_API_URL) {
    return import.meta.env.VITE_API_URL + '/api/v1'
  }
  // 否则使用相对路径（通过 Nginx 代理）
  return '/api/v1'
}

const api = axios.create({
  baseURL: getApiBaseURL(),
  timeout: 10000
})

// 请求拦截器
api.interceptors.request.use(
  config => {
    // 添加 JWT token
    const token = localStorage.getItem('token')
    if (token) {
      // 确保 token 格式正确（去除可能的空格）
      const cleanToken = token.trim()
      config.headers.Authorization = `Bearer ${cleanToken}`
    }
    
    // 添加请求 ID 用于追踪
    config.headers['X-Request-ID'] = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
    
    // 添加内容类型
    if (!config.headers['Content-Type']) {
      config.headers['Content-Type'] = 'application/json'
    }
    
    // 添加 Accept 头
    if (!config.headers['Accept']) {
      config.headers['Accept'] = 'application/json'
    }
    
    // 日志记录（开发环境）
    if (import.meta.env.DEV) {
      console.log(`[API Request] ${config.method?.toUpperCase()} ${config.url}`, {
        headers: config.headers,
        params: config.params,
        data: config.data
      })
    }
    
    return config
  },
  error => {
    console.error('[API Request Error]', error)
    return Promise.reject(error)
  }
)

// 响应拦截器
api.interceptors.response.use(
  response => {
    // 日志记录（开发环境）
    if (import.meta.env.DEV) {
      console.log(`[API Response] ${response.config.method?.toUpperCase()} ${response.config.url}`, {
        status: response.status,
        data: response.data
      })
    }
    return response.data
  },
  error => {
    const response = error.response
    const status = response?.status
    const errorData = response?.data
    
    // 日志记录错误
    console.error('[API Error]', {
      url: error.config?.url,
      method: error.config?.method,
      status: status,
      error: errorData,
      headers: error.config?.headers
    })
    
    // 处理 401 未授权（token 过期或无效）
    if (status === 401) {
      console.warn('[API] Token expired or invalid, clearing storage')
      localStorage.removeItem('token')
      localStorage.removeItem('userId')
      localStorage.removeItem('username')
      // 如果不在登录页，跳转到登录页
      if (window.location.pathname !== '/login') {
        window.location.href = '/login'
      }
    }
    
    // 处理 422 未处理的实体（通常是 JWT token 格式错误）
    if (status === 422) {
      const errorMsg = errorData?.error || 'Token validation failed'
      console.error('[API] 422 Error:', errorMsg)
      
      // 如果错误信息包含 token 相关，清除 token
      if (errorMsg.toLowerCase().includes('token') || 
          errorMsg.toLowerCase().includes('jwt') ||
          errorMsg.toLowerCase().includes('invalid')) {
        console.warn('[API] Invalid token detected, clearing storage')
        localStorage.removeItem('token')
        localStorage.removeItem('userId')
        localStorage.removeItem('username')
        
        // 如果不在登录页，跳转到登录页
        if (window.location.pathname !== '/login') {
          window.location.href = '/login'
        }
      }
    }
    
    return Promise.reject(error)
  }
)

api.setToken = (token) => {
  if (token) {
    api.defaults.headers.common['Authorization'] = `Bearer ${token}`
  } else {
    delete api.defaults.headers.common['Authorization']
  }
}

// API方法
export default {
  // 认证
  auth: {
    register: (data) => api.post('/register', data),
    login: (data) => api.post('/login', data),
    getProfile: () => api.get('/profile')
  },
  // 菜品
  dishes: {
    getList: (params) => api.get('/dishes', { params }),
    getDetail: (id) => api.get(`/dishes/${id}`),
    getCategories: () => api.get('/dishes/categories')
  },
  // 推荐
  recommendations: {
    getList: (params) => api.get('/recommendations', { params })
  },
  // 评分
  ratings: {
    create: (data) => api.post('/ratings', data),
    get: (dishId) => api.get(`/ratings/${dishId}`),
    getHistory: (params) => api.get('/history', { params })
  },
  setToken: api.setToken
}
