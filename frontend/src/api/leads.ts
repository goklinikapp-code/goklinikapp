import { apiClient } from '@/lib/axios'

export interface LeadSeller {
  id: string
  name: string
  email: string
  ref_code: string
}

export interface Lead {
  id: string
  name: string
  email: string
  phone: string
  ref_code: string | null
  seller: LeadSeller | null
  created_at: string
}

export interface LeadCreatePayload {
  name: string
  email: string
  phone: string
  ref_code?: string
}

export interface LeadUpdatePayload {
  name: string
  email: string
  phone: string
}

export interface LeadListFilters {
  seller?: string
  ref_code?: string
  start_date?: string
  end_date?: string
  page?: number
}

export interface LeadListResponse {
  count: number
  next: string | null
  previous: string | null
  results: Lead[]
}

export async function createLead(payload: LeadCreatePayload): Promise<Lead> {
  const { data } = await apiClient.post<Lead>('/leads', payload)
  return data
}

export async function getLeads(filters: LeadListFilters = {}): Promise<LeadListResponse> {
  const { data } = await apiClient.get<Lead[] | LeadListResponse>('/leads', {
    params: filters,
  })
  if (Array.isArray(data)) {
    return {
      count: data.length,
      next: null,
      previous: null,
      results: data,
    }
  }
  return data
}

export async function deleteLead(leadId: string): Promise<void> {
  await apiClient.delete(`/leads/${leadId}/`)
}

export async function updateLead(leadId: string, payload: LeadUpdatePayload): Promise<Lead> {
  const { data } = await apiClient.put<Lead>(`/leads/${leadId}/`, payload)
  return data
}
