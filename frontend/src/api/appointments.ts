import { apiClient } from '@/lib/axios'
import { normalizeNextPagePath } from '@/api/pagination'

interface PaginatedResponse<T> {
  results: T[]
  next?: string | null
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

export interface ProfessionalAvailabilityRule {
  id?: string
  day_of_week: number
  start_time: string
  end_time: string
  is_active: boolean
}

interface ProfessionalAvailabilityResponse {
  professional_id: string
  professional_name: string
  rules: ProfessionalAvailabilityRule[]
}

export interface BlockedPeriodItem {
  id: string
  professional: string
  professional_name?: string
  start_datetime: string
  end_datetime: string
  reason: string
}

interface BlockedPeriodsResponse {
  professional_id: string
  professional_name: string
  results: BlockedPeriodItem[]
}

export async function getAppointments(params?: Record<string, string>): Promise<AppointmentItem[]> {
  let nextPath: string | null = '/appointments/'
  const rows: AppointmentItem[] = []
  let safety = 0
  let isFirstRequest = true

  while (nextPath && safety < 50) {
    safety += 1
    const response: {
      data: PaginatedResponse<AppointmentItem> | AppointmentItem[]
    } = await apiClient.get<PaginatedResponse<AppointmentItem> | AppointmentItem[]>(
      nextPath,
      {
        params: isFirstRequest ? params : undefined,
      },
    )
    const payload: PaginatedResponse<AppointmentItem> | AppointmentItem[] = response.data

    if (Array.isArray(payload)) {
      return payload
    }

    rows.push(...(payload.results || []))

    const next: string = (payload.next || '').trim()
    if (!next) {
      nextPath = null
      continue
    }

    nextPath = normalizeNextPagePath(next) || null

    isFirstRequest = false
  }

  return rows
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
    cancellation_reason?: string
  },
) {
  const { data } = await apiClient.put(`/appointments/${appointmentId}/`, payload)
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

export async function getProfessionalAvailabilityRules(params?: {
  professional_id?: string
}) {
  const { data } = await apiClient.get<ProfessionalAvailabilityResponse>(
    '/appointments/availability-rules/',
    { params },
  )
  return data
}

export async function updateProfessionalAvailabilityRules(payload: {
  professional_id?: string
  rules: ProfessionalAvailabilityRule[]
}) {
  const { data } = await apiClient.put<ProfessionalAvailabilityResponse>(
    '/appointments/availability-rules/',
    payload,
  )
  return data
}

export async function getBlockedPeriods(params?: {
  professional_id?: string
  date_from?: string
  date_to?: string
}) {
  const { data } = await apiClient.get<BlockedPeriodsResponse>(
    '/appointments/blocked-periods/',
    { params },
  )
  return data
}

export async function createBlockedPeriod(payload: {
  professional_id?: string
  start_datetime: string
  end_datetime: string
  reason: string
}) {
  const { data } = await apiClient.post<BlockedPeriodItem>(
    '/appointments/blocked-periods/',
    payload,
  )
  return data
}

export async function deleteBlockedPeriod(id: string) {
  await apiClient.delete('/appointments/blocked-periods/', {
    data: { id },
  })
}
