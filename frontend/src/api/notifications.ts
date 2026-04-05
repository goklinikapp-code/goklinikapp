import { apiClient } from '@/lib/axios'
import type { AppNotificationItem } from '@/types'

interface NotificationListResponse {
  count?: number
  next?: string | null
  previous?: string | null
  results?: AppNotificationItem[]
}

export interface NotificationListParams {
  page?: number
  pageSize?: number
}

export interface NotificationPage {
  count: number
  next: string | null
  previous: string | null
  results: AppNotificationItem[]
}

export async function getNotifications(params: NotificationListParams = {}): Promise<NotificationPage> {
  const { data } = await apiClient.get<NotificationListResponse | AppNotificationItem[]>('/notifications/', {
    params: {
      page: params.page || 1,
      page_size: params.pageSize || 8,
    },
  })

  if (Array.isArray(data)) {
    return {
      count: data.length,
      next: null,
      previous: null,
      results: data,
    }
  }

  return {
    count: Number(data.count || 0),
    next: data.next || null,
    previous: data.previous || null,
    results: data.results || [],
  }
}

export async function getUnreadNotificationsCount(): Promise<number> {
  const { data } = await apiClient.get<{ unread_count?: number }>('/notifications/unread-count/')
  return Number(data.unread_count || 0)
}

export async function markNotificationAsRead(id: string): Promise<AppNotificationItem> {
  const { data } = await apiClient.put<AppNotificationItem>(`/notifications/${id}/read/`)
  return data
}

export async function markAllNotificationsAsRead(): Promise<number> {
  const { data } = await apiClient.put<{ updated_count?: number }>('/notifications/read-all/')
  return Number(data.updated_count || 0)
}
