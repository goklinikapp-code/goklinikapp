import { apiClient } from '@/lib/axios'
import type { WorkflowItem } from '@/types'

export async function getWorkflows(): Promise<WorkflowItem[]> {
  const { data } = await apiClient.get<WorkflowItem[]>('/notifications/workflows/')
  return data
}

interface SendMassMessagePayload {
  segment: string
  channel: 'whatsapp' | 'push'
  body: string
}

export async function sendMassMessage(payload: SendMassMessagePayload) {
  const normalizedSegment = payload.segment.trim().toLowerCase()
  const sendToAll = normalizedSegment === 'todos os pacientes'

  const requestPayload = {
    title: payload.channel === 'whatsapp' ? 'Campanha WhatsApp' : 'Campanha Push',
    body: payload.body,
    send_to_all: sendToAll,
  }

  const { data } = await apiClient.post('/notifications/admin/broadcast/', requestPayload)
  return data
}
