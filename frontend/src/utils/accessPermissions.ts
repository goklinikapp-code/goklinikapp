import type { AuthUser, UserRole } from '@/types'

export type AccessPermissionKey =
  | 'dashboard'
  | 'app'
  | 'patients'
  | 'schedule'
  | 'reports'
  | 'referrals'
  | 'team'
  | 'automations'
  | 'settings'
  | 'tutorials'

export interface AccessPermissionDefinition {
  key: AccessPermissionKey
  label: string
  description: string
}

export const ACCESS_PERMISSION_DEFINITIONS: AccessPermissionDefinition[] = [
  { key: 'dashboard', label: 'Dashboard', description: 'Resumo e métricas da clínica' },
  { key: 'app', label: 'Aplicativo', description: 'Links dos apps e indicação do paciente' },
  { key: 'patients', label: 'Pacientes', description: 'Lista de pacientes e prontuário' },
  { key: 'schedule', label: 'Agenda', description: 'Visualização e gestão de agendamentos' },
  { key: 'reports', label: 'Relatórios', description: 'Indicadores e desempenho da clínica' },
  { key: 'referrals', label: 'Indicações', description: 'Comissões e programa de indicação' },
  { key: 'team', label: 'Equipe', description: 'Convidar e gerenciar membros' },
  { key: 'automations', label: 'Automações', description: 'Fluxos automáticos da clínica' },
  { key: 'settings', label: 'Configurações', description: 'Branding, idioma e parâmetros' },
  { key: 'tutorials', label: 'Tutoriais', description: 'Cursos e onboarding da plataforma' },
]

export const ALL_ACCESS_PERMISSIONS = ACCESS_PERMISSION_DEFINITIONS.map((item) => item.key)

const DEFAULT_ROLE_ACCESS: Record<UserRole, AccessPermissionKey[]> = {
  super_admin: [],
  clinic_master: ALL_ACCESS_PERMISSIONS,
  surgeon: ['dashboard', 'app', 'patients', 'schedule', 'reports'],
  secretary: ['dashboard', 'app', 'patients', 'schedule', 'reports'],
  nurse: ['dashboard', 'app', 'patients', 'schedule'],
  patient: [],
}

export function normalizeAccessPermissions(value: string[] | undefined | null): AccessPermissionKey[] {
  if (!Array.isArray(value)) return []
  const validKeys = new Set<AccessPermissionKey>(ALL_ACCESS_PERMISSIONS)
  const normalized: AccessPermissionKey[] = []
  for (const raw of value) {
    const key = String(raw || '').trim().toLowerCase() as AccessPermissionKey
    if (!validKeys.has(key) || normalized.includes(key)) continue
    normalized.push(key)
  }
  return normalized
}

export function getDefaultAccessPermissionsForRole(role: UserRole): AccessPermissionKey[] {
  return [...(DEFAULT_ROLE_ACCESS[role] || [])]
}

export function hasAccessPermission(
  user: Pick<AuthUser, 'role' | 'access_permissions'> | null | undefined,
  permission: AccessPermissionKey,
): boolean {
  if (!user) return false
  if (user.role === 'super_admin' || user.role === 'clinic_master') return true

  const explicitPermissions = normalizeAccessPermissions(user.access_permissions)
  if (explicitPermissions.length > 0) {
    return explicitPermissions.includes(permission)
  }

  return getDefaultAccessPermissionsForRole(user.role).includes(permission)
}

