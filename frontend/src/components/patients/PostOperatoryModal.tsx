import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Modal } from '@/components/ui/Modal'
import { getLocaleForLanguage, t as translate, type TranslationKey } from '@/i18n/system'
import { usePreferencesStore } from '@/stores/preferencesStore'
import type { PostOperatoryAdminDetail, UrgentTicketRecord } from '@/types'
import { formatDate } from '@/utils/format'
import { resolveMediaUrl } from '@/utils/mediaUrl'
import { cn } from '@/utils/cn'
import {
  getLatestCheckin,
  postOperatoryClinicalReason,
  postOperatorySuggestedAction,
  postOperatoryDetailSummary,
  postOperatoryJourneyStatusLabel,
} from '@/components/patients/postOperatoryStatus'

interface PostOperatoryModalProps {
  isOpen: boolean
  onClose: () => void
  title?: string
  className?: string
  record?: PostOperatoryAdminDetail | null
  isLoading?: boolean
  isError?: boolean
  loadingMessage?: string
  errorMessage?: string
  emptyMessage?: string
  onUpdateUrgentStatus?: (
    ticketId: string,
    status: 'viewed' | 'resolved',
  ) => Promise<unknown> | unknown
  updatingUrgentTicketId?: string | null
  onUpdateJourneyStatus?: (
    journeyId: string,
    status: 'completed',
  ) => Promise<unknown> | unknown
  updatingJourneyStatus?: 'completed' | null
}

function formatDateTime(value: string | null | undefined, locale: string) {
  if (!value) return '-'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '-'

  return new Intl.DateTimeFormat(locale, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}

export function PostOperatoryModal({
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
  onUpdateUrgentStatus,
  updatingUrgentTicketId = null,
  onUpdateJourneyStatus,
  updatingJourneyStatus = null,
}: PostOperatoryModalProps) {
  const language = usePreferencesStore((state) => state.language)
  const t = (key: TranslationKey) => translate(language, key)
  const locale = getLocaleForLanguage(language)
  const resolvedTitle = title || t('postop_modal_title')
  const resolvedLoadingMessage = loadingMessage || t('postop_loading')
  const resolvedErrorMessage = errorMessage || t('postop_modal_load_error')
  const resolvedEmptyMessage = emptyMessage || t('postop_modal_empty')

  if (!record) {
    return (
      <Modal isOpen={isOpen} onClose={onClose} title={resolvedTitle} className={className}>
        {isLoading ? (
          <p className="text-sm text-slate-500">{resolvedLoadingMessage}</p>
        ) : isError ? (
          <p className="text-sm text-slate-500">{resolvedErrorMessage}</p>
        ) : (
          <p className="text-sm text-slate-500">{resolvedEmptyMessage}</p>
        )}
      </Modal>
    )
  }

  const summary = postOperatoryDetailSummary(record, t)
  const latestCheckin = getLatestCheckin(record)
  const reason = postOperatoryClinicalReason(record, t)
  const suggestedAction = postOperatorySuggestedAction(record, t)
  const urgentTickets = record.urgent_tickets || []
  const canCloseJourney = record.status === 'active' && Boolean(onUpdateJourneyStatus)

  const summaryHighlightClass =
    record.clinical_status === 'risk'
      ? 'border-danger/40 bg-danger/5'
      : record.clinical_status === 'delayed'
        ? 'border-amber-300 bg-amber-50'
        : 'border-success/30 bg-success/5'

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={resolvedTitle} className={className}>
      <div className="space-y-4">
        <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <p className="text-base font-semibold text-night">{record.patient_name}</p>
              <p className="text-sm text-slate-600">
                {t('postop_current_day_label')}: {record.current_day}/{record.total_days}
              </p>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <Badge className={summary.journeyClass}>{postOperatoryJourneyStatusLabel(record.status, t)}</Badge>
              <Badge className={summary.clinicalClass}>{summary.clinicalStatus}</Badge>
            </div>
          </div>
          {canCloseJourney ? (
            <div className="mt-3 flex flex-wrap gap-2 border-t border-slate-200 pt-3">
              <Button
                type="button"
                size="sm"
                variant="primary"
                disabled={updatingJourneyStatus !== null}
                onClick={async () => {
                  try {
                    await onUpdateJourneyStatus?.(record.journey_id, 'completed')
                  } catch {
                    // Error feedback is handled by page-level query refresh/state.
                  }
                }}
              >
                {updatingJourneyStatus === 'completed' ? t('postop_completing') : t('postop_complete_button')}
              </Button>
            </div>
          ) : null}
        </div>

        <div className="grid gap-3 md:grid-cols-2">
          <div className={cn('rounded-card border p-3', summaryHighlightClass)}>
            <p className="overline">{t('postop_patient_status')}</p>
            <div className="mt-1 flex flex-wrap items-center gap-2">
              <Badge className={summary.clinicalClass}>{summary.clinicalStatus}</Badge>
              <Badge className={summary.journeyClass}>
                {postOperatoryJourneyStatusLabel(record.status, t)}
              </Badge>
            </div>
            <p className="mt-2 text-sm text-slate-700">{reason}</p>
          </div>
          <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
            <p className="overline">{t('postop_suggested_action')}</p>
            <p className="mt-2 text-sm text-slate-700">{suggestedAction}</p>
          </div>
        </div>

        <div>
          <p className="mb-2 text-sm font-semibold text-night">{t('postop_urgent_tickets')}</p>
          {urgentTickets.length === 0 ? (
            <p className="text-sm text-slate-500">{t('postop_no_urgent_tickets')}</p>
          ) : (
            <div className="space-y-3">
              {urgentTickets.map((ticket) => {
                const isUpdating = updatingUrgentTicketId === ticket.id
                return (
                  <div
                    key={ticket.id}
                    className={cn(
                      'rounded-card border p-3',
                      ticket.status === 'open'
                        ? 'border-danger/40 bg-danger/5'
                        : ticket.status === 'viewed'
                          ? 'border-amber-300 bg-amber-50'
                          : 'border-success/30 bg-success/5',
                    )}
                  >
                    <div className="flex flex-wrap items-center gap-2">
                      <Badge className={urgentTicketStatusClass(ticket.status)}>
                        {urgentTicketStatusLabel(ticket.status, t)}
                      </Badge>
                      <Badge className={urgentTicketSeverityClass(ticket.severity)}>
                        {urgentTicketSeverityLabel(ticket.severity, t)}
                      </Badge>
                      <span className="text-xs text-slate-500">{formatDateTime(ticket.created_at, locale)}</span>
                    </div>
                    <p className="mt-2 text-sm text-slate-700">{ticket.message}</p>

                    {ticket.images?.length ? (
                      <div className="mt-2 grid grid-cols-3 gap-2 md:grid-cols-6">
                        {ticket.images.map((url, index) => (
                          <a
                            key={`${ticket.id}-${index}`}
                            href={resolveMediaUrl(url)}
                            target="_blank"
                            rel="noreferrer"
                            className="relative h-16 overflow-hidden rounded-md border border-slate-200"
                          >
                            <img
                              src={resolveMediaUrl(url)}
                              alt={`${t('postop_ticket_image_alt')} ${index + 1}`}
                              className="h-full w-full object-cover"
                            />
                          </a>
                        ))}
                      </div>
                    ) : null}

                    {ticket.status !== 'resolved' && onUpdateUrgentStatus ? (
                      <div className="mt-3 flex flex-wrap gap-2">
                        {ticket.status === 'open' ? (
                          <Button
                            type="button"
                            size="sm"
                            variant="secondary"
                            disabled={isUpdating}
                            onClick={async () => {
                              try {
                                await onUpdateUrgentStatus(ticket.id, 'viewed')
                              } catch {
                                // Error feedback is handled by page-level query refresh/state.
                              }
                            }}
                          >
                            {isUpdating ? t('postop_updating') : t('postop_ticket_mark_viewed')}
                          </Button>
                        ) : null}
                        <Button
                          type="button"
                          size="sm"
                          variant="primary"
                          disabled={isUpdating}
                          onClick={async () => {
                            try {
                              await onUpdateUrgentStatus(ticket.id, 'resolved')
                          } catch {
                            // Error feedback is handled by page-level query refresh/state.
                          }
                        }}
                      >
                          {isUpdating ? t('postop_updating') : t('postop_ticket_mark_resolved')}
                      </Button>
                    </div>
                  ) : null}
                  </div>
                )
              })}
            </div>
          )}
        </div>

        <div className="grid gap-3 md:grid-cols-3">
          <div className={cn('rounded-card border p-3', summaryHighlightClass)}>
            <p className="overline">{t('postop_last_checkin')}</p>
            <p className="text-sm text-slate-700">{formatDateTime(record.last_checkin_date, locale)}</p>
          </div>
          <div className={cn('rounded-card border p-3', summaryHighlightClass)}>
            <p className="overline">{t('postop_pain')}</p>
            <p className="text-sm text-slate-700">
              {record.last_pain_level != null ? record.last_pain_level : '-'}
            </p>
          </div>
          <div className={cn('rounded-card border p-3', summaryHighlightClass)}>
            <p className="overline">{t('postop_days_without_checkin')}</p>
            <p className="text-sm text-slate-700">{record.days_without_checkin}</p>
          </div>
        </div>

        <div className="grid gap-3 md:grid-cols-2">
          <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
            <p className="overline">{t('postop_journey_start')}</p>
            <p className="text-sm text-slate-700">{formatDate(record.start_date || record.surgery_date)}</p>
          </div>
          <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
            <p className="overline">{t('postop_last_fever')}</p>
            <p className="text-sm text-slate-700">{latestCheckin?.has_fever ? t('postop_yes') : t('postop_no')}</p>
          </div>
        </div>

        <div>
          <p className="mb-2 text-sm font-semibold text-night">{t('postop_checkins')}</p>
          {record.checkins.length === 0 ? (
            <p className="text-sm text-slate-500">{t('postop_no_checkins')}</p>
          ) : (
            <div className="overflow-x-auto rounded-card border border-slate-200">
              <table className="min-w-full divide-y divide-slate-100 bg-white">
                <thead className="bg-slate-50">
                  <tr>
                    <th className="px-3 py-2 text-left overline">{t('postop_col_day')}</th>
                    <th className="px-3 py-2 text-left overline">{t('postop_col_pain')}</th>
                    <th className="px-3 py-2 text-left overline">{t('postop_col_fever')}</th>
                    <th className="px-3 py-2 text-left overline">{t('postop_col_notes')}</th>
                    <th className="px-3 py-2 text-left overline">{t('postop_col_sent_at')}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {record.checkins.map((item) => (
                    <tr key={item.id}>
                      <td className="px-3 py-2 text-sm text-slate-700">{t('postop_day_prefix')} {item.day}</td>
                      <td className="px-3 py-2 text-sm text-slate-700">{item.pain_level}</td>
                      <td className="px-3 py-2 text-sm text-slate-700">{item.has_fever ? t('postop_yes') : t('postop_no')}</td>
                      <td className="px-3 py-2 text-sm text-slate-700">{item.notes?.trim() || '-'}</td>
                      <td className="px-3 py-2 text-sm text-slate-700">{formatDateTime(item.created_at, locale)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div>
          <p className="mb-2 text-sm font-semibold text-night">{t('postop_checklist')}</p>
          {record.checklist_by_day.length === 0 ? (
            <p className="text-sm text-slate-500">{t('postop_no_checklist')}</p>
          ) : (
            <div className="space-y-2">
              {record.checklist_by_day.map((day) => (
                <div key={day.day} className="rounded-card border border-slate-200 bg-slate-50 p-3">
                  <p className="mb-2 text-sm font-semibold text-night">{t('postop_day_prefix')} {day.day}</p>
                  <div className="space-y-1">
                    {day.items.map((item) => (
                      <div key={item.id} className="flex items-start justify-between gap-2 text-sm">
                        <span className="text-slate-700">{item.item_text}</span>
                        <Badge className={item.is_completed ? 'bg-success/15 text-success' : 'bg-slate-200 text-slate-600'}>
                          {item.is_completed ? t('postop_status_completed') : t('postop_status_pending')}
                        </Badge>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div>
          <p className="mb-2 text-sm font-semibold text-night">{t('postop_photos')}</p>
          {record.photos.length === 0 ? (
            <p className="text-sm text-slate-500">{t('postop_no_photos')}</p>
          ) : (
            <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
              {record.photos.map((photo) => (
                <a
                  key={photo.id}
                  href={resolveMediaUrl(photo.photo_url || photo.image)}
                  target="_blank"
                  rel="noreferrer"
                  className="relative h-24 overflow-hidden rounded-md border border-slate-200"
                >
                  <img
                    src={resolveMediaUrl(photo.photo_url || photo.image)}
                    alt={`${t('postop_photo_day')} ${photo.day}`}
                    className="h-full w-full object-cover"
                  />
                </a>
              ))}
            </div>
          )}
        </div>
      </div>
    </Modal>
  )
}

function urgentTicketStatusLabel(status: UrgentTicketRecord['status'], t: (key: TranslationKey) => string) {
  if (status === 'resolved') return t('postop_ticket_status_resolved')
  if (status === 'viewed') return t('postop_ticket_status_viewed')
  return t('postop_ticket_status_open')
}

function urgentTicketStatusClass(status: UrgentTicketRecord['status']) {
  if (status === 'resolved') return 'bg-success/15 text-success'
  if (status === 'viewed') return 'bg-amber-100 text-amber-700'
  return 'bg-danger/20 text-danger'
}

function urgentTicketSeverityLabel(
  severity: UrgentTicketRecord['severity'],
  t: (key: TranslationKey) => string,
) {
  if (severity === 'low') return t('postop_ticket_severity_low')
  if (severity === 'medium') return t('postop_ticket_severity_medium')
  return t('postop_ticket_severity_high')
}

function urgentTicketSeverityClass(severity: UrgentTicketRecord['severity']) {
  if (severity === 'low') return 'bg-slate-200 text-slate-700'
  if (severity === 'medium') return 'bg-amber-100 text-amber-700'
  return 'bg-danger/20 text-danger'
}
