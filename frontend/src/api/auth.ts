import { apiClient } from '@/lib/axios'
import type { AuthResponse, AuthUser } from '@/types'

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

interface ChangePasswordPayload {
  current_password: string
  new_password: string
}

interface DetailResponse {
  detail: string
}

export async function getCurrentUser(): Promise<AuthUser> {
  const { data } = await apiClient.get<AuthUser>('/auth/me/')
  return data
}

export async function uploadCurrentUserAvatar(file: File): Promise<AuthUser> {
  const formData = new FormData()
  formData.append('avatar', file)
  const { data } = await apiClient.post<AuthUser>('/auth/me/avatar/', formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  })
  return data
}

export async function changeCurrentUserPassword(
  payload: ChangePasswordPayload,
): Promise<DetailResponse> {
  const { data } = await apiClient.post<DetailResponse>('/auth/change-password/', payload)
  return data
}
