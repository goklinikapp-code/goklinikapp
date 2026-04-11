import { useMutation, useQuery } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { Eye, EyeOff, Upload } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import toast from 'react-hot-toast'

import {
  changeCurrentUserPassword,
  getCurrentUser,
  uploadCurrentUserAvatar,
} from '@/api/auth'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Avatar } from '@/components/ui/Avatar'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { t as translate, type TranslationKey } from '@/i18n/system'
import { useAuthStore } from '@/stores/authStore'
import { usePreferencesStore } from '@/stores/preferencesStore'

function extractApiErrorMessage(error: unknown, fallback: string): string {
  if (!isAxiosError(error)) return fallback
  const payload = error.response?.data as Record<string, unknown> | undefined
  if (!payload) return fallback
  const detail = payload.detail
  if (typeof detail === 'string' && detail.trim()) return detail
  const firstValue = Object.values(payload)[0]
  if (Array.isArray(firstValue) && typeof firstValue[0] === 'string') {
    return firstValue[0]
  }
  if (typeof firstValue === 'string' && firstValue.trim()) {
    return firstValue
  }
  return fallback
}

export default function ProfileSettingsPage() {
  const language = usePreferencesStore((state) => state.language)
  const t = (key: TranslationKey) => translate(language, key)
  const user = useAuthStore((state) => state.user)
  const setUser = useAuthStore((state) => state.setUser)

  const [selectedAvatarFile, setSelectedAvatarFile] = useState<File | null>(null)
  const [avatarPreviewUrl, setAvatarPreviewUrl] = useState<string | null>(null)
  const [currentPassword, setCurrentPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showCurrentPassword, setShowCurrentPassword] = useState(false)
  const [showNewPassword, setShowNewPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)

  const { data: currentUser } = useQuery({
    queryKey: ['current-user-profile', user?.id],
    queryFn: getCurrentUser,
    enabled: Boolean(user?.id),
    staleTime: 60_000,
  })

  useEffect(() => {
    if (!currentUser) return
    setUser(currentUser)
  }, [currentUser, setUser])

  useEffect(() => {
    if (!selectedAvatarFile) {
      setAvatarPreviewUrl(null)
      return
    }

    const objectUrl = URL.createObjectURL(selectedAvatarFile)
    setAvatarPreviewUrl(objectUrl)
    return () => {
      URL.revokeObjectURL(objectUrl)
    }
  }, [selectedAvatarFile])

  const avatarMutation = useMutation({
    mutationFn: uploadCurrentUserAvatar,
    onSuccess: (updatedUser) => {
      setUser(updatedUser)
      setSelectedAvatarFile(null)
      toast.success(t('profile_settings_avatar_success'))
    },
    onError: (error) => {
      toast.error(extractApiErrorMessage(error, t('profile_settings_avatar_error')))
    },
  })

  const passwordMutation = useMutation({
    mutationFn: changeCurrentUserPassword,
    onSuccess: (payload) => {
      setCurrentPassword('')
      setNewPassword('')
      setConfirmPassword('')
      toast.success(payload.detail || t('profile_settings_password_success'))
    },
    onError: (error) => {
      toast.error(extractApiErrorMessage(error, t('profile_settings_password_error')))
    },
  })

  const resolvedAvatarUrl = useMemo(
    () => avatarPreviewUrl || user?.avatar_url || undefined,
    [avatarPreviewUrl, user?.avatar_url],
  )

  const handleAvatarUpload = () => {
    if (!selectedAvatarFile) {
      toast.error(t('profile_settings_avatar_select_file'))
      return
    }
    avatarMutation.mutate(selectedAvatarFile)
  }

  const handlePasswordChange = () => {
    if (!currentPassword || !newPassword || !confirmPassword) {
      toast.error(t('profile_settings_password_required'))
      return
    }
    if (newPassword.length < 8) {
      toast.error(t('profile_settings_password_min_length'))
      return
    }
    if (newPassword !== confirmPassword) {
      toast.error(t('profile_settings_password_mismatch'))
      return
    }

    passwordMutation.mutate({
      current_password: currentPassword,
      new_password: newPassword,
    })
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title={t('profile_settings_title')}
        subtitle={t('profile_settings_subtitle')}
      />

      <div className="grid gap-4 xl:grid-cols-2">
        <Card>
          <h2 className="section-heading mb-1">{t('profile_settings_avatar_card_title')}</h2>
          <p className="caption mb-4">{t('profile_settings_avatar_card_hint')}</p>

          <div className="mb-4 flex items-center gap-3">
            <Avatar
              name={user?.full_name || 'Perfil'}
              src={resolvedAvatarUrl}
              className="h-16 w-16 text-sm"
            />
            <div className="text-sm text-slate-600">
              <p className="font-semibold text-night">{user?.full_name || '-'}</p>
              <p>{user?.email || '-'}</p>
            </div>
          </div>

          <label className="mb-1 block text-xs font-semibold text-slate-600">
            {t('profile_settings_avatar_select_label')}
          </label>
          <Input
            type="file"
            accept="image/*"
            onChange={(event) => {
              const file = event.target.files?.[0] || null
              setSelectedAvatarFile(file)
            }}
          />

          <div className="mt-3 flex justify-end">
            <Button onClick={handleAvatarUpload} disabled={avatarMutation.isPending}>
              <Upload className="h-4 w-4" />
              {avatarMutation.isPending ? t('profile_settings_saving') : t('profile_settings_avatar_save')}
            </Button>
          </div>
        </Card>

        <Card>
          <h2 className="section-heading mb-1">{t('profile_settings_password_card_title')}</h2>
          <p className="caption mb-4">{t('profile_settings_password_card_hint')}</p>

          <div className="space-y-3">
            <div>
              <label className="mb-1 block text-xs font-semibold text-slate-600">
                {t('profile_settings_current_password')}
              </label>
              <div className="flex items-center gap-2">
                <Input
                  type={showCurrentPassword ? 'text' : 'password'}
                  value={currentPassword}
                  onChange={(event) => setCurrentPassword(event.target.value)}
                />
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => setShowCurrentPassword((value) => !value)}
                  aria-label={showCurrentPassword ? 'Ocultar senha atual' : 'Mostrar senha atual'}
                >
                  {showCurrentPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </Button>
              </div>
            </div>

            <div>
              <label className="mb-1 block text-xs font-semibold text-slate-600">
                {t('profile_settings_new_password')}
              </label>
              <div className="flex items-center gap-2">
                <Input
                  type={showNewPassword ? 'text' : 'password'}
                  value={newPassword}
                  onChange={(event) => setNewPassword(event.target.value)}
                />
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => setShowNewPassword((value) => !value)}
                  aria-label={showNewPassword ? 'Ocultar nova senha' : 'Mostrar nova senha'}
                >
                  {showNewPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </Button>
              </div>
            </div>

            <div>
              <label className="mb-1 block text-xs font-semibold text-slate-600">
                {t('profile_settings_confirm_password')}
              </label>
              <div className="flex items-center gap-2">
                <Input
                  type={showConfirmPassword ? 'text' : 'password'}
                  value={confirmPassword}
                  onChange={(event) => setConfirmPassword(event.target.value)}
                />
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => setShowConfirmPassword((value) => !value)}
                  aria-label={showConfirmPassword ? 'Ocultar confirmação de senha' : 'Mostrar confirmação de senha'}
                >
                  {showConfirmPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </Button>
              </div>
            </div>
          </div>

          <div className="mt-4 flex justify-end">
            <Button onClick={handlePasswordChange} disabled={passwordMutation.isPending}>
              {passwordMutation.isPending ? t('profile_settings_saving') : t('profile_settings_password_save')}
            </Button>
          </div>
        </Card>
      </div>
    </div>
  )
}
