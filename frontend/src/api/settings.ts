import { apiClient } from '@/lib/axios'
import type { TenantBranding } from '@/types'

export async function uploadBrandingLogo(file: File, tenantId?: string) {
  const formData = new FormData()
  formData.append('logo', file)
  if (tenantId) {
    formData.append('tenant_id', tenantId)
  }
  const { data } = await apiClient.post('/public/tenants/branding/logo/', formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  })
  return data as TenantBranding
}

export async function updateBranding(payload: TenantBranding) {
  const requestPayload: Record<string, unknown> = {
    tenant_id: payload.id,
    name: payload.name,
    primary_color: payload.primary_color,
    secondary_color: payload.secondary_color,
    accent_color: payload.accent_color,
    clinic_addresses: (payload.clinic_addresses || []).map((item) => item.trim()).filter(Boolean),
    ai_assistant_prompt: (payload.ai_assistant_prompt || '').trim(),
  }

  const logoUrl = typeof payload.logo_url === 'string' ? payload.logo_url.trim() : payload.logo_url
  if (logoUrl === null || logoUrl === '') {
    requestPayload.logo_url = null
  } else if (typeof logoUrl === 'string' && /^https?:\/\//i.test(logoUrl)) {
    requestPayload.logo_url = logoUrl
  }

  const faviconUrl = typeof payload.favicon_url === 'string' ? payload.favicon_url.trim() : payload.favicon_url
  if (faviconUrl === null || faviconUrl === '') {
    requestPayload.favicon_url = null
  } else if (typeof faviconUrl === 'string' && /^https?:\/\//i.test(faviconUrl)) {
    requestPayload.favicon_url = faviconUrl
  }

  const { data } = await apiClient.put('/public/tenants/branding/', requestPayload)
  return data
}

export interface TenantProcedure {
  id: string
  specialty_name: string
  description: string
  specialty_icon: string
  default_duration_minutes: number
  is_active: boolean
  display_order: number
}

export interface TenantProcedurePayload {
  specialty_name?: string
  description?: string
  specialty_icon?: string
  default_duration_minutes?: number
  is_active?: boolean
  display_order?: number
  tenant_id?: string
}

export async function listTenantProcedures(tenantId?: string) {
  const { data } = await apiClient.get<TenantProcedure[]>('/public/tenants/procedures/', {
    params: tenantId ? { tenant_id: tenantId } : undefined,
  })
  return data
}

export async function createTenantProcedure(payload: TenantProcedurePayload) {
  const { data } = await apiClient.post<TenantProcedure>('/public/tenants/procedures/', payload)
  return data
}

export async function updateTenantProcedure(
  specialtyId: string,
  payload: TenantProcedurePayload,
) {
  const { data } = await apiClient.patch<TenantProcedure>(
    `/public/tenants/procedures/${specialtyId}/`,
    payload,
  )
  return data
}

export async function deleteTenantProcedure(specialtyId: string, tenantId?: string) {
  await apiClient.delete(`/public/tenants/procedures/${specialtyId}/`, {
    data: tenantId ? { tenant_id: tenantId } : undefined,
  })
}
