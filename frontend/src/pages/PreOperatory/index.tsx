import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { Eye, RefreshCw } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import toast from 'react-hot-toast'

import {
  listTenantPreOperatory,
  type PreOperatoryAdminUpdatePayload,
  type PreOperatoryStatus,
  updatePreOperatoryById,
} from '@/api/preOperatory'
import { getDoctors } from '@/api/patients'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { PreOperatoryModal } from '@/components/patients/PreOperatoryModal'
import { preOperatoryStatusLabel } from '@/components/patients/preOperatoryStatus'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Select } from '@/components/ui/Select'
import { TextArea } from '@/components/ui/TextArea'
import { t as translate, type TranslationKey } from '@/i18n/system'
import { useAuthStore } from '@/stores/authStore'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { formatDate } from '@/utils/format'

type StatusFilter = 'active' | PreOperatoryStatus

type ActionKind =
  | 'in_review'
  | 'approve'
  | 'reject'
  | 'assign'
  | 'approve_assign'

function statusBadgeClass(status: PreOperatoryStatus) {
  if (status === 'approved') return 'bg-success/15 text-success'
  if (status === 'rejected') return 'bg-danger/15 text-danger'
  if (status === 'in_review') return 'bg-amber-100 text-amber-700'
  return 'bg-slate-200 text-slate-600'
}

function extractApiErrorMessage(error: unknown, fallback: string) {
  if (!isAxiosError(error)) return fallback
  const responseData = error.response?.data as
    | {
        detail?: string
        non_field_errors?: string[]
        status?: string[]
        assigned_doctor?: string[]
      }
    | undefined

  if (responseData?.detail) return responseData.detail
  if (Array.isArray(responseData?.non_field_errors) && responseData.non_field_errors[0]) {
    return responseData.non_field_errors[0]
  }
  if (Array.isArray(responseData?.status) && responseData.status[0]) {
    return responseData.status[0]
  }
  if (Array.isArray(responseData?.assigned_doctor) && responseData.assigned_doctor[0]) {
    return responseData.assigned_doctor[0]
  }
  return fallback
}

export default function PreOperatoryPage() {
  const queryClient = useQueryClient()
  const currentUser = useAuthStore((state) => state.user)
  const language = usePreferencesStore((state) => state.language)
  const t = (key: TranslationKey) => translate(language, key)
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('active')
  const [selectedRecordId, setSelectedRecordId] = useState<string | null>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [notes, setNotes] = useState('')
  const [selectedDoctorId, setSelectedDoctorId] = useState('')
  const [pendingAction, setPendingAction] = useState<ActionKind | null>(null)
  const isClinicMaster = currentUser?.role === 'clinic_master'
  const isSurgeon = currentUser?.role === 'surgeon'
  const canReviewPreOperatory = isClinicMaster || isSurgeon

  const listQuery = useQuery({
    queryKey: ['pre-operatory-admin-list', statusFilter],
    queryFn: () =>
      listTenantPreOperatory(
        statusFilter === 'active' ? undefined : statusFilter,
      ),
    refetchInterval: 10000,
    refetchOnMount: 'always',
  })

  const doctorsQuery = useQuery({
    queryKey: ['pre-operatory-admin-doctors'],
    queryFn: getDoctors,
    enabled: isModalOpen && isClinicMaster,
  })

  const selectedRecord = useMemo(
    () =>
      (listQuery.data || []).find((item) => item.id === selectedRecordId) ||
      null,
    [listQuery.data, selectedRecordId],
  )
  useEffect(() => {
    if (!isModalOpen || !selectedRecord) return
    setNotes(selectedRecord.notes || '')
    setSelectedDoctorId(selectedRecord.assigned_doctor || '')
  }, [isModalOpen, selectedRecord?.id])

  const updateMutation = useMutation({
    mutationFn: ({
      preOperatoryId,
      payload,
    }: {
      preOperatoryId: string
      payload: PreOperatoryAdminUpdatePayload
    }) => updatePreOperatoryById(preOperatoryId, payload),
  })

  const closeModal = () => {
    setIsModalOpen(false)
    setSelectedRecordId(null)
    setNotes('')
    setSelectedDoctorId('')
    setPendingAction(null)
  }

  const executeAction = async (
    action: ActionKind,
    payload: PreOperatoryAdminUpdatePayload,
  ) => {
    if (!selectedRecord) return

    setPendingAction(action)
    try {
      await updateMutation.mutateAsync({
        preOperatoryId: selectedRecord.id,
        payload,
      })
      await queryClient.invalidateQueries({
        queryKey: ['pre-operatory-admin-list'],
      })
      toast.success(t('preop_update_success'))
      closeModal()
    } catch (error) {
      toast.error(
        extractApiErrorMessage(
          error,
          t('preop_update_error'),
        ),
      )
    } finally {
      setPendingAction(null)
    }
  }

  const requireDoctor = () => {
    if (selectedDoctorId) return true
    toast.error(t('preop_select_doctor_error'))
    return false
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title={t('preop_title')}
        subtitle={t('preop_subtitle')}
        actions={
          <Button
            type="button"
            variant="secondary"
            onClick={() => void listQuery.refetch()}
            disabled={listQuery.isLoading || listQuery.isFetching}
            >
              <RefreshCw
                className={`h-4 w-4 ${
                  listQuery.isLoading || listQuery.isFetching ? 'animate-spin' : ''
                }`}
              />
            {t('preop_refresh')}
          </Button>
        }
      />

      <Card>
        <div className="grid gap-3 md:grid-cols-[220px_1fr]">
          <Select
            value={statusFilter}
            onChange={(event) => setStatusFilter(event.target.value as StatusFilter)}
          >
            <option value="active">{t('preop_filter_active')}</option>
            <option value="pending">{t('preop_status_pending')}</option>
            <option value="in_review">{t('preop_status_in_review')}</option>
            <option value="approved">{t('preop_status_approved')}</option>
            <option value="rejected">{t('preop_status_rejected')}</option>
          </Select>
          <div className="flex items-center text-sm text-slate-500">
            {(listQuery.data || []).length} {t('preop_found_suffix')}
          </div>
        </div>
      </Card>

      <Card padded={false} className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">{t('preop_col_patient')}</th>
                <th className="px-4 py-3 text-left overline">{t('preop_col_status')}</th>
                <th className="px-4 py-3 text-left overline">{t('preop_col_sent_at')}</th>
                <th className="px-4 py-3 text-right overline">{t('preop_col_action')}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {listQuery.isLoading ? (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-sm text-slate-500">
                    {t('preop_loading_list')}
                  </td>
                </tr>
              ) : listQuery.isError ? (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-sm text-slate-500">
                    {t('preop_load_error')}
                  </td>
                </tr>
              ) : (listQuery.data || []).length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-sm text-slate-500">
                    {t('preop_empty')}
                  </td>
                </tr>
              ) : (
                (listQuery.data || []).map((item) => (
                  <tr key={item.id} className="hover:bg-tealIce/50">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <Avatar
                          name={item.patient_name || t('preop_patient_fallback')}
                          src={item.patient_avatar_url || undefined}
                          className="h-8 w-8"
                        />
                        <span className="text-sm font-semibold text-night">
                          {item.patient_name || t('preop_patient_fallback')}
                        </span>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <Badge className={statusBadgeClass(item.status)}>
                        {preOperatoryStatusLabel(item.status, t)}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-600">
                      {formatDate(item.created_at)}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Button
                        type="button"
                        size="sm"
                        variant="secondary"
                        onClick={() => {
                          setSelectedRecordId(item.id)
                          setIsModalOpen(true)
                        }}
                      >
                        <Eye className="h-4 w-4" />
                        {t('preop_view')}
                      </Button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </Card>

      <PreOperatoryModal
        isOpen={isModalOpen}
        onClose={closeModal}
        record={selectedRecord}
        isLoading={Boolean(isModalOpen && listQuery.isLoading && !selectedRecord)}
        isError={Boolean(isModalOpen && listQuery.isError)}
        title={
          selectedRecord?.patient_name
            ? `${t('preop_modal_title')} • ${selectedRecord.patient_name}`
            : t('preop_modal_title')
        }
        actionArea={canReviewPreOperatory ? (
          <div className="space-y-4">
            <div>
              <p className="mb-2 text-sm font-semibold text-night">{t('preop_clinic_observations')}</p>
              <TextArea
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
                placeholder={t('preop_clinic_notes_placeholder')}
                rows={4}
              />
            </div>

            {isClinicMaster ? (
              <div>
                <p className="mb-2 text-sm font-semibold text-night">{t('preop_assign_doctor')}</p>
                <Select
                  value={selectedDoctorId}
                  onChange={(event) => setSelectedDoctorId(event.target.value)}
                  disabled={doctorsQuery.isLoading}
                >
                  <option value="">{t('preop_select_doctor')}</option>
                  {(doctorsQuery.data || []).map((doctor) => (
                    <option key={doctor.id} value={doctor.id}>
                      {doctor.name}
                    </option>
                  ))}
                </Select>
              </div>
            ) : null}

            <div className="grid gap-2 md:grid-cols-2">
              {isClinicMaster ? (
                <Button
                  type="button"
                  variant="secondary"
                  disabled={Boolean(pendingAction)}
                  onClick={() => {
                    if (!requireDoctor()) return
                    void executeAction('in_review', {
                      status: 'in_review',
                      notes,
                      assigned_doctor: selectedDoctorId,
                    })
                  }}
                >
                  {pendingAction === 'in_review' ? t('preop_saving') : t('preop_mark_in_review')}
                </Button>
              ) : null}

              <Button
                type="button"
                disabled={Boolean(pendingAction)}
                onClick={() =>
                  void executeAction('approve', {
                    status: 'approved',
                    notes,
                  })
                }
              >
                {pendingAction === 'approve' ? t('preop_saving') : t('preop_approve')}
              </Button>

              <Button
                type="button"
                variant="danger"
                disabled={Boolean(pendingAction)}
                onClick={() =>
                  void executeAction('reject', {
                    status: 'rejected',
                    notes,
                  })
                }
              >
                {pendingAction === 'reject' ? t('preop_saving') : t('preop_reject')}
              </Button>

              {isClinicMaster ? (
                <>
                  <Button
                    type="button"
                    variant="secondary"
                    disabled={Boolean(pendingAction)}
                    onClick={() => {
                      if (!requireDoctor()) return
                      void executeAction('assign', {
                        notes,
                        assigned_doctor: selectedDoctorId,
                      })
                    }}
                  >
                    {pendingAction === 'assign' ? t('preop_saving') : t('preop_assign')}
                  </Button>

                  <Button
                    type="button"
                    className="md:col-span-2"
                    disabled={Boolean(pendingAction)}
                    onClick={() => {
                      if (!requireDoctor()) return
                      void executeAction('approve_assign', {
                        status: 'approved',
                        notes,
                        assigned_doctor: selectedDoctorId,
                      })
                    }}
                  >
                    {pendingAction === 'approve_assign'
                      ? t('preop_saving')
                      : t('preop_approve_assign')}
                  </Button>
                </>
              ) : null}
            </div>
          </div>
        ) : null}
      />
    </div>
  )
}
