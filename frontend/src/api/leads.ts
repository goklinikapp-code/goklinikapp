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

export interface LeadListFilters {
  seller?: string
  ref_code?: string
  start_date?: string
  end_date?: string
}

export async function createLead(payload: LeadCreatePayload): Promise<Lead> {
  const { data } = await apiClient.post<Lead>('/leads', payload)
  return data
}

export async function getLeads(filters: LeadListFilters = {}): Promise<Lead[]> {
  const { data } = await apiClient.get<Lead[]>('/leads', {
    params: filters,
  })
  return data
}
