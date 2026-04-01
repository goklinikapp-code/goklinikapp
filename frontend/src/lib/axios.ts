import axios from 'axios'

import { useAuthStore } from '@/stores/authStore'
import { normalizeMediaUrlsDeep } from '@/utils/mediaUrl'

const API_URL = import.meta.env.VITE_API_URL || 'https://api.goklinik.com/api'

export const apiClient = axios.create({
  baseURL: API_URL,
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
})

apiClient.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token

  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }

  return config
})

apiClient.interceptors.response.use(
  (response) => {
    response.data = normalizeMediaUrlsDeep(response.data)
    return response
  },
  (error) => {
    if (error?.response?.status === 401) {
      useAuthStore.getState().logout()
      if (window.location.pathname !== '/login') {
        window.location.href = '/login'
      }
    }

    return Promise.reject(error)
  },
)
