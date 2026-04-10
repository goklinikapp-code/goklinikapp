import { apiClient } from '@/lib/axios'
import { normalizeNextPagePath } from '@/api/pagination'
import type { PatientDetail, PatientRow } from '@/types'

interface PaginatedResponse<T> {
  results: T[]
  next?: string | null
}

export interface PatientsFilters {
  status?: string
  app_status?: 'installed' | 'not_installed'
}

export interface PatientsImportResponse {
  total_rows: number
  imported: number
  duplicates: number
  errors: number
  error_details: string[]
}

export async function getPatients(filters: PatientsFilters = {}): Promise<PatientRow[]> {
  const queryParams = new URLSearchParams()
  if (filters.status) {
    queryParams.set('status', filters.status)
  }
  if (filters.app_status) {
    queryParams.set('app_status', filters.app_status)
  }

  const queryString = queryParams.toString()
  let nextPath: string | null = queryString ? `/patients/?${queryString}` : '/patients/'
  const rows: PatientRow[] = []
  let safety = 0

  while (nextPath && safety < 20) {
    safety += 1
    const response = await apiClient.get<PaginatedResponse<PatientRow> | PatientRow[]>(
      nextPath,
    )
    const payload: PaginatedResponse<PatientRow> | PatientRow[] = response.data

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
  }

  return rows
}

export async function importPatients(file: File): Promise<PatientsImportResponse> {
  const formData = new FormData()
  formData.append('file', file)

  const { data } = await apiClient.post<PatientsImportResponse>('/patients/import/', formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  })
  return data
}

interface CreatePatientPayload {
  full_name: string
  cpf: string
  email: string
  phone: string
  date_of_birth: string
  password: string
  specialty_name?: string
  referral_source: string
}

const referralSourceMap: Record<string, string> = {
  instagram: 'instagram',
  indication: 'indication',
  indicacao: 'indication',
  'indicação': 'indication',
  google: 'google',
  other: 'other',
  outro: 'other',
}

export async function createPatient(payload: CreatePatientPayload) {
  const normalizedReferral =
    referralSourceMap[payload.referral_source.trim().toLowerCase()] || 'other'

  const requestPayload: Record<string, unknown> = {
    full_name: payload.full_name,
    cpf: payload.cpf,
    email: payload.email,
    phone: payload.phone,
    date_of_birth: payload.date_of_birth,
    password: payload.password,
    referral_source: normalizedReferral,
  }

  if (payload.specialty_name?.trim()) {
    requestPayload.specialty_name = payload.specialty_name.trim()
  }

  const { data } = await apiClient.post('/patients/', requestPayload)
  return data
}

interface TeamMemberApi {
  id: string
  full_name: string
  role: string
}

export interface DoctorOption {
  id: string
  name: string
  specialty: string
}

export async function getDoctors(): Promise<DoctorOption[]> {
  const { data } = await apiClient.get<TeamMemberApi[]>('/auth/team/')
  return (data || [])
    .filter((member) => member.role === 'surgeon')
    .map((member) => ({
      id: member.id,
      name: member.full_name,
      specialty: 'Cirurgiao',
    }))
}

export async function assignDoctorToPatient(
  patientId: string,
  doctorId: string,
  notes: string,
): Promise<PatientRow> {
  const { data } = await apiClient.post<PatientRow>(`/patients/${patientId}/assign-doctor/`, {
    doctor_id: doctorId,
    notes,
  })
  return data
}

export interface UpdatePatientPayload {
  full_name?: string
  email?: string
  phone?: string
  cpf?: string
  date_of_birth?: string
  specialty_name?: string
  status?: 'active' | 'inactive' | 'lead'
  referral_source?: string
  notes?: string
}

export async function getPatientById(patientId: string): Promise<PatientDetail> {
  const { data } = await apiClient.get<PatientDetail>(`/patients/${patientId}/`)
  return data
}

export async function updatePatient(
  patientId: string,
  payload: UpdatePatientPayload,
): Promise<PatientDetail> {
  const requestPayload: Record<string, unknown> = {}

  if (typeof payload.full_name === 'string') requestPayload.full_name = payload.full_name.trim()
  if (typeof payload.email === 'string') requestPayload.email = payload.email.trim()
  if (typeof payload.phone === 'string') requestPayload.phone = payload.phone.trim()
  if (typeof payload.cpf === 'string') requestPayload.cpf = payload.cpf.trim()
  if (typeof payload.date_of_birth === 'string') requestPayload.date_of_birth = payload.date_of_birth
  if (typeof payload.specialty_name === 'string') {
    requestPayload.specialty_name = payload.specialty_name.trim()
  }
  if (typeof payload.status === 'string') requestPayload.status = payload.status
  if (typeof payload.notes === 'string') requestPayload.notes = payload.notes
  if (typeof payload.referral_source === 'string') {
    requestPayload.referral_source =
      referralSourceMap[payload.referral_source.trim().toLowerCase()] || 'other'
  }

  const { data } = await apiClient.patch<PatientDetail>(
    `/patients/${patientId}/`,
    requestPayload,
  )
  return data
}
