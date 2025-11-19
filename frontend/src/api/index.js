import axios from 'axios'

const api = axios.create({
  baseURL: '/api/v1',
  timeout: 10000
})

// 请求拦截器
api.interceptors.request.use(
  config => {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  error => {
    return Promise.reject(error)
  }
)

// 响应拦截器
api.interceptors.response.use(
  response => response.data,
  error => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token')
      window.location.href = '/login'
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
