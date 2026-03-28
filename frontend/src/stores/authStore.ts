import { create } from 'zustand'
import { persist } from 'zustand/middleware'

import type { AuthResponse, AuthUser, TenantBranding } from '@/types'

interface AuthState {
  user: AuthUser | null
  token: string | null
  refreshToken: string | null
  tenant: TenantBranding | null
  isAuthenticated: boolean
  login: (payload: AuthResponse) => void
  logout: () => void
  setUser: (user: AuthUser) => void
}

export const AUTH_STORAGE_KEY = 'goklinik-auth'

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      refreshToken: null,
      tenant: null,
      isAuthenticated: false,
      login: (payload) => {
        set({
          user: payload.user,
          token: payload.access_token,
          refreshToken: payload.refresh_token,
          tenant: payload.user.tenant || null,
          isAuthenticated: true,
        })
      },
      logout: () => {
        set({
          user: null,
          token: null,
          refreshToken: null,
          tenant: null,
          isAuthenticated: false,
        })
      },
      setUser: (user) => {
        set((state) => ({ user, tenant: user.tenant || state.tenant }))
      },
    }),
    {
      name: AUTH_STORAGE_KEY,
      partialize: (state) => ({
        user: state.user,
        token: state.token,
        refreshToken: state.refreshToken,
        tenant: state.tenant,
        isAuthenticated: state.isAuthenticated,
      }),
    },
  ),
)
