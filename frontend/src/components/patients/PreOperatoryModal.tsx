import type { ReactNode } from 'react'

import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import { t as translate, type TranslationKey } from '@/i18n/system'
import { usePreferencesStore } from '@/stores/preferencesStore'
import type { PreOperatoryRecord } from '@/types'
import { resolveMediaUrl } from '@/utils/mediaUrl'
import { preOperatoryStatusLabel } from '@/components/patients/preOperatoryStatus'

function preOperatoryStatusBadgeClass(status?: PreOperatoryRecord['status']) {
  if (status === 'approved') return 'bg-success/15 text-success'
  if (status === 'rejected') return 'bg-danger/15 text-danger'
  if (status === 'in_review') return 'bg-amber-100 text-amber-700'
  return 'bg-slate-200 text-slate-600'
}

interface PreOperatoryModalProps {
  isOpen: boolean
  onClose: () => void
  title?: string
  className?: string
  record?: PreOperatoryRecord | null
  isLoading?: boolean
  isError?: boolean
  loadingMessage?: string
  errorMessage?: string
  emptyMessage?: string
  allowPhotoDelete?: boolean
  deletingPhotoId?: string | null
  onDeletePhoto?: (photoId: string) => void
  actionArea?: ReactNode
}

function formatApprovalDate(value?: string | null): string {
  if (!value) return 'Não informado'
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) return 'Não informado'
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(parsed)
}

export function PreOperatoryModal({
  isOpen,
  onClose,
  title,
  className = 'max-w-5xl',
  record,
  isLoading = false,
  isError = false,
  loadingMessage,
  errorMessage,
  emptyMessage,
  allowPhotoDelete = false,
  deletingPhotoId,
  onDeletePhoto,
  actionArea,
}: PreOperatoryModalProps) {
  const language = usePreferencesStore((state) => state.language)
  const t = (key: TranslationKey) => translate(language, key)
  const statusText = preOperatoryStatusLabel(record?.status, t)
  const resolvedTitle = title || t('preop_modal_title')
  const resolvedLoadingMessage = loadingMessage || t('preop_modal_loading')
  const resolvedErrorMessage = errorMessage || t('preop_modal_error')
  const resolvedEmptyMessage = emptyMessage || t('preop_modal_empty')
  const approvedByDisplayName =
    record?.approved_by_name?.trim()
    || record?.current_doctor_name?.trim()
    || record?.assigned_doctor_name?.trim()
    || ''
  const currentDoctorDisplayName =
    record?.current_doctor_name?.trim()
    || record?.assigned_doctor_name?.trim()
    || ''

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={resolvedTitle}
      className={className}
    >
      {isLoading ? (
        <p className="text-sm text-slate-500">{resolvedLoadingMessage}</p>
      ) : isError ? (
        <p className="text-sm text-slate-500">{resolvedErrorMessage}</p>
      ) : !record ? (
        <p className="text-sm text-slate-500">{resolvedEmptyMessage}</p>
      ) : (
        <div className="space-y-4">
          <div className="flex items-center justify-between rounded-card border border-slate-200 bg-slate-50 p-3">
            <p className="text-sm font-semibold text-night">{t('preop_modal_screening_status')}</p>
            <Badge className={preOperatoryStatusBadgeClass(record.status)}>{statusText}</Badge>
          </div>

          {record.status === 'approved' ? (
            <div className="space-y-2 rounded-card border border-emerald-200 bg-emerald-50 p-3">
              <p className="text-xs font-semibold uppercase tracking-wide text-emerald-700">
                Histórico de aprovação
              </p>
              <p className="text-sm text-slate-700">
                <span className="font-semibold">Médico que aprovou:</span>{' '}
                {approvedByDisplayName ? `Dr. ${approvedByDisplayName}` : 'Não informado'}
              </p>
              <p className="text-sm text-slate-700">
                <span className="font-semibold">Data da aprovação:</span>{' '}
                {formatApprovalDate(record.approved_at)}
              </p>
              {record.approved_by_different_doctor ? (
                <p className="rounded-lg border border-sky-200 bg-sky-50 px-3 py-2 text-xs text-sky-700">
                  Pré-operatório aprovado pelo Dr. {approvedByDisplayName || 'Não informado'}. Médico atual:
                  {' '}Dr. {currentDoctorDisplayName || 'Não informado'}.
                </p>
              ) : null}
            </div>
          ) : null}

          <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
            <p className="overline">{t('preop_field_procedure')}</p>
            <p className="text-sm text-slate-700">{record.procedure_name?.trim() || t('preop_not_informed')}</p>
          </div>

          <div className="grid gap-3 md:grid-cols-2">
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">{t('preop_field_allergies')}</p>
              <p className="text-sm text-slate-700">{record.allergies?.trim() || t('preop_not_informed')}</p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">{t('preop_field_medications')}</p>
              <p className="text-sm text-slate-700">{record.medications?.trim() || t('preop_not_informed')}</p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">{t('preop_field_previous_surgeries')}</p>
              <p className="text-sm text-slate-700">{record.previous_surgeries?.trim() || t('preop_not_informed')}</p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">{t('preop_field_diseases')}</p>
              <p className="text-sm text-slate-700">{record.diseases?.trim() || t('preop_not_informed')}</p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">{t('preop_field_height')}</p>
              <p className="text-sm text-slate-700">
                {record.height != null ? `${record.height} m` : t('preop_not_informed')}
              </p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">{t('preop_field_weight')}</p>
              <p className="text-sm text-slate-700">
                {record.weight != null ? `${record.weight} kg` : t('preop_not_informed')}
              </p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">{t('preop_field_smoking')}</p>
              <p className="text-sm text-slate-700">{record.smoking ? t('preop_yes') : t('preop_no')}</p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">{t('preop_field_alcohol')}</p>
              <p className="text-sm text-slate-700">{record.alcohol ? t('preop_yes') : t('preop_no')}</p>
            </div>
          </div>

          <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
            <p className="overline">{t('preop_clinic_observations')}</p>
            <p className="text-sm text-slate-700">{record.notes?.trim() || t('preop_no_observations')}</p>
          </div>

          <div>
            <p className="mb-2 text-sm font-semibold text-night">{t('preop_photos')}</p>
            {(record.photos || []).length === 0 ? (
              <p className="text-sm text-slate-500">{t('preop_no_photos')}</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                {record.photos.map((item) => (
                  <div
                    key={item.id}
                    className="relative h-20 w-20 overflow-hidden rounded-md border border-slate-200"
                  >
                    <a href={resolveMediaUrl(item.file_url)} target="_blank" rel="noreferrer">
                      <img
                        src={resolveMediaUrl(item.file_url)}
                        alt={t('preop_photo_alt')}
                        className="h-full w-full object-cover"
                      />
                    </a>
                    {allowPhotoDelete ? (
                      <button
                        type="button"
                        className="absolute right-1 top-1 rounded-full bg-red-600 px-1.5 py-0.5 text-[10px] font-semibold text-white hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-60"
                        onClick={() => onDeletePhoto?.(item.id)}
                        disabled={deletingPhotoId === item.id}
                        title={t('preop_remove_image_title')}
                      >
                        {deletingPhotoId === item.id ? '...' : 'X'}
                      </button>
                    ) : null}
                  </div>
                ))}
              </div>
            )}
          </div>

          <div>
            <p className="mb-2 text-sm font-semibold text-night">{t('preop_documents')}</p>
            {(record.documents || []).length === 0 ? (
              <p className="text-sm text-slate-500">{t('preop_no_documents')}</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                {record.documents.map((item, index) => (
                  <a
                    key={item.id}
                    href={resolveMediaUrl(item.file_url)}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center rounded-md border border-slate-200 px-3 py-2 text-sm text-primary hover:bg-tealIce"
                  >
                    {t('preop_document')} {index + 1}
                  </a>
                ))}
              </div>
            )}
          </div>

          {actionArea ? <div className="rounded-card border border-slate-200 bg-white p-4">{actionArea}</div> : null}
        </div>
      )}
    </Modal>
  )
}
