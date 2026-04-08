import { useEffect, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Bot, RefreshCw, Search, SendHorizonal, UserRound } from 'lucide-react'
import toast from 'react-hot-toast'

import {
  getChatAIConversationMessages,
  getChatAISettings,
  listChatAIConversations,
  sendChatAIStaffMessage,
  setChatAIPatientMode,
  setChatAITypingStatus,
  updateChatAISettings,
  type ChatAIMessage,
} from '@/api/chatCenter'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { TextArea } from '@/components/ui/TextArea'
import { cn } from '@/utils/cn'

function formatDateTime(value?: string | null) {
  if (!value) return '-'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '-'
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}

function messageSourceLabel(message: ChatAIMessage) {
  if (message.source === 'staff') return 'EQUIPE'
  if (message.source === 'ai') return 'IA'
  if (message.source === 'system') return 'SISTEMA'
  return 'PACIENTE'
}

export default function ChatCenterPage() {
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')
  const [selectedPatientId, setSelectedPatientId] = useState<string | null>(null)
  const [draft, setDraft] = useState('')
  const [composerFocused, setComposerFocused] = useState(false)
  const [sendOnEnter, setSendOnEnter] = useState(false)
  const messagesScrollRef = useRef<HTMLDivElement | null>(null)

  const settingsQuery = useQuery({
    queryKey: ['chat-ai-settings'],
    queryFn: getChatAISettings,
    refetchInterval: 30000,
  })

  const conversationsQuery = useQuery({
    queryKey: ['chat-ai-conversations', search],
    queryFn: () => listChatAIConversations(search.trim() || undefined),
    refetchInterval: 15000,
  })
  const conversationRows = conversationsQuery.data?.results || []
  const effectiveSelectedPatientId =
    selectedPatientId && conversationRows.some((item) => item.patient_id === selectedPatientId)
      ? selectedPatientId
      : (conversationRows[0]?.patient_id ?? null)

  const detailQuery = useQuery({
    queryKey: ['chat-ai-conversation-detail', effectiveSelectedPatientId],
    queryFn: () => getChatAIConversationMessages(effectiveSelectedPatientId as string),
    enabled: Boolean(effectiveSelectedPatientId),
    refetchInterval: 7000,
  })

  const updateGlobalSettingsMutation = useMutation({
    mutationFn: updateChatAISettings,
    onSuccess: async () => {
      toast.success('Modo global do chat atualizado.')
      await queryClient.invalidateQueries({ queryKey: ['chat-ai-settings'] })
      await queryClient.invalidateQueries({ queryKey: ['chat-ai-conversations'] })
      await queryClient.invalidateQueries({ queryKey: ['chat-ai-conversation-detail'] })
    },
    onError: () => {
      toast.error('Não foi possível atualizar o modo global agora.')
    },
  })

  const updatePatientModeMutation = useMutation({
    mutationFn: (payload: { patientId: string; forceHuman: boolean }) =>
      setChatAIPatientMode(payload.patientId, payload.forceHuman),
    onSuccess: async () => {
      toast.success('Modo da conversa atualizado.')
      await queryClient.invalidateQueries({ queryKey: ['chat-ai-conversations'] })
      await queryClient.invalidateQueries({ queryKey: ['chat-ai-conversation-detail'] })
    },
    onError: () => {
      toast.error('Não foi possível atualizar o modo dessa conversa.')
    },
  })

  const sendMessageMutation = useMutation({
    mutationFn: (payload: { patientId: string; content: string }) =>
      sendChatAIStaffMessage(payload.patientId, payload.content),
    onSuccess: async () => {
      setDraft('')
      toast.success('Mensagem enviada para o paciente.')
      await queryClient.invalidateQueries({ queryKey: ['chat-ai-conversations'] })
      await queryClient.invalidateQueries({ queryKey: ['chat-ai-conversation-detail'] })
    },
    onError: () => {
      toast.error('Não foi possível enviar a mensagem agora.')
    },
  })

  const hasDraft = draft.trim().length > 0
  useEffect(() => {
    if (!effectiveSelectedPatientId) return
    let intervalId: number | undefined
    const emitTyping = (isTyping: boolean) => {
      void setChatAITypingStatus(effectiveSelectedPatientId, isTyping).catch(() => {
        // no-op: typing heartbeat should not break UI.
      })
    }

    if (composerFocused && hasDraft) {
      emitTyping(true)
      intervalId = window.setInterval(() => {
        emitTyping(true)
      }, 2000)
    } else {
      emitTyping(false)
    }

    return () => {
      if (intervalId) {
        window.clearInterval(intervalId)
      }
      emitTyping(false)
    }
  }, [effectiveSelectedPatientId, composerFocused, hasDraft])

  const handleSendMessage = async () => {
    const content = draft.trim()
    if (!effectiveSelectedPatientId || !content) return
    await sendMessageMutation.mutateAsync({
      patientId: effectiveSelectedPatientId,
      content,
    })
  }

  const handleToggleGlobalAI = () => {
    const current = settingsQuery.data?.ai_enabled ?? true
    updateGlobalSettingsMutation.mutate(!current)
  }

  const handleTogglePatientMode = () => {
    if (!effectiveSelectedPatientId || !detailQuery.data) return
    updatePatientModeMutation.mutate({
      patientId: effectiveSelectedPatientId,
      forceHuman: !detailQuery.data.force_human,
    })
  }

  useEffect(() => {
    const element = messagesScrollRef.current
    if (!element) return
    element.scrollTop = element.scrollHeight
  }, [effectiveSelectedPatientId, detailQuery.data?.messages.length])

  return (
    <div className="space-y-5">
      <SectionHeader
        title="Central de Chat"
        subtitle="Acompanhe conversas, intervenha manualmente e controle quando a IA deve pausar."
        actions={
          <>
            <Button
              type="button"
              variant="secondary"
              onClick={() => {
                void settingsQuery.refetch()
                void conversationsQuery.refetch()
                if (effectiveSelectedPatientId) {
                  void detailQuery.refetch()
                }
              }}
            >
              <RefreshCw className={cn('h-4 w-4', (conversationsQuery.isFetching || detailQuery.isFetching) && 'animate-spin')} />
              Atualizar
            </Button>
            <Button
              type="button"
              variant={settingsQuery.data?.ai_enabled === false ? 'danger' : 'primary'}
              disabled={updateGlobalSettingsMutation.isPending || settingsQuery.isLoading}
              onClick={handleToggleGlobalAI}
            >
              <Bot className="h-4 w-4" />
              {settingsQuery.data?.ai_enabled === false ? 'Retomar IA Global' : 'Pausar IA Global'}
            </Button>
          </>
        }
      />

      <div className="grid gap-5 lg:grid-cols-[320px_minmax(0,1fr)]">
        <Card className="flex h-[calc(100vh-240px)] min-h-[620px] max-h-[860px] flex-col overflow-hidden p-0">
          <div className="border-b border-slate-100 p-4">
            <p className="overline">Conversas</p>
            <div className="mt-2 flex items-center gap-2">
              <Search className="h-4 w-4 text-slate-400" />
              <Input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Buscar paciente por nome ou e-mail"
              />
            </div>
          </div>

          <div className="min-h-0 flex-1 space-y-1 overflow-y-auto p-2">
            {conversationsQuery.isLoading ? (
              <p className="px-3 py-4 text-sm text-slate-500">Carregando conversas...</p>
            ) : conversationsQuery.isError ? (
              <p className="px-3 py-4 text-sm text-slate-500">Não foi possível carregar as conversas.</p>
            ) : conversationRows.length === 0 ? (
              <p className="px-3 py-4 text-sm text-slate-500">Nenhuma conversa encontrada.</p>
            ) : (
              conversationRows.map((item) => (
                <button
                  key={item.patient_id}
                  type="button"
                  onClick={() => setSelectedPatientId(item.patient_id)}
                  className={cn(
                    'w-full rounded-xl border px-3 py-2 text-left transition',
                    effectiveSelectedPatientId === item.patient_id
                      ? 'border-primary bg-primary/5'
                      : 'border-transparent hover:border-slate-200 hover:bg-slate-50',
                  )}
                >
                  <div className="flex items-start gap-3">
                    <Avatar
                      name={item.patient_name}
                      src={item.patient_avatar_url}
                      className="mt-0.5 h-9 w-9 border border-white/80 shadow-sm"
                    />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-start justify-between gap-2">
                        <p className="truncate text-sm font-semibold text-night">{item.patient_name}</p>
                        <p className="text-[11px] text-slate-500">{formatDateTime(item.last_message_at)}</p>
                      </div>
                      <p className="caption truncate">{item.patient_email}</p>
                      <p className="mt-1 truncate text-xs text-slate-600">{item.last_message_preview}</p>
                    </div>
                  </div>
                  <div className="mt-2 flex justify-end">
                    <Badge className={item.effective_ai_enabled ? 'bg-success/15 text-success' : 'bg-amber-100 text-amber-700'}>
                      {item.effective_ai_enabled ? 'IA ativa' : 'Humano'}
                    </Badge>
                  </div>
                </button>
              ))
            )}
          </div>
        </Card>

        <Card className="flex h-[calc(100vh-240px)] min-h-[620px] max-h-[860px] flex-col">
          {!effectiveSelectedPatientId ? (
            <div className="flex flex-1 items-center justify-center text-sm text-slate-500">
              Selecione uma conversa para começar.
            </div>
          ) : detailQuery.isLoading ? (
            <div className="flex flex-1 items-center justify-center text-sm text-slate-500">
              Carregando mensagens...
            </div>
          ) : detailQuery.isError || !detailQuery.data ? (
            <div className="flex flex-1 items-center justify-center text-sm text-slate-500">
              Não foi possível carregar esta conversa.
            </div>
          ) : (
            <>
              <div className="mb-4 flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 pb-4">
                <div className="flex items-center gap-3">
                  <Avatar
                    name={detailQuery.data.patient.name}
                    src={detailQuery.data.patient.avatar_url}
                    className="h-11 w-11 border border-white shadow-sm"
                  />
                  <div>
                    <p className="text-base font-semibold text-night">{detailQuery.data.patient.name}</p>
                    <p className="caption">{detailQuery.data.patient.email}</p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <Badge className={detailQuery.data.effective_ai_enabled ? 'bg-success/15 text-success' : 'bg-amber-100 text-amber-700'}>
                    {detailQuery.data.effective_ai_enabled ? 'IA ativa' : 'Humano assumiu'}
                  </Badge>
                  <Button
                    type="button"
                    variant="secondary"
                    disabled={updatePatientModeMutation.isPending}
                    onClick={handleTogglePatientMode}
                  >
                    {detailQuery.data.force_human ? 'Retomar IA neste paciente' : 'Assumir conversa (Humano)'}
                  </Button>
                </div>
              </div>

              <div
                ref={messagesScrollRef}
                className="min-h-0 flex-1 space-y-2 overflow-y-auto rounded-2xl bg-slate-100/80 p-4"
              >
                {detailQuery.data.messages.length === 0 ? (
                  <p className="text-sm text-slate-500">Ainda não há mensagens nessa conversa.</p>
                ) : (
                  detailQuery.data.messages.map((message) => {
                    const isPatientMessage = message.role === 'user'
                    const speakerLabel = isPatientMessage
                      ? 'Paciente'
                      : message.source === 'staff'
                        ? 'Equipe da clínica'
                        : message.source === 'ai'
                          ? 'Assistente IA'
                          : 'Sistema'
                    return (
                      <div
                        key={message.id}
                        className={cn('flex', isPatientMessage ? 'justify-end' : 'justify-start')}
                      >
                        <div
                          className={cn(
                            'max-w-[78%] rounded-2xl px-3 py-2 shadow-sm',
                            isPatientMessage
                              ? 'rounded-br-md bg-primary text-white'
                              : 'rounded-bl-md border border-slate-200 bg-white text-slate-800',
                          )}
                        >
                          <div className="mb-1 flex items-center gap-2">
                            <span className={cn('text-[10px] font-semibold uppercase tracking-wide', isPatientMessage ? 'text-white/80' : 'text-slate-500')}>
                              {speakerLabel}
                            </span>
                            <Badge
                              className={cn(
                                'px-2 py-0 text-[9px]',
                                isPatientMessage ? 'bg-white/20 text-white' : 'bg-slate-100 text-slate-600',
                              )}
                            >
                              {messageSourceLabel(message)}
                            </Badge>
                          </div>
                          <p className="whitespace-pre-wrap text-sm">{message.content}</p>
                          <p className={cn('mt-1 text-[11px]', isPatientMessage ? 'text-white/70' : 'text-slate-500')}>
                            {formatDateTime(message.created_at)}
                          </p>
                        </div>
                      </div>
                    )
                  })
                )}
              </div>

              <div className="mt-4 space-y-2">
                <TextArea
                  rows={3}
                  value={draft}
                  onChange={(event) => setDraft(event.target.value)}
                  onKeyDown={(event) => {
                    if (!sendOnEnter) return
                    if (event.key === 'Enter' && !event.shiftKey) {
                      event.preventDefault()
                      void handleSendMessage()
                    }
                  }}
                  onFocus={() => setComposerFocused(true)}
                  onBlur={() => setComposerFocused(false)}
                  placeholder="Digite a resposta da equipe da clínica..."
                />
                <div className="flex items-center justify-between">
                  <div className="space-y-1">
                    <label className="inline-flex cursor-pointer items-center gap-2 text-xs text-slate-600">
                      <input
                        type="checkbox"
                        className="h-4 w-4 rounded border-slate-300 text-primary focus:ring-primary/30"
                        checked={sendOnEnter}
                        onChange={(event) => setSendOnEnter(event.target.checked)}
                      />
                      Enter envia mensagem (Shift + Enter quebra linha)
                    </label>
                    <p className="caption flex items-center gap-1">
                      <UserRound className="h-3.5 w-3.5" />
                      O paciente verá “digitando...” enquanto você escreve.
                    </p>
                  </div>
                  <Button
                    type="button"
                    disabled={sendMessageMutation.isPending || draft.trim().length === 0}
                    onClick={() => void handleSendMessage()}
                  >
                    <SendHorizonal className="h-4 w-4" />
                    {sendMessageMutation.isPending ? 'Enviando...' : 'Enviar mensagem'}
                  </Button>
                </div>
              </div>
            </>
          )}
        </Card>
      </div>
    </div>
  )
}
