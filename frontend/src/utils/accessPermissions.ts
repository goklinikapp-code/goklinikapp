import type { AuthUser, UserRole } from '@/types'
import type { TranslationKey } from '@/i18n/system'

export type AccessPermissionKey =
  | 'dashboard'
  | 'app'
  | 'patients'
  | 'pre_operatory'
  | 'post_operatory'
  | 'schedule'
  | 'travel_plans'
  | 'chat_center'
  | 'reports'
  | 'referrals'
  | 'team'
  | 'automations'
  | 'settings'
  | 'tutorials'

export interface AccessPermissionDefinition {
  key: AccessPermissionKey
  labelKey: TranslationKey
  descriptionKey: TranslationKey
}

export const ACCESS_PERMISSION_DEFINITIONS: AccessPermissionDefinition[] = [
  {
    key: 'dashboard',
    labelKey: 'access_dashboard_label',
    descriptionKey: 'access_dashboard_description',
  },
  {
    key: 'app',
    labelKey: 'access_app_label',
    descriptionKey: 'access_app_description',
  },
  {
    key: 'patients',
    labelKey: 'access_patients_label',
    descriptionKey: 'access_patients_description',
  },
  {
    key: 'pre_operatory',
    labelKey: 'access_pre_operatory_label',
    descriptionKey: 'access_pre_operatory_description',
  },
  {
    key: 'post_operatory',
    labelKey: 'access_post_operatory_label',
    descriptionKey: 'access_post_operatory_description',
  },
  {
    key: 'schedule',
    labelKey: 'access_schedule_label',
    descriptionKey: 'access_schedule_description',
  },
  {
    key: 'travel_plans',
    labelKey: 'access_travel_plans_label',
    descriptionKey: 'access_travel_plans_description',
  },
  {
    key: 'chat_center',
    labelKey: 'access_chat_center_label',
    descriptionKey: 'access_chat_center_description',
  },
  {
    key: 'reports',
    labelKey: 'access_reports_label',
    descriptionKey: 'access_reports_description',
  },
  {
    key: 'referrals',
    labelKey: 'access_referrals_label',
    descriptionKey: 'access_referrals_description',
  },
  {
    key: 'team',
    labelKey: 'access_team_label',
    descriptionKey: 'access_team_description',
  },
  {
    key: 'automations',
    labelKey: 'access_automations_label',
    descriptionKey: 'access_automations_description',
  },
  {
    key: 'settings',
    labelKey: 'access_settings_label',
    descriptionKey: 'access_settings_description',
  },
  {
    key: 'tutorials',
    labelKey: 'access_tutorials_label',
    descriptionKey: 'access_tutorials_description',
  },
]

export const ALL_ACCESS_PERMISSIONS = ACCESS_PERMISSION_DEFINITIONS.map((item) => item.key)

const DEFAULT_ROLE_ACCESS: Record<UserRole, AccessPermissionKey[]> = {
  super_admin: [],
  clinic_master: ALL_ACCESS_PERMISSIONS,
  surgeon: ['dashboard', 'patients', 'pre_operatory', 'post_operatory', 'schedule'],
  secretary: [
    'dashboard',
    'app',
    'patients',
    'schedule',
    'travel_plans',
    'chat_center',
    'reports',
    'automations',
  ],
  nurse: ['dashboard', 'app', 'patients', 'pre_operatory', 'post_operatory', 'schedule'],
  patient: [],
}

const LEGACY_PERMISSION_ALIASES: Record<AccessPermissionKey, AccessPermissionKey[]> = {
  dashboard: [],
  app: [],
  patients: [],
  pre_operatory: ['patients'],
  post_operatory: ['patients'],
  schedule: [],
  travel_plans: ['schedule'],
  chat_center: ['patients'],
  reports: [],
  referrals: [],
  team: [],
  automations: [],
  settings: [],
  tutorials: [],
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
    if (explicitPermissions.includes(permission)) {
      return true
    }
    return LEGACY_PERMISSION_ALIASES[permission].some((legacyPermission) =>
      explicitPermissions.includes(legacyPermission),
    )
  }

  return getDefaultAccessPermissionsForRole(user.role).includes(permission)
}
