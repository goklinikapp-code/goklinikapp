import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Eye, RefreshCw } from 'lucide-react'
import { useMemo, useState } from 'react'

import {
  getPostOperatoryByPatient,
  listTenantPostOperatory,
  updatePostOperatoryJourneyStatus,
  updateUrgentTicketStatus,
} from '@/api/postOperatory'
import { PostOperatoryModal } from '@/components/patients/PostOperatoryModal'
import {
  postOperatoryClinicalStatusClass,
  postOperatoryClinicalStatusLabel,
} from '@/components/patients/postOperatoryStatus'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import type { PostOperatoryAdminItem } from '@/types'
import { cn } from '@/utils/cn'

type ListFilter = 'all' | 'active' | 'alerts' | 'without_checkin' | 'completed'
type ExtendedListFilter = ListFilter | 'urgent'

const FILTERS: Array<{ key: ExtendedListFilter; label: string }> = [
  { key: 'all', label: 'Todos' },
  { key: 'active', label: 'Em andamento' },
  { key: 'alerts', label: 'Com alerta' },
  { key: 'urgent', label: 'Urgentes' },
  { key: 'without_checkin', label: 'Sem check-in' },
  { key: 'completed', label: 'Concluídos' },
]

function formatDateTime(value?: string | null) {
  if (!value) return 'Sem check-in'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'Sem check-in'

  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}

function applyFilter(rows: PostOperatoryAdminItem[], filter: ExtendedListFilter) {
  if (filter === 'all') return rows
  if (filter === 'active') return rows.filter((item) => item.status === 'active')
  if (filter === 'alerts') return rows.filter((item) => item.clinical_status === 'risk')
  if (filter === 'urgent') return rows.filter((item) => item.has_open_urgent_ticket === true)
  if (filter === 'without_checkin') {
    return rows.filter(
      (item) => item.status === 'active' && item.clinical_status === 'delayed',
    )
  }
  return rows.filter((item) => item.status === 'completed')
}

export default function PostOperatoryPage() {
  const queryClient = useQueryClient()
  const [selectedFilter, setSelectedFilter] = useState<ExtendedListFilter>('all')
  const [selectedPatientId, setSelectedPatientId] = useState<string | null>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)

  const listQuery = useQuery({
    queryKey: ['post-operatory-admin-list'],
    queryFn: () => listTenantPostOperatory(),
    refetchInterval: 15000,
    refetchOnMount: 'always',
  })

  const detailQuery = useQuery({
    queryKey: ['post-operatory-admin-detail', selectedPatientId],
    queryFn: () => getPostOperatoryByPatient(selectedPatientId || ''),
    enabled: isModalOpen && Boolean(selectedPatientId),
  })

  const urgentTicketStatusMutation = useMutation({
    mutationFn: (payload: { ticketId: string; status: 'viewed' | 'resolved' }) =>
      updateUrgentTicketStatus(payload.ticketId, payload.status),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({
          queryKey: ['post-operatory-admin-list'],
        }),
        queryClient.invalidateQueries({
          queryKey: ['post-operatory-admin-detail', selectedPatientId],
        }),
      ])
    },
  })

  const journeyStatusMutation = useMutation({
    mutationFn: (payload: { journeyId: string; status: 'completed' }) =>
      updatePostOperatoryJourneyStatus(payload.journeyId, payload.status),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({
          queryKey: ['post-operatory-admin-list'],
        }),
        queryClient.invalidateQueries({
          queryKey: ['post-operatory-admin-detail', selectedPatientId],
        }),
      ])
    },
  })

  const rows = listQuery.data || []
  const filteredRows = useMemo(
    () => applyFilter(rows, selectedFilter),
    [rows, selectedFilter],
  )

  const selectedRow = useMemo(
    () => rows.find((item) => item.patient_id === selectedPatientId) || null,
    [rows, selectedPatientId],
  )

  const dashboard = useMemo(() => {
    const active = rows.filter((item) => item.status === 'active')

    return {
      activeCount: active.length,
      alertsCount: rows.filter((item) => item.clinical_status === 'risk').length,
      noCheckinTodayCount: active.filter((item) => item.clinical_status === 'delayed').length,
      completedCount: rows.filter((item) => item.status === 'completed').length,
    }
  }, [rows])

  return (
    <div className="space-y-5">
      <SectionHeader
        title="Pós-operatório"
        subtitle="Monitore pacientes em recuperação, identifique riscos e acompanhe a evolução clínica."
        actions={
          <Button
            type="button"
            variant="secondary"
            disabled={listQuery.isLoading || listQuery.isFetching}
            onClick={() => {
              void listQuery.refetch()
              if (isModalOpen && selectedPatientId) {
                void detailQuery.refetch()
              }
            }}
          >
            <RefreshCw
              className={cn(
                'h-4 w-4',
                (listQuery.isLoading || listQuery.isFetching) && 'animate-spin',
              )}
            />
            Atualizar
          </Button>
        }
      />

      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        <Card className="space-y-2">
          <p className="overline">Pacientes em pós-op</p>
          <p className="text-2xl font-bold text-night">{dashboard.activeCount}</p>
        </Card>
        <Card className="space-y-2">
          <p className="overline">Com alerta</p>
          <p className="text-2xl font-bold text-danger">{dashboard.alertsCount}</p>
        </Card>
        <Card className="space-y-2">
          <p className="overline">Sem check-in hoje</p>
          <p className="text-2xl font-bold text-amber-600">{dashboard.noCheckinTodayCount}</p>
        </Card>
        <Card className="space-y-2">
          <p className="overline">Concluídos</p>
          <p className="text-2xl font-bold text-success">{dashboard.completedCount}</p>
        </Card>
      </div>

      <Card>
        <div className="flex flex-wrap items-center gap-2">
          {FILTERS.map((filter) => (
            <button
              key={filter.key}
              type="button"
              onClick={() => setSelectedFilter(filter.key)}
              className={cn(
                'rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-wide transition',
                selectedFilter === filter.key
                  ? 'border-primary bg-primary text-white'
                  : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50',
              )}
            >
              {filter.label}
            </button>
          ))}
          <span className="ml-auto text-sm text-slate-500">
            {filteredRows.length} paciente(s) encontrado(s)
          </span>
        </div>
      </Card>

      <Card padded={false} className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">PACIENTE</th>
                <th className="px-4 py-3 text-left overline">STATUS</th>
                <th className="px-4 py-3 text-left overline">DIA ATUAL</th>
                <th className="px-4 py-3 text-left overline">ÚLTIMO CHECK-IN</th>
                <th className="px-4 py-3 text-left overline">DOR</th>
                <th className="px-4 py-3 text-left overline">STATUS CLÍNICO</th>
                <th className="px-4 py-3 text-right overline">AÇÃO</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {listQuery.isLoading ? (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-sm text-slate-500">
                    Carregando pós-operatórios...
                  </td>
                </tr>
              ) : listQuery.isError ? (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-sm text-slate-500">
                    Não foi possível carregar os pós-operatórios.
                  </td>
                </tr>
              ) : filteredRows.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-sm text-slate-500">
                    Nenhum paciente encontrado com os filtros atuais.
                  </td>
                </tr>
              ) : (
                filteredRows.map((item) => (
                  <tr
                    key={item.patient_id}
                    className={cn(
                      'hover:bg-tealIce/50',
                      item.has_open_urgent_ticket && 'bg-danger/5',
                    )}
                  >
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <Avatar
                          name={item.patient_name}
                          src={item.patient_avatar_url || undefined}
                          className="h-8 w-8"
                        />
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="text-sm font-semibold text-night">{item.patient_name}</span>
                          {item.has_open_urgent_ticket ? (
                            <Badge className="bg-danger/20 text-danger">
                              Urgente {item.open_urgent_ticket_count ? `(${item.open_urgent_ticket_count})` : ''}
                            </Badge>
                          ) : null}
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <Badge className={item.status === 'completed' ? 'bg-success/15 text-success' : item.status === 'cancelled' ? 'bg-danger/15 text-danger' : 'bg-primary/15 text-primary'}>
                        {item.status === 'completed' ? 'Concluído' : item.status === 'cancelled' ? 'Cancelado' : 'Em andamento'}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-700">
                      {item.current_day}/{item.total_days}
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-600">
                      {formatDateTime(item.last_checkin_date)}
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-700">
                      {item.last_pain_level != null ? item.last_pain_level : '-'}
                    </td>
                    <td className="px-4 py-3">
                      <Badge className={postOperatoryClinicalStatusClass(item.clinical_status)}>
                        {postOperatoryClinicalStatusLabel(item.clinical_status)}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Button
                        type="button"
                        size="sm"
                        variant="secondary"
                        onClick={() => {
                          setSelectedPatientId(item.patient_id)
                          setIsModalOpen(true)
                        }}
                      >
                        <Eye className="h-4 w-4" />
                        Ver
                      </Button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </Card>

      <PostOperatoryModal
        isOpen={isModalOpen}
        onClose={() => {
          setIsModalOpen(false)
          setSelectedPatientId(null)
        }}
        title={
          selectedRow?.patient_name
            ? `Pós-operatório • ${selectedRow.patient_name}`
            : 'Pós-operatório'
        }
        record={detailQuery.data}
        isLoading={detailQuery.isLoading}
        isError={detailQuery.isError}
        onUpdateUrgentStatus={(ticketId, status) =>
          urgentTicketStatusMutation.mutateAsync({ ticketId, status })
        }
        updatingUrgentTicketId={
          urgentTicketStatusMutation.isPending
            ? urgentTicketStatusMutation.variables?.ticketId || null
            : null
        }
        onUpdateJourneyStatus={(journeyId, status) =>
          journeyStatusMutation.mutateAsync({ journeyId, status })
        }
        updatingJourneyStatus={
          journeyStatusMutation.isPending
            ? journeyStatusMutation.variables?.status || null
            : null
        }
      />
    </div>
  )
}
