import { apiClient } from '@/lib/axios'

export type ReferralStatus = 'pending' | 'converted' | 'paid'

export interface ReferralsSummary {
  total_referrals: number
  total_converted: number
  total_paid_count: number
  total_commission_pending: number
  total_commission_paid: number
}

export interface ReferralListItem {
  id: string
  referrer: {
    name: string
    phone: string
  }
  referred: {
    name: string
    phone: string
  }
  status: ReferralStatus
  commission_value: number
  created_at: string
  converted_at?: string | null
  paid_at?: string | null
}

export interface ClinicReferralLink {
  tenant_slug: string
  referral_code: string
  referral_link: string
}

interface ReferralsSummaryResponse {
  total_referrals: number
  total_converted: number
  total_paid_count: number
  total_commission_pending: number | string | null
  total_commission_paid: number | string | null
}

interface ReferralListItemResponse {
  id: string
  referrer?: {
    name?: string | null
    phone?: string | null
  }
  referred?: {
    name?: string | null
    phone?: string | null
  }
  status: ReferralStatus
  commission_value?: number | string | null
  created_at: string
  converted_at?: string | null
  paid_at?: string | null
}

interface ClinicReferralLinkResponse {
  tenant_slug?: string | null
  referral_code?: string | null
  referral_link?: string | null
}

export async function getReferralsSummary(): Promise<ReferralsSummary> {
  const { data } = await apiClient.get<ReferralsSummaryResponse>('/referrals/admin/summary/')
  return {
    total_referrals: Number(data.total_referrals || 0),
    total_converted: Number(data.total_converted || 0),
    total_paid_count: Number(data.total_paid_count || 0),
    total_commission_pending: Number(data.total_commission_pending || 0),
    total_commission_paid: Number(data.total_commission_paid || 0),
  }
}

export async function getReferralsList(status?: ReferralStatus): Promise<ReferralListItem[]> {
  const { data } = await apiClient.get<ReferralListItemResponse[]>('/referrals/admin/list/', {
    params: status ? { status } : undefined,
  })

  return (data || []).map((item) => ({
    id: item.id,
    referrer: {
      name: item.referrer?.name || 'Paciente',
      phone: item.referrer?.phone || '-',
    },
    referred: {
      name: item.referred?.name || 'Paciente',
      phone: item.referred?.phone || '-',
    },
    status: item.status,
    commission_value: Number(item.commission_value || 0),
    created_at: item.created_at,
    converted_at: item.converted_at || null,
    paid_at: item.paid_at || null,
  }))
}

export async function markConverted(id: string): Promise<void> {
  await apiClient.put(`/referrals/${id}/mark-converted/`, {})
}

export async function markPaid(id: string, commissionValue: number): Promise<void> {
  await apiClient.put(`/referrals/${id}/mark-paid/`, {
    commission_value: commissionValue,
  })
}

export async function getClinicReferralLink(): Promise<ClinicReferralLink> {
  const { data } = await apiClient.get<ClinicReferralLinkResponse>('/referrals/admin/link/')
  return {
    tenant_slug: (data.tenant_slug || '').toString(),
    referral_code: (data.referral_code || '').toString(),
    referral_link: (data.referral_link || '').toString(),
  }
}
