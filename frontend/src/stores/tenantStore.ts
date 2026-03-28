import { create } from 'zustand'

import { apiClient } from '@/lib/axios'
import { useAuthStore } from '@/stores/authStore'
import type { TenantBranding } from '@/types'

interface TenantState {
  tenantConfig: TenantBranding
  loadTenantBranding: (slug?: string) => Promise<void>
  setTenantConfig: (config: TenantBranding) => void
}

const defaultTenant: TenantBranding = {
  name: 'GoKlinik Demo',
  slug: 'goklinik-demo',
  primary_color: '#0D5C73',
  secondary_color: '#4A7C59',
  accent_color: '#C8992E',
  clinic_addresses: ['Unidade principal da clínica'],
  logo_url: '/assets/logo_go_klink.png',
  favicon_url: '/assets/favicon_go_klink.png',
  ai_assistant_prompt:
    'Você é a assistente virtual da clínica. Atenda com empatia, objetividade e nunca revele dados de outros pacientes.',
}

const hexToRgbChannels = (hexColor: string): string | null => {
  const clean = (hexColor || '').trim().replace('#', '')
  if (!/^[\da-f]{6}$/i.test(clean)) {
    return null
  }
  const r = Number.parseInt(clean.slice(0, 2), 16)
  const g = Number.parseInt(clean.slice(2, 4), 16)
  const b = Number.parseInt(clean.slice(4, 6), 16)
  return `${r} ${g} ${b}`
}

const applyBranding = (config: TenantBranding) => {
  const root = document.documentElement
  root.style.setProperty('--gk-primary', config.primary_color)
  root.style.setProperty('--gk-secondary', config.secondary_color)
  root.style.setProperty('--gk-accent', config.accent_color)

  const primaryRgb = hexToRgbChannels(config.primary_color) || '13 92 115'
  const secondaryRgb = hexToRgbChannels(config.secondary_color) || '74 124 89'
  const accentRgb = hexToRgbChannels(config.accent_color) || '200 153 46'

  root.style.setProperty('--gk-primary-rgb', primaryRgb)
  root.style.setProperty('--gk-secondary-rgb', secondaryRgb)
  root.style.setProperty('--gk-accent-rgb', accentRgb)

  const [r, g, b] = primaryRgb.split(' ')
  root.style.setProperty('--gk-teal-ice', `rgba(${r}, ${g}, ${b}, 0.12)`)
}

export const useTenantStore = create<TenantState>((set) => ({
  tenantConfig: defaultTenant,
  setTenantConfig: (config) => {
    const normalized = {
      ...config,
      clinic_addresses: config.clinic_addresses || [],
    }
    applyBranding(normalized)
    set({ tenantConfig: normalized })
  },
  loadTenantBranding: async (slug) => {
    const auth = useAuthStore.getState()
    const authenticatedTenantId = auth.tenant?.id || auth.user?.tenant?.id
    const fallbackSlug = slug || auth.tenant?.slug || auth.user?.tenant?.slug || 'goklinik-demo'

    try {
      let data: TenantBranding

      if (auth.isAuthenticated) {
        const { data: currentTenantBranding } = await apiClient.get<TenantBranding>(
          '/public/tenants/branding/',
          {
            params: authenticatedTenantId ? { tenant_id: authenticatedTenantId } : undefined,
          },
        )
        data = currentTenantBranding
      } else {
        const { data: publicBranding } = await apiClient.get<TenantBranding>(
          `/public/tenants/${fallbackSlug}/branding/`,
        )
        data = publicBranding
      }

      const merged = {
        ...defaultTenant,
        ...data,
        clinic_addresses: data.clinic_addresses || defaultTenant.clinic_addresses,
      }
      applyBranding(merged)
      set({ tenantConfig: merged })
    } catch {
      try {
        const { data } = await apiClient.get<TenantBranding>(
          `/public/tenants/${fallbackSlug}/branding/`,
        )
        const merged = {
          ...defaultTenant,
          ...data,
          clinic_addresses: data.clinic_addresses || defaultTenant.clinic_addresses,
        }
        applyBranding(merged)
        set({ tenantConfig: merged })
      } catch {
        applyBranding(defaultTenant)
        set({ tenantConfig: defaultTenant })
      }
    }
  },
}))
