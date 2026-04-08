import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { AlertTriangle, Pencil, Plus, Trash2, UserCheck, UserX } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import toast from 'react-hot-toast'
import { z } from 'zod'

import {
  deleteTeamMember,
  getActivityLogs,
  getTeamMemberById,
  getTeamMembers,
  inviteUser,
  updateTeamMember,
} from '@/api/team'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Modal } from '@/components/ui/Modal'
import { TextArea } from '@/components/ui/TextArea'
import { t as translate, type TranslationKey } from '@/i18n/system'
import { useAuthStore } from '@/stores/authStore'
import { usePreferencesStore } from '@/stores/preferencesStore'
import type { TeamMemberDetail, UserRole } from '@/types'
import {
  ACCESS_PERMISSION_DEFINITIONS,
  getDefaultAccessPermissionsForRole,
  type AccessPermissionKey,
} from '@/utils/accessPermissions'
import { formatDate } from '@/utils/format'

const roleOptions = [
  {
    id: 'Clinic Master',
    titleKey: 'team_role_clinic_master_title',
    descriptionKey: 'team_role_clinic_master_description',
  },
  {
    id: 'Surgeon',
    titleKey: 'team_role_surgeon_title',
    descriptionKey: 'team_role_surgeon_description',
  },
  {
    id: 'Secretary',
    titleKey: 'team_role_secretary_title',
    descriptionKey: 'team_role_secretary_description',
  },
  {
    id: 'Nursing',
    titleKey: 'team_role_nursing_title',
    descriptionKey: 'team_role_nursing_description',
  },
].map((role) => role as { id: string; titleKey: TranslationKey; descriptionKey: TranslationKey })

const manageableRoles: UserRole[] = ['clinic_master', 'super_admin']

type InviteForm = {
  full_name: string
  email: string
  role: string
  access_permissions?: string[]
}

type TeamMemberForm = {
  full_name: string
  email: string
  role: string
  phone: string
  cpf: string
  date_of_birth: string
  bio: string
  crm_number: string
  years_experience: string
  avatar_url: string
  is_visible_in_app: boolean
}

type TeamMemberConfirmationState =
  | {
      action: 'toggle'
      memberId: string
      memberName: string
      nextActive: boolean
    }
  | {
      action: 'delete'
      memberId: string
      memberName: string
    }
  | null

function extractErrorMessage(error: unknown, fallback: string): string {
  if (!isAxiosError(error)) {
    return fallback
  }

  const data = error.response?.data as Record<string, unknown> | undefined
  if (!data) {
    return fallback
  }

  if (typeof data.detail === 'string' && data.detail.trim()) {
    return data.detail
  }

  const firstValue = Object.values(data)[0]
  if (typeof firstValue === 'string' && firstValue.trim()) {
    return firstValue
  }
  if (Array.isArray(firstValue) && firstValue.length > 0) {
    return String(firstValue[0])
  }

  return fallback
}

function roleCodeFromLabel(label: string): string {
  const normalized = label.trim().toLowerCase()
  if (normalized === 'clinic master') return 'clinic_master'
  if (normalized === 'surgeon') return 'surgeon'
  if (normalized === 'secretary') return 'secretary'
  if (normalized === 'nursing') return 'nurse'
  if (normalized === 'saas owner') return 'super_admin'
  return normalized.replace(/\s+/g, '_')
}

function roleLabelFromCode(role: string, t: (key: TranslationKey) => string): string {
  const normalized = role.trim().toLowerCase()
  if (normalized === 'clinic_master') return t('team_role_clinic_master_title')
  if (normalized === 'surgeon') return t('team_role_surgeon_title')
  if (normalized === 'secretary') return t('team_role_secretary_title')
  if (normalized === 'nurse') return t('team_role_nursing_title')
  if (normalized === 'super_admin') return t('role_super_admin')
  return role
}

function getDefaultPermissionsByInviteRoleLabel(roleLabel: string): AccessPermissionKey[] {
  const roleCode = roleCodeFromLabel(roleLabel) as UserRole
  if (!roleCode) return []
  return getDefaultAccessPermissionsForRole(roleCode)
}

function buildMemberForm(member: TeamMemberDetail): TeamMemberForm {
  return {
    full_name: member.name || '',
    email: member.email || '',
    role: member.role_code || roleCodeFromLabel(member.role),
    phone: member.phone || '',
    cpf: member.cpf || '',
    date_of_birth: member.date_of_birth || '',
    bio: member.bio || '',
    crm_number: member.crm_number || '',
    years_experience:
      member.years_experience === null || member.years_experience === undefined
        ? ''
        : String(member.years_experience),
    avatar_url: member.avatar_url || '',
    is_visible_in_app: Boolean(member.is_visible_in_app),
  }
}

export default function TeamPage() {
  const [isInviteModalOpen, setIsInviteModalOpen] = useState(false)
  const [isMemberModalOpen, setIsMemberModalOpen] = useState(false)
  const [isMemberLoading, setIsMemberLoading] = useState(false)
  const [isMemberEditMode, setIsMemberEditMode] = useState(false)
  const [selectedMember, setSelectedMember] = useState<TeamMemberDetail | null>(null)
  const [memberForm, setMemberForm] = useState<TeamMemberForm | null>(null)
  const [confirmationState, setConfirmationState] = useState<TeamMemberConfirmationState>(null)

  const queryClient = useQueryClient()
  const language = usePreferencesStore((state) => state.language)
  const currentUser = useAuthStore((state) => state.user)
  const t = (key: TranslationKey) => translate(language, key)

  const canManageMembers = Boolean(currentUser && manageableRoles.includes(currentUser.role))

  const editableRoleOptions = useMemo(() => {
    const base = [
      { value: 'clinic_master', label: t('team_role_clinic_master_title') },
      { value: 'surgeon', label: t('team_role_surgeon_title') },
      { value: 'secretary', label: t('team_role_secretary_title') },
      { value: 'nurse', label: t('team_role_nursing_title') },
    ]
    if (currentUser?.role === 'super_admin') {
      return [{ value: 'super_admin', label: t('role_super_admin') }, ...base]
    }
    return base
  }, [language, currentUser?.role])

  const inviteSchema = z.object({
    full_name: z.string().min(3, t('team_validation_full_name')),
    email: z.string().email(t('team_validation_email')),
    role: z.string().min(2, t('team_validation_role')),
    access_permissions: z.array(z.string()).default([]),
  })

  const { data: members = [] } = useQuery({
    queryKey: ['team-members'],
    queryFn: getTeamMembers,
  })

  const { data: logs = [] } = useQuery({
    queryKey: ['team-logs'],
    queryFn: getActivityLogs,
  })

  const {
    register,
    handleSubmit,
    setValue,
    control,
    reset,
    formState: { errors },
  } = useForm<InviteForm>({
    resolver: zodResolver(inviteSchema),
    defaultValues: {
      full_name: '',
      email: '',
      role: '',
      access_permissions: [],
    },
  })

  const selectedRole = useWatch({
    control,
    name: 'role',
  })

  const selectedPermissions = useWatch({
    control,
    name: 'access_permissions',
  }) || []

  const selectedRoleCode = roleCodeFromLabel(selectedRole || '')
  const isClinicMasterInvite = selectedRoleCode === 'clinic_master'

  useEffect(() => {
    if (!selectedRole) return
    setValue('access_permissions', getDefaultPermissionsByInviteRoleLabel(selectedRole), {
      shouldValidate: true,
      shouldDirty: true,
    })
  }, [selectedRole, setValue])

  const inviteMutation = useMutation({
    mutationFn: inviteUser,
    onSuccess: () => {
      toast.success(t('team_invite_sent_success'))
      void queryClient.invalidateQueries({ queryKey: ['team-members'] })
      setIsInviteModalOpen(false)
      reset()
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('team_invite_sent_error')))
    },
  })

  const updateMemberMutation = useMutation({
    mutationFn: ({
      memberId,
      payload,
    }: {
      memberId: string
      payload: {
        full_name?: string
        email?: string
        role?: string
        phone?: string
        cpf?: string
        date_of_birth?: string | null
        bio?: string
        crm_number?: string
        years_experience?: number | null
        is_visible_in_app?: boolean
        avatar_url?: string
        is_active?: boolean
      }
    }) => updateTeamMember(memberId, payload),
    onSuccess: (member) => {
      setSelectedMember(member)
      setMemberForm(buildMemberForm(member))
      setIsMemberEditMode(false)
      toast.success(t('team_member_updated_success'))
      void queryClient.invalidateQueries({ queryKey: ['team-members'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('team_member_update_error')))
    },
  })

  const toggleMemberMutation = useMutation({
    mutationFn: ({ memberId, active }: { memberId: string; active: boolean }) =>
      updateTeamMember(memberId, { is_active: active }),
    onSuccess: (member) => {
      setConfirmationState(null)
      setSelectedMember(member)
      setMemberForm(buildMemberForm(member))
      toast.success(t('team_member_toggle_success'))
      void queryClient.invalidateQueries({ queryKey: ['team-members'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('team_member_toggle_error')))
    },
  })

  const deleteMemberMutation = useMutation({
    mutationFn: (memberId: string) => deleteTeamMember(memberId),
    onSuccess: () => {
      setConfirmationState(null)
      toast.success(t('team_member_deleted_success'))
      setIsMemberModalOpen(false)
      setSelectedMember(null)
      setMemberForm(null)
      void queryClient.invalidateQueries({ queryKey: ['team-members'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('team_member_delete_error')))
    },
  })

  const onInviteSubmit = (values: InviteForm) => {
    inviteMutation.mutate({ ...values, language })
  }

  const toggleInvitePermission = (permission: AccessPermissionKey) => {
    if (isClinicMasterInvite) return
    if (selectedPermissions.includes(permission)) {
      setValue(
        'access_permissions',
        selectedPermissions.filter((item) => item !== permission),
        { shouldValidate: true, shouldDirty: true },
      )
      return
    }

    setValue('access_permissions', [...selectedPermissions, permission], {
      shouldValidate: true,
      shouldDirty: true,
    })
  }

  const closeMemberModal = () => {
    setIsMemberModalOpen(false)
    setIsMemberEditMode(false)
    setSelectedMember(null)
    setMemberForm(null)
    setIsMemberLoading(false)
    setConfirmationState(null)
  }

  const openMemberModal = async (memberId: string, editMode = false) => {
    setIsMemberModalOpen(true)
    setIsMemberEditMode(editMode)
    setIsMemberLoading(true)
    try {
      const member = await getTeamMemberById(memberId)
      setSelectedMember(member)
      setMemberForm(buildMemberForm(member))
    } catch (error) {
      toast.error(extractErrorMessage(error, t('team_member_load_error')))
      setSelectedMember(null)
      setMemberForm(null)
    } finally {
      setIsMemberLoading(false)
    }
  }

  const handleSaveMember = () => {
    if (!selectedMember || !memberForm) return

    const yearsValue = memberForm.years_experience.trim()
    const years = yearsValue ? Number(yearsValue) : null
    if (yearsValue && Number.isNaN(years)) {
      toast.error(t('team_member_update_error'))
      return
    }

    updateMemberMutation.mutate({
      memberId: selectedMember.id,
      payload: {
        full_name: memberForm.full_name.trim(),
        email: memberForm.email.trim(),
        role: memberForm.role,
        phone: memberForm.phone.trim(),
        cpf: memberForm.cpf.trim(),
        date_of_birth: memberForm.date_of_birth || null,
        bio: memberForm.bio.trim(),
        crm_number: memberForm.crm_number.trim(),
        years_experience: years,
        avatar_url: memberForm.avatar_url.trim(),
        is_visible_in_app: memberForm.is_visible_in_app,
      },
    })
  }

  const handleToggleMember = (memberId: string, currentStatus: 'active' | 'inactive', memberName: string) => {
    const nextActive = currentStatus !== 'active'
    setConfirmationState({
      action: 'toggle',
      memberId,
      memberName,
      nextActive,
    })
  }

  const handleDeleteMember = (memberId: string, memberName: string) => {
    setConfirmationState({
      action: 'delete',
      memberId,
      memberName,
    })
  }

  const isDeleteConfirmation = confirmationState?.action === 'delete'
  const confirmationTitle = isDeleteConfirmation
    ? t('team_member_delete')
    : confirmationState?.nextActive
      ? t('team_member_activate')
      : t('team_member_deactivate')
  const confirmationMessage = isDeleteConfirmation
    ? t('team_member_confirm_delete')
    : confirmationState?.nextActive
      ? t('team_member_confirm_activate')
      : t('team_member_confirm_deactivate')
  const confirmationHint = isDeleteConfirmation
    ? t('team_member_confirm_delete_hint')
    : t('team_member_confirm_toggle_hint')
  const confirmationButtonLabel = isDeleteConfirmation
    ? t('team_member_delete')
    : confirmationState?.nextActive
      ? t('team_member_activate')
      : t('team_member_deactivate')

  const isConfirmationPending = confirmationState?.action === 'toggle'
    ? toggleMemberMutation.isPending
    : confirmationState?.action === 'delete'
      ? deleteMemberMutation.isPending
      : false

  const runConfirmedAction = () => {
    if (!confirmationState) return

    if (confirmationState.action === 'toggle') {
      toggleMemberMutation.mutate({
        memberId: confirmationState.memberId,
        active: confirmationState.nextActive,
      })
      return
    }

    deleteMemberMutation.mutate(confirmationState.memberId)
  }

  const isSelfSelected = Boolean(selectedMember && currentUser && selectedMember.id === currentUser.id)

  return (
    <div className="space-y-5">
      <SectionHeader
        title={t('team_title')}
        subtitle={t('team_subtitle')}
        actions={canManageMembers ? (
          <Button onClick={() => setIsInviteModalOpen(true)}>
            <Plus className="h-4 w-4" />
            {t('team_invite_user')}
          </Button>
        ) : undefined}
      />

      <Card padded={false}>
        <div className="border-b border-slate-100 px-5 py-4">
          <h2 className="section-heading">{t('team_members')}</h2>
        </div>
        <div className="divide-y divide-slate-100">
          {members.map((member) => {
            const isSelf = Boolean(currentUser && member.id === currentUser.id)
            return (
              <div key={member.id} className="flex flex-wrap items-center justify-between gap-3 px-5 py-3">
                <div className="flex items-center gap-3">
                  <Avatar name={member.name} src={member.avatar} className="h-10 w-10" />
                  <div>
                    <p className="text-sm font-semibold text-night">{member.name}</p>
                    <p className="caption">{member.email}</p>
                  </div>
                </div>

                <div className="flex flex-wrap items-center gap-2">
                  <Badge className="bg-primary/10 text-primary">{roleLabelFromCode(member.role_code || member.role, t)}</Badge>
                  <Badge status={member.status} />
                  <Button size="sm" variant="secondary" onClick={() => void openMemberModal(member.id)}>
                    {t('team_view_details')}
                  </Button>
                  {canManageMembers ? (
                    <>
                      <Button size="sm" variant="secondary" onClick={() => void openMemberModal(member.id, true)}>
                        <Pencil className="h-3.5 w-3.5" />
                        {t('team_edit_member')}
                      </Button>
                      {!isSelf ? (
                        <>
                          <Button
                            size="sm"
                            variant="secondary"
                            onClick={() => handleToggleMember(member.id, member.status, member.name)}
                            disabled={toggleMemberMutation.isPending}
                          >
                            {member.status === 'active' ? <UserX className="h-3.5 w-3.5" /> : <UserCheck className="h-3.5 w-3.5" />}
                            {member.status === 'active' ? t('team_member_deactivate') : t('team_member_activate')}
                          </Button>
                          <Button
                            size="sm"
                            variant="danger"
                            onClick={() => handleDeleteMember(member.id, member.name)}
                            disabled={deleteMemberMutation.isPending}
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                            {t('team_member_delete')}
                          </Button>
                        </>
                      ) : null}
                    </>
                  ) : null}
                </div>
              </div>
            )
          })}
        </div>
      </Card>

      <Card padded={false}>
        <div className="border-b border-slate-100 px-5 py-4">
          <h2 className="section-heading">{t('team_recent_activity')}</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">{t('team_log_datetime')}</th>
                <th className="px-4 py-3 text-left overline">{t('team_log_user')}</th>
                <th className="px-4 py-3 text-left overline">{t('team_log_action')}</th>
                <th className="px-4 py-3 text-left overline">{t('team_log_ip')}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {logs.map((log) => (
                <tr key={log.id}>
                  <td className="px-4 py-3 text-sm text-slate-600">{log.created_at}</td>
                  <td className="px-4 py-3 text-sm font-medium text-night">{log.user}</td>
                  <td className="px-4 py-3 text-sm text-slate-600">{log.action}</td>
                  <td className="px-4 py-3 text-sm text-slate-600">{log.ip}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <Modal
        isOpen={isInviteModalOpen}
        onClose={() => setIsInviteModalOpen(false)}
        title={t('team_invite_new_user')}
        className="max-w-3xl"
      >
        <form className="space-y-4" onSubmit={handleSubmit(onInviteSubmit)}>
          <div className="grid gap-3 md:grid-cols-2">
            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">{t('team_full_name')}</label>
              <Input {...register('full_name')} placeholder={t('team_enter_name')} />
              {errors.full_name ? <p className="caption mt-1 text-danger">{errors.full_name.message}</p> : null}
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">{t('team_corporate_email')}</label>
              <Input {...register('email')} placeholder={t('team_email_placeholder')} />
              {errors.email ? <p className="caption mt-1 text-danger">{errors.email.message}</p> : null}
            </div>
          </div>

          <div>
            <p className="mb-2 text-xs font-medium text-slate-600">{t('team_access_profile')}</p>
            <div className="grid gap-2 md:grid-cols-2">
              {roleOptions.map((role) => (
                <button
                  key={role.id}
                  type="button"
                  onClick={() => setValue('role', role.id, { shouldValidate: true })}
                  className={`rounded-xl border p-3 text-left transition ${
                    selectedRole === role.id
                      ? 'border-primary bg-primary/5 shadow-[0_0_0_2px_rgba(13,92,115,0.12)]'
                      : 'border-slate-200 hover:border-slate-300'
                  }`}
                >
                  <p className="text-sm font-semibold text-night">{t(role.titleKey)}</p>
                  <p className="caption mt-1">{t(role.descriptionKey)}</p>
                </button>
              ))}
            </div>
            {errors.role ? <p className="caption mt-1 text-danger">{errors.role.message}</p> : null}
          </div>

          {selectedRole ? (
            <div>
              <p className="mb-2 text-xs font-medium text-slate-600">{t('team_panel_features')}</p>
              <div className="rounded-xl border border-slate-200 bg-slate-50 p-3">
                <div className="grid gap-2 sm:grid-cols-2">
                  {ACCESS_PERMISSION_DEFINITIONS.map((permission) => {
                    const checked = selectedPermissions.includes(permission.key)
                    return (
                      <label
                        key={permission.key}
                        className={`flex items-start gap-2 rounded-lg border p-2 text-left ${
                          checked ? 'border-primary/30 bg-primary/5' : 'border-slate-200 bg-white'
                        } ${isClinicMasterInvite ? 'cursor-not-allowed opacity-80' : 'cursor-pointer'}`}
                      >
                        <input
                          type="checkbox"
                          className="mt-1 h-4 w-4 accent-primary"
                          checked={checked}
                          disabled={isClinicMasterInvite}
                          onChange={() => toggleInvitePermission(permission.key)}
                        />
                        <span>
                          <span className="block text-sm font-semibold text-night">{t(permission.labelKey)}</span>
                          <span className="caption">{t(permission.descriptionKey)}</span>
                        </span>
                      </label>
                    )
                  })}
                </div>
                {isClinicMasterInvite ? (
                  <p className="caption mt-2">
                    {t('team_clinic_master_auto_access')}
                  </p>
                ) : (
                  <p className="caption mt-2">
                    {t('team_role_permissions_hint')}
                  </p>
                )}
              </div>
            </div>
          ) : null}

          <div className="flex justify-end gap-2">
            <Button type="button" variant="secondary" onClick={() => setIsInviteModalOpen(false)}>
              {t('team_cancel')}
            </Button>
            <Button type="submit" disabled={inviteMutation.isPending}>
              {inviteMutation.isPending ? t('team_sending') : t('team_send_invite')}
            </Button>
          </div>
        </form>
      </Modal>

      <Modal
        isOpen={isMemberModalOpen}
        onClose={closeMemberModal}
        title={t('team_member_details_title')}
        className="max-w-4xl"
      >
        {isMemberLoading ? (
          <p className="text-sm text-slate-500">{t('team_member_loading')}</p>
        ) : !selectedMember || !memberForm ? (
          <p className="text-sm text-danger">{t('team_member_load_error')}</p>
        ) : isMemberEditMode ? (
          <div className="space-y-3">
            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">{t('team_full_name')}</label>
                <Input
                  value={memberForm.full_name}
                  onChange={(event) =>
                    setMemberForm((prev) => (prev ? { ...prev, full_name: event.target.value } : prev))
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">{t('team_corporate_email')}</label>
                <Input
                  value={memberForm.email}
                  onChange={(event) =>
                    setMemberForm((prev) => (prev ? { ...prev, email: event.target.value } : prev))
                  }
                />
              </div>
            </div>

            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">{t('team_access_profile')}</label>
                <select
                  className="h-10 w-full rounded-lg border border-slate-200 bg-white px-3 text-sm text-night"
                  value={memberForm.role}
                  onChange={(event) =>
                    setMemberForm((prev) => (prev ? { ...prev, role: event.target.value } : prev))
                  }
                >
                  {editableRoleOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">{t('team_member_phone')}</label>
                <Input
                  value={memberForm.phone}
                  onChange={(event) =>
                    setMemberForm((prev) => (prev ? { ...prev, phone: event.target.value } : prev))
                  }
                />
              </div>
            </div>

            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">{t('team_member_tax_number')}</label>
                <Input
                  value={memberForm.cpf}
                  onChange={(event) =>
                    setMemberForm((prev) => (prev ? { ...prev, cpf: event.target.value } : prev))
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">{t('team_member_date_of_birth')}</label>
                <Input
                  type="date"
                  value={memberForm.date_of_birth}
                  onChange={(event) =>
                    setMemberForm((prev) => (prev ? { ...prev, date_of_birth: event.target.value } : prev))
                  }
                />
              </div>
            </div>

            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">{t('team_member_crm_number')}</label>
                <Input
                  value={memberForm.crm_number}
                  onChange={(event) =>
                    setMemberForm((prev) => (prev ? { ...prev, crm_number: event.target.value } : prev))
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">{t('team_member_years_experience')}</label>
                <Input
                  type="number"
                  min={0}
                  value={memberForm.years_experience}
                  onChange={(event) =>
                    setMemberForm((prev) =>
                      prev ? { ...prev, years_experience: event.target.value } : prev,
                    )
                  }
                />
              </div>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">{t('team_member_avatar_url')}</label>
              <Input
                value={memberForm.avatar_url}
                onChange={(event) =>
                  setMemberForm((prev) => (prev ? { ...prev, avatar_url: event.target.value } : prev))
                }
              />
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">{t('team_member_bio')}</label>
              <TextArea
                rows={3}
                value={memberForm.bio}
                onChange={(event) =>
                  setMemberForm((prev) => (prev ? { ...prev, bio: event.target.value } : prev))
                }
              />
            </div>

            <label className="inline-flex items-center gap-2 text-sm text-slate-700">
              <input
                type="checkbox"
                checked={memberForm.is_visible_in_app}
                onChange={(event) =>
                  setMemberForm((prev) =>
                    prev ? { ...prev, is_visible_in_app: event.target.checked } : prev,
                  )
                }
              />
              {t('team_member_visible_in_app')}
            </label>

            <div className="flex justify-end gap-2">
              <Button
                variant="secondary"
                onClick={() => {
                  setIsMemberEditMode(false)
                  setMemberForm(buildMemberForm(selectedMember))
                }}
              >
                {t('team_cancel')}
              </Button>
              <Button onClick={handleSaveMember} disabled={updateMemberMutation.isPending}>
                {updateMemberMutation.isPending ? t('team_sending') : t('team_member_save_changes')}
              </Button>
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="grid gap-3 md:grid-cols-2">
              <div className="rounded-lg border border-slate-100 p-3">
                <p className="overline">{t('team_full_name')}</p>
                <p className="text-sm font-semibold text-night">{selectedMember.name}</p>
              </div>
              <div className="rounded-lg border border-slate-100 p-3">
                <p className="overline">{t('team_corporate_email')}</p>
                <p className="text-sm font-semibold text-night">{selectedMember.email}</p>
              </div>
              <div className="rounded-lg border border-slate-100 p-3">
                <p className="overline">{t('team_access_profile')}</p>
                <p className="text-sm font-semibold text-night">
                  {roleLabelFromCode(selectedMember.role_code || selectedMember.role, t)}
                </p>
              </div>
              <div className="rounded-lg border border-slate-100 p-3">
                <p className="overline">{t('team_member_status')}</p>
                <Badge status={selectedMember.status} />
              </div>
              <div className="rounded-lg border border-slate-100 p-3">
                <p className="overline">{t('team_member_phone')}</p>
                <p className="text-sm font-semibold text-night">{selectedMember.phone || t('team_member_not_informed')}</p>
              </div>
              <div className="rounded-lg border border-slate-100 p-3">
                <p className="overline">{t('team_member_tax_number')}</p>
                <p className="text-sm font-semibold text-night">{selectedMember.cpf || t('team_member_not_informed')}</p>
              </div>
              <div className="rounded-lg border border-slate-100 p-3">
                <p className="overline">{t('team_member_date_of_birth')}</p>
                <p className="text-sm font-semibold text-night">
                  {selectedMember.date_of_birth ? formatDate(selectedMember.date_of_birth) : t('team_member_not_informed')}
                </p>
              </div>
              <div className="rounded-lg border border-slate-100 p-3">
                <p className="overline">{t('team_member_date_joined')}</p>
                <p className="text-sm font-semibold text-night">
                  {selectedMember.date_joined ? formatDate(selectedMember.date_joined) : t('team_member_not_informed')}
                </p>
              </div>
              <div className="rounded-lg border border-slate-100 p-3">
                <p className="overline">{t('team_member_crm_number')}</p>
                <p className="text-sm font-semibold text-night">{selectedMember.crm_number || t('team_member_not_informed')}</p>
              </div>
              <div className="rounded-lg border border-slate-100 p-3">
                <p className="overline">{t('team_member_years_experience')}</p>
                <p className="text-sm font-semibold text-night">
                  {selectedMember.years_experience ?? t('team_member_not_informed')}
                </p>
              </div>
              <div className="rounded-lg border border-slate-100 p-3 md:col-span-2">
                <p className="overline">{t('team_member_avatar_url')}</p>
                <p className="text-sm font-semibold text-night break-all">
                  {selectedMember.avatar_url || t('team_member_not_informed')}
                </p>
              </div>
              <div className="rounded-lg border border-slate-100 p-3 md:col-span-2">
                <p className="overline">{t('team_member_bio')}</p>
                <p className="text-sm font-semibold text-night">{selectedMember.bio || t('team_member_not_informed')}</p>
              </div>
            </div>

            <div className="flex flex-wrap justify-end gap-2">
              {canManageMembers ? (
                <>
                  <Button variant="secondary" onClick={() => setIsMemberEditMode(true)}>
                    <Pencil className="h-4 w-4" />
                    {t('team_edit_member')}
                  </Button>
                  {!isSelfSelected ? (
                    <>
                      <Button
                        variant="secondary"
                        onClick={() => handleToggleMember(selectedMember.id, selectedMember.status, selectedMember.name)}
                        disabled={toggleMemberMutation.isPending}
                      >
                        {selectedMember.status === 'active' ? <UserX className="h-4 w-4" /> : <UserCheck className="h-4 w-4" />}
                        {selectedMember.status === 'active' ? t('team_member_deactivate') : t('team_member_activate')}
                      </Button>
                      <Button
                        variant="danger"
                        onClick={() => handleDeleteMember(selectedMember.id, selectedMember.name)}
                        disabled={deleteMemberMutation.isPending}
                      >
                        <Trash2 className="h-4 w-4" />
                        {t('team_member_delete')}
                      </Button>
                    </>
                  ) : null}
                </>
              ) : null}
              <Button variant="secondary" onClick={closeMemberModal}>
                {t('team_cancel')}
              </Button>
            </div>
          </div>
        )}
      </Modal>

      <Modal
        isOpen={Boolean(confirmationState)}
        onClose={() => {
          if (!isConfirmationPending) {
            setConfirmationState(null)
          }
        }}
        title={confirmationTitle}
        className="max-w-lg"
      >
        {confirmationState ? (
          <div className="space-y-5">
            <div
              className={`rounded-2xl border p-4 ${
                isDeleteConfirmation ? 'border-danger/20 bg-danger/5' : 'border-primary/20 bg-primary/5'
              }`}
            >
              <div className="flex items-start gap-3">
                <span
                  className={`inline-flex h-10 w-10 items-center justify-center rounded-full ${
                    isDeleteConfirmation ? 'bg-danger/10 text-danger' : 'bg-primary/10 text-primary'
                  }`}
                >
                  <AlertTriangle className="h-5 w-5" />
                </span>
                <div>
                  <p className="text-sm font-semibold text-night">{confirmationState.memberName}</p>
                  <p className="mt-1 text-sm text-slate-700">{confirmationMessage}</p>
                  <p className="mt-2 text-xs text-slate-500">{confirmationHint}</p>
                </div>
              </div>
            </div>

            <div className="flex justify-end gap-2">
              <Button
                variant="secondary"
                onClick={() => setConfirmationState(null)}
                disabled={isConfirmationPending}
              >
                {t('team_cancel')}
              </Button>
              <Button
                variant={isDeleteConfirmation ? 'danger' : 'primary'}
                onClick={runConfirmedAction}
                disabled={isConfirmationPending}
              >
                {isConfirmationPending ? t('team_sending') : confirmationButtonLabel}
              </Button>
            </div>
          </div>
        ) : null}
      </Modal>
    </div>
  )
}
