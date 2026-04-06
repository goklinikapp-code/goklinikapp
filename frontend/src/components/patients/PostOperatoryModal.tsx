import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Modal } from '@/components/ui/Modal'
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

function formatDateTime(value?: string | null) {
  if (!value) return '-'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '-'

  return new Intl.DateTimeFormat('pt-BR', {
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
  title = 'Pós-operatório',
  className = 'max-w-5xl',
  record,
  isLoading = false,
  isError = false,
  loadingMessage = 'Carregando pós-operatório...',
  errorMessage = 'Não foi possível carregar os dados do pós-operatório agora.',
  emptyMessage = 'Nenhuma jornada pós-operatória encontrada para este paciente.',
  onUpdateUrgentStatus,
  updatingUrgentTicketId = null,
  onUpdateJourneyStatus,
  updatingJourneyStatus = null,
}: PostOperatoryModalProps) {
  if (!record) {
    return (
      <Modal isOpen={isOpen} onClose={onClose} title={title} className={className}>
        {isLoading ? (
          <p className="text-sm text-slate-500">{loadingMessage}</p>
        ) : isError ? (
          <p className="text-sm text-slate-500">{errorMessage}</p>
        ) : (
          <p className="text-sm text-slate-500">{emptyMessage}</p>
        )}
      </Modal>
    )
  }

  const summary = postOperatoryDetailSummary(record)
  const latestCheckin = getLatestCheckin(record)
  const reason = postOperatoryClinicalReason(record)
  const suggestedAction = postOperatorySuggestedAction(record)
  const urgentTickets = record.urgent_tickets || []
  const canCloseJourney = record.status === 'active' && Boolean(onUpdateJourneyStatus)

  const summaryHighlightClass =
    record.clinical_status === 'risk'
      ? 'border-danger/40 bg-danger/5'
      : record.clinical_status === 'delayed'
        ? 'border-amber-300 bg-amber-50'
        : 'border-success/30 bg-success/5'

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={title} className={className}>
      <div className="space-y-4">
        <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <p className="text-base font-semibold text-night">{record.patient_name}</p>
              <p className="text-sm text-slate-600">
                Dia atual: {record.current_day}/{record.total_days}
              </p>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <Badge className={summary.journeyClass}>{postOperatoryJourneyStatusLabel(record.status)}</Badge>
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
                {updatingJourneyStatus === 'completed' ? 'Concluindo...' : 'Concluir pós-op'}
              </Button>
            </div>
          ) : null}
        </div>

        <div className="grid gap-3 md:grid-cols-2">
          <div className={cn('rounded-card border p-3', summaryHighlightClass)}>
            <p className="overline">Status do paciente</p>
            <div className="mt-1 flex flex-wrap items-center gap-2">
              <Badge className={summary.clinicalClass}>{summary.clinicalStatus}</Badge>
              <Badge className={summary.journeyClass}>
                {postOperatoryJourneyStatusLabel(record.status)}
              </Badge>
            </div>
            <p className="mt-2 text-sm text-slate-700">{reason}</p>
          </div>
          <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
            <p className="overline">Ação sugerida</p>
            <p className="mt-2 text-sm text-slate-700">{suggestedAction}</p>
          </div>
        </div>

        <div>
          <p className="mb-2 text-sm font-semibold text-night">Tickets urgentes</p>
          {urgentTickets.length === 0 ? (
            <p className="text-sm text-slate-500">Nenhum ticket urgente para este paciente.</p>
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
                        {urgentTicketStatusLabel(ticket.status)}
                      </Badge>
                      <Badge className={urgentTicketSeverityClass(ticket.severity)}>
                        {urgentTicketSeverityLabel(ticket.severity)}
                      </Badge>
                      <span className="text-xs text-slate-500">{formatDateTime(ticket.created_at)}</span>
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
                              alt={`Ticket ${ticket.id} imagem ${index + 1}`}
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
                            {isUpdating ? 'Atualizando...' : 'Marcar como visualizado'}
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
                          {isUpdating ? 'Atualizando...' : 'Marcar como resolvido'}
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
            <p className="overline">Último check-in</p>
            <p className="text-sm text-slate-700">{formatDateTime(record.last_checkin_date)}</p>
          </div>
          <div className={cn('rounded-card border p-3', summaryHighlightClass)}>
            <p className="overline">Dor</p>
            <p className="text-sm text-slate-700">
              {record.last_pain_level != null ? record.last_pain_level : '-'}
            </p>
          </div>
          <div className={cn('rounded-card border p-3', summaryHighlightClass)}>
            <p className="overline">Dias sem check-in</p>
            <p className="text-sm text-slate-700">{record.days_without_checkin}</p>
          </div>
        </div>

        <div className="grid gap-3 md:grid-cols-2">
          <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
            <p className="overline">Início da jornada</p>
            <p className="text-sm text-slate-700">{formatDate(record.start_date || record.surgery_date)}</p>
          </div>
          <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
            <p className="overline">Última febre reportada</p>
            <p className="text-sm text-slate-700">{latestCheckin?.has_fever ? 'Sim' : 'Não'}</p>
          </div>
        </div>

        <div>
          <p className="mb-2 text-sm font-semibold text-night">Check-ins</p>
          {record.checkins.length === 0 ? (
            <p className="text-sm text-slate-500">Nenhum check-in enviado.</p>
          ) : (
            <div className="overflow-x-auto rounded-card border border-slate-200">
              <table className="min-w-full divide-y divide-slate-100 bg-white">
                <thead className="bg-slate-50">
                  <tr>
                    <th className="px-3 py-2 text-left overline">Dia</th>
                    <th className="px-3 py-2 text-left overline">Dor</th>
                    <th className="px-3 py-2 text-left overline">Febre</th>
                    <th className="px-3 py-2 text-left overline">Observações</th>
                    <th className="px-3 py-2 text-left overline">Enviado em</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {record.checkins.map((item) => (
                    <tr key={item.id}>
                      <td className="px-3 py-2 text-sm text-slate-700">Dia {item.day}</td>
                      <td className="px-3 py-2 text-sm text-slate-700">{item.pain_level}</td>
                      <td className="px-3 py-2 text-sm text-slate-700">{item.has_fever ? 'Sim' : 'Não'}</td>
                      <td className="px-3 py-2 text-sm text-slate-700">{item.notes?.trim() || '-'}</td>
                      <td className="px-3 py-2 text-sm text-slate-700">{formatDateTime(item.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div>
          <p className="mb-2 text-sm font-semibold text-night">Checklist</p>
          {record.checklist_by_day.length === 0 ? (
            <p className="text-sm text-slate-500">Nenhum checklist disponível.</p>
          ) : (
            <div className="space-y-2">
              {record.checklist_by_day.map((day) => (
                <div key={day.day} className="rounded-card border border-slate-200 bg-slate-50 p-3">
                  <p className="mb-2 text-sm font-semibold text-night">Dia {day.day}</p>
                  <div className="space-y-1">
                    {day.items.map((item) => (
                      <div key={item.id} className="flex items-start justify-between gap-2 text-sm">
                        <span className="text-slate-700">{item.item_text}</span>
                        <Badge className={item.is_completed ? 'bg-success/15 text-success' : 'bg-slate-200 text-slate-600'}>
                          {item.is_completed ? 'Concluído' : 'Pendente'}
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
          <p className="mb-2 text-sm font-semibold text-night">Fotos</p>
          {record.photos.length === 0 ? (
            <p className="text-sm text-slate-500">Nenhuma foto enviada.</p>
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
                    alt={`Foto dia ${photo.day}`}
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

function urgentTicketStatusLabel(status: UrgentTicketRecord['status']) {
  if (status === 'resolved') return 'Resolvido'
  if (status === 'viewed') return 'Visualizado'
  return 'Aberto'
}

function urgentTicketStatusClass(status: UrgentTicketRecord['status']) {
  if (status === 'resolved') return 'bg-success/15 text-success'
  if (status === 'viewed') return 'bg-amber-100 text-amber-700'
  return 'bg-danger/20 text-danger'
}

function urgentTicketSeverityLabel(severity: UrgentTicketRecord['severity']) {
  if (severity === 'low') return 'Baixa'
  if (severity === 'medium') return 'Média'
  return 'Alta'
}

function urgentTicketSeverityClass(severity: UrgentTicketRecord['severity']) {
  if (severity === 'low') return 'bg-slate-200 text-slate-700'
  if (severity === 'medium') return 'bg-amber-100 text-amber-700'
  return 'bg-danger/20 text-danger'
}
