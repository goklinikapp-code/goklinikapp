import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { MailOpen, RefreshCw, SendHorizonal } from 'lucide-react'
import { useMemo, useState } from 'react'
import toast from 'react-hot-toast'

import {
  listUrgentMedicalRequests,
  replyUrgentMedicalRequest,
} from '@/api/postOperatory'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Modal } from '@/components/ui/Modal'
import { TextArea } from '@/components/ui/TextArea'
import type { UrgentMedicalRequestRecord } from '@/types'
import { cn } from '@/utils/cn'

type InboxFilter = 'all' | 'open' | 'answered' | 'closed'

const FILTERS: Array<{ key: InboxFilter; label: string }> = [
  { key: 'all', label: 'Todas' },
  { key: 'open', label: 'Não lidas' },
  { key: 'answered', label: 'Respondidas' },
  { key: 'closed', label: 'Fechadas' },
]

function formatDateTime(value: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '-'
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}

function statusLabel(status: UrgentMedicalRequestRecord['status']) {
  if (status === 'open') return 'Não lida'
  if (status === 'answered') return 'Respondida'
  return 'Fechada'
}

function statusBadgeClass(status: UrgentMedicalRequestRecord['status']) {
  if (status === 'open') return 'bg-danger/15 text-danger'
  if (status === 'answered') return 'bg-success/15 text-success'
  return 'bg-slate-200 text-slate-700'
}

function applyFilter(items: UrgentMedicalRequestRecord[], filter: InboxFilter) {
  if (filter === 'all') return items
  return items.filter((item) => item.status === filter)
}

export default function InboxPage() {
  const queryClient = useQueryClient()
  const [filter, setFilter] = useState<InboxFilter>('all')
  const [selected, setSelected] = useState<UrgentMedicalRequestRecord | null>(null)
  const [answerDraft, setAnswerDraft] = useState('')

  const inboxQuery = useQuery({
    queryKey: ['surgeon-inbox-urgent-requests'],
    queryFn: listUrgentMedicalRequests,
    refetchInterval: 15000,
  })

  const replyMutation = useMutation({
    mutationFn: (payload: { requestId: string; answer: string }) =>
      replyUrgentMedicalRequest(payload.requestId, payload.answer),
    onSuccess: async () => {
      toast.success('Resposta enviada com sucesso.')
      setSelected(null)
      setAnswerDraft('')
      await queryClient.invalidateQueries({
        queryKey: ['surgeon-inbox-urgent-requests'],
      })
      await queryClient.invalidateQueries({
        queryKey: ['header-notifications-list'],
      })
      await queryClient.invalidateQueries({
        queryKey: ['header-notifications-unread'],
      })
    },
    onError: () => {
      toast.error('Não foi possível enviar resposta agora.')
    },
  })

  const rows = useMemo(() => {
    const base = inboxQuery.data || []
    return [...base].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
  }, [inboxQuery.data])

  const filteredRows = useMemo(() => applyFilter(rows, filter), [rows, filter])

  const openCount = rows.filter((item) => item.status === 'open').length

  const openReplyModal = (item: UrgentMedicalRequestRecord) => {
    setSelected(item)
    setAnswerDraft(item.answer || '')
  }

  const handleSubmitReply = async () => {
    if (!selected) return
    const normalized = answerDraft.trim()
    if (normalized.length < 3) {
      toast.error('Digite pelo menos 3 caracteres na resposta.')
      return
    }
    await replyMutation.mutateAsync({
      requestId: selected.id,
      answer: normalized,
    })
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title="Caixa de Mensagens"
        subtitle="Mensagens assíncronas dos pacientes para acompanhamento clínico."
        actions={
          <Button
            type="button"
            variant="secondary"
            disabled={inboxQuery.isLoading || inboxQuery.isFetching}
            onClick={() => {
              void inboxQuery.refetch()
            }}
          >
            <RefreshCw
              className={cn(
                'h-4 w-4',
                (inboxQuery.isLoading || inboxQuery.isFetching) && 'animate-spin',
              )}
            />
            Atualizar
          </Button>
        }
      />

      <Card>
        <div className="flex flex-wrap items-center gap-2">
          {FILTERS.map((item) => (
            <button
              key={item.key}
              type="button"
              onClick={() => setFilter(item.key)}
              className={cn(
                'rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-wide transition',
                filter === item.key
                  ? 'border-primary bg-primary text-white'
                  : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50',
              )}
            >
              {item.label}
            </button>
          ))}
          <Badge className="ml-auto bg-danger/15 text-danger">
            {openCount} não lida(s)
          </Badge>
        </div>
      </Card>

      <Card padded={false} className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">PACIENTE</th>
                <th className="px-4 py-3 text-left overline">MENSAGEM</th>
                <th className="px-4 py-3 text-left overline">STATUS</th>
                <th className="px-4 py-3 text-left overline">DATA</th>
                <th className="px-4 py-3 text-right overline">AÇÃO</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {inboxQuery.isLoading ? (
                <tr>
                  <td colSpan={5} className="px-4 py-10 text-center text-sm text-slate-500">
                    Carregando caixa de mensagens...
                  </td>
                </tr>
              ) : inboxQuery.isError ? (
                <tr>
                  <td colSpan={5} className="px-4 py-10 text-center text-sm text-slate-500">
                    Não foi possível carregar mensagens agora.
                  </td>
                </tr>
              ) : filteredRows.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-4 py-10 text-center text-sm text-slate-500">
                    Nenhuma mensagem encontrada para este filtro.
                  </td>
                </tr>
              ) : (
                filteredRows.map((item) => (
                  <tr key={item.id} className={cn(item.status === 'open' && 'bg-danger/5')}>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <Avatar
                          name={item.patient_name}
                          src={item.patient_avatar_url || undefined}
                          className="h-8 w-8"
                        />
                        <div>
                          <p className="text-sm font-semibold text-night">{item.patient_name}</p>
                          <p className="caption">{item.patient_email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-700">
                      <p className="max-w-xl truncate">{item.question}</p>
                      {item.status === 'answered' && item.answer ? (
                        <p className="caption mt-1 truncate text-success">
                          Resposta: {item.answer}
                        </p>
                      ) : null}
                    </td>
                    <td className="px-4 py-3">
                      <Badge className={statusBadgeClass(item.status)}>
                        {statusLabel(item.status)}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-600">
                      {formatDateTime(item.created_at)}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Button
                        type="button"
                        size="sm"
                        variant={item.status === 'answered' ? 'secondary' : 'primary'}
                        onClick={() => openReplyModal(item)}
                      >
                        <MailOpen className="h-4 w-4" />
                        {item.status === 'answered' ? 'Ver resposta' : 'Responder'}
                      </Button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </Card>

      <Modal
        isOpen={Boolean(selected)}
        onClose={() => {
          if (replyMutation.isPending) return
          setSelected(null)
          setAnswerDraft('')
        }}
        title={selected ? `Mensagem • ${selected.patient_name}` : 'Mensagem'}
        className="max-w-2xl"
      >
        {selected ? (
          <div className="space-y-3">
            <Card className="bg-slate-50">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Pergunta do paciente
              </p>
              <p className="mt-2 text-sm text-night">{selected.question}</p>
            </Card>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">
                Sua resposta
              </label>
              <TextArea
                value={answerDraft}
                onChange={(event) => setAnswerDraft(event.target.value)}
                rows={5}
                placeholder="Escreva uma orientação clara para o paciente..."
              />
            </div>

            <div className="flex justify-end gap-2">
              <Button
                type="button"
                variant="secondary"
                onClick={() => {
                  if (replyMutation.isPending) return
                  setSelected(null)
                  setAnswerDraft('')
                }}
              >
                Fechar
              </Button>
              <Button
                type="button"
                disabled={replyMutation.isPending}
                onClick={() => void handleSubmitReply()}
              >
                <SendHorizonal className="h-4 w-4" />
                {replyMutation.isPending ? 'Enviando...' : 'Enviar resposta'}
              </Button>
            </div>
          </div>
        ) : null}
      </Modal>
    </div>
  )
}
