import { apiClient } from '@/lib/axios'
import type {
  PostOperatoryAdminDetail,
  PostOperatoryAdminItem,
  UrgentMedicalRequestRecord,
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

export async function listUrgentMedicalRequests() {
  const { data } = await apiClient.get<UrgentMedicalRequestRecord[]>('/post-operatory/urgent-requests/')
  return data
}

export async function replyUrgentMedicalRequest(
  requestId: string,
  answer: string,
) {
  const { data } = await apiClient.put<UrgentMedicalRequestRecord>(
    `/post-operatory/urgent-requests/${requestId}/reply/`,
    { answer },
  )
  return data
}
