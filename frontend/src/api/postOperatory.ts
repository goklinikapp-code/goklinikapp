import { apiClient } from '@/lib/axios'
import type {
  PostOperatoryAdminDetail,
  PostOperatoryAdminItem,
  UrgentTicketRecord,
} from '@/types'

export async function listTenantPostOperatory(status?: 'active' | 'completed' | 'cancelled') {
  const params = status ? { status } : undefined
  const { data } = await apiClient.get<PostOperatoryAdminItem[]>('/post-operatory/', {
    params,
  })
  return data
}

export async function getPostOperatoryByPatient(patientId: string) {
  const { data } = await apiClient.get<PostOperatoryAdminDetail>(`/post-operatory/${patientId}/`)
  return data
}

export async function listUrgentTickets() {
  const { data } = await apiClient.get<UrgentTicketRecord[]>('/urgent-tickets/')
  return data
}

export async function updateUrgentTicketStatus(
  ticketId: string,
  status: 'viewed' | 'resolved',
) {
  const { data } = await apiClient.patch<UrgentTicketRecord>(`/urgent-tickets/${ticketId}/`, {
    status,
  })
  return data
}
