import { apiClient } from '@/lib/axios'

interface PaginatedResponse<T> {
  results: T[]
}

export interface AppointmentItem {
  id: string
  tenant?: string
  patient: string
  patient_name: string
  patient_avatar_url?: string | null
  professional: string
  professional_name: string
  professional_avatar_url?: string | null
  clinic_location?: string | null
  specialty?: string | null
  specialty_name?: string | null
  appointment_date: string
  appointment_time: string
  duration_minutes?: number
  appointment_type: string
  status: string
  notes?: string
  internal_notes?: string
  cancellation_reason?: string
  created_at?: string
  updated_at?: string
}

interface CreateAppointmentPayload {
  patient: string
  professional: string
  clinic_location?: string
  appointment_date: string
  appointment_time: string
  appointment_type: string
  notes?: string
}

export interface UpdateAppointmentPayload {
  patient: string
  professional: string
  clinic_location?: string
  appointment_date: string
  appointment_time: string
  appointment_type: string
  status?: string
  duration_minutes?: number
  notes?: string
}

interface AvailableSlotsResponse {
  professional_id: string
  date: string
  slots: string[]
}

export async function getAppointments(params?: Record<string, string>): Promise<AppointmentItem[]> {
  const { data } = await apiClient.get<PaginatedResponse<AppointmentItem> | AppointmentItem[]>('/appointments/', {
    params,
  })

  if (Array.isArray(data)) {
    return data
  }
  return data.results || []
}

export async function createAppointment(payload: CreateAppointmentPayload) {
  const { data } = await apiClient.post('/appointments/', payload)
  return data
}

export async function updateAppointment(
  appointmentId: string,
  payload: UpdateAppointmentPayload,
) {
  const { data } = await apiClient.patch(`/appointments/${appointmentId}/`, payload)
  return data
}

export async function updateAppointmentStatus(
  appointmentId: string,
  payload: {
    status: string
    internal_notes?: string
  },
) {
  const { data } = await apiClient.put(`/appointments/${appointmentId}/status/`, payload)
  return data
}

export async function cancelAppointment(
  appointmentId: string,
  reason: string,
) {
  await apiClient.delete(`/appointments/${appointmentId}/`, {
    data: {
      reason,
    },
  })
}

export async function getAvailableSlots(params: {
  professional_id: string
  date: string
  specialty_id?: string
}): Promise<string[]> {
  const { data } = await apiClient.get<AvailableSlotsResponse>('/appointments/available-slots/', {
    params,
  })
  return Array.isArray(data?.slots) ? data.slots : []
}
