import { apiClient } from '@/lib/axios'
import type { SupportedLanguage } from '@/i18n/system'
import type { ActivityLog, TeamMember, TeamMemberDetail, UserRole } from '@/types'

interface TeamMemberApi {
  id: string
  email: string
  full_name: string
  role: string
  is_active: boolean
  avatar_url?: string
  access_permissions?: string[]
}

interface TeamMemberDetailApi extends TeamMemberApi {
  first_name?: string
  last_name?: string
  phone?: string
  cpf?: string
  date_of_birth?: string | null
  bio?: string
  crm_number?: string
  years_experience?: number | null
  is_visible_in_app?: boolean
  date_joined?: string
}

function mapRoleLabel(role: string): TeamMember['role'] {
  const roleMap: Record<string, TeamMember['role']> = {
    clinic_master: 'Clinic Master',
    surgeon: 'Surgeon',
    secretary: 'Secretary',
    nurse: 'Nursing',
    super_admin: 'SaaS Owner',
  }
  return roleMap[role] || 'Secretary'
}

function mapMember(member: TeamMemberApi): TeamMember {
  return {
    id: member.id,
    name: member.full_name,
    email: member.email,
    role: mapRoleLabel(member.role),
    role_code: member.role as UserRole,
    access_permissions: member.access_permissions || [],
    status: member.is_active ? 'active' : 'inactive',
    avatar: member.avatar_url,
  }
}

const roleMapPayload: Record<string, string> = {
  'Clinic Master': 'master',
  Surgeon: 'surgeon',
  Secretary: 'secretary',
  Nursing: 'nursing',
  'SaaS Owner': 'super_admin',
  clinic_master: 'clinic_master',
  surgeon: 'surgeon',
  secretary: 'secretary',
  nursing: 'nursing',
  nurse: 'nurse',
  super_admin: 'super_admin',
}

export async function getTeamMembers(): Promise<TeamMember[]> {
  const { data } = await apiClient.get<TeamMemberApi[]>('/auth/team/')
  return data.map(mapMember)
}

export async function getActivityLogs(): Promise<ActivityLog[]> {
  const { data } = await apiClient.get<ActivityLog[]>('/auth/activity-log/')
  return data
}

export async function inviteUser(payload: {
  full_name: string
  email: string
  role: string
  access_permissions?: string[]
  language?: SupportedLanguage
}) {
  const requestPayload = {
    ...payload,
    role: roleMapPayload[payload.role] || payload.role.toLowerCase(),
  }
  const { data } = await apiClient.post('/auth/invite/', requestPayload)
  return data
}

export async function getTeamMemberById(memberId: string): Promise<TeamMemberDetail> {
  const { data } = await apiClient.get<TeamMemberDetailApi>(`/auth/team/${memberId}/`)
  return {
    ...mapMember(data),
    first_name: data.first_name || '',
    last_name: data.last_name || '',
    phone: data.phone || '',
    cpf: data.cpf || '',
    date_of_birth: data.date_of_birth || null,
    bio: data.bio || '',
    crm_number: data.crm_number || '',
    years_experience: data.years_experience ?? null,
    is_visible_in_app: Boolean(data.is_visible_in_app),
    avatar_url: data.avatar_url || '',
    date_joined: data.date_joined || '',
  }
}

export async function updateTeamMember(
  memberId: string,
  payload: {
    full_name?: string
    email?: string
    role?: string
    access_permissions?: string[]
    phone?: string
    cpf?: string
    date_of_birth?: string | null
    bio?: string
    crm_number?: string
    years_experience?: number | null
    is_visible_in_app?: boolean
    avatar_url?: string
    is_active?: boolean
  },
): Promise<TeamMemberDetail> {
  const mappedRole =
    payload.role && roleMapPayload[payload.role]
      ? roleMapPayload[payload.role]
      : payload.role

  const body = {
    ...payload,
    role: mappedRole,
  }

  const { data } = await apiClient.patch<TeamMemberDetailApi>(`/auth/team/${memberId}/`, body)
  return {
    ...mapMember(data),
    first_name: data.first_name || '',
    last_name: data.last_name || '',
    phone: data.phone || '',
    cpf: data.cpf || '',
    date_of_birth: data.date_of_birth || null,
    bio: data.bio || '',
    crm_number: data.crm_number || '',
    years_experience: data.years_experience ?? null,
    is_visible_in_app: Boolean(data.is_visible_in_app),
    avatar_url: data.avatar_url || '',
    date_joined: data.date_joined || '',
  }
}

export async function deleteTeamMember(memberId: string) {
  await apiClient.delete(`/auth/team/${memberId}/`)
}
