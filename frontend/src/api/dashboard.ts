import { apiClient } from '@/lib/axios'
import type { DashboardResponse } from '@/types'

export async function getDashboard(): Promise<DashboardResponse> {
  const { data } = await apiClient.get<DashboardResponse>('/admin/dashboard/')
  return data
}
