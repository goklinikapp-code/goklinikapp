import { apiClient } from '@/lib/axios'
import type { PreOperatoryRecord } from '@/types'

export type PreOperatoryStatus = PreOperatoryRecord['status']

export interface PreOperatoryAdminUpdatePayload {
  status?: PreOperatoryStatus
  notes?: string
  assigned_doctor?: string | null
}

export async function listTenantPreOperatory(status?: PreOperatoryStatus) {
  const params = status ? { status } : undefined
  const { data } = await apiClient.get<PreOperatoryRecord[]>('/pre-operatory', { params })
  return data
}

export async function updatePreOperatoryById(
  preOperatoryId: string,
  payload: PreOperatoryAdminUpdatePayload,
) {
  const requestPayload: Record<string, unknown> = {}

  if (typeof payload.status === 'string') {
    requestPayload.status = payload.status
  }
  if (typeof payload.notes === 'string') {
    requestPayload.notes = payload.notes.trim()
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'assigned_doctor')) {
    requestPayload.assigned_doctor = payload.assigned_doctor || null
  }

  const { data } = await apiClient.put<PreOperatoryRecord>(
    `/pre-operatory/${preOperatoryId}`,
    requestPayload,
  )
  return data
}
