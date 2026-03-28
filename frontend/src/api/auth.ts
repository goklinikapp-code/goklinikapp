import { apiClient } from '@/lib/axios'
import type { AuthResponse } from '@/types'

interface LoginPayload {
  identifier: string
  password: string
}

export async function login(payload: LoginPayload): Promise<AuthResponse> {
  const { data } = await apiClient.post<AuthResponse>('/auth/login/', {
    identifier: payload.identifier,
    password: payload.password,
  })
  return data
}
