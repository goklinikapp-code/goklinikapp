import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { Bell, Edit3, Plus, Send, Timer, Workflow } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import toast from 'react-hot-toast'
import { z } from 'zod'

import {
  cancelScheduledNotification,
  clearNotificationCampaignLogs,
  createNotificationTemplate,
  createWorkflow,
  getNotificationCampaignLogs,
  getNotificationTemplates,
  getScheduledNotifications,
  getWorkflows,
  scheduleMassMessage,
  searchNotificationRecipients,
  sendMassMessage,
  updateNotificationTemplate,
  updateWorkflow,
  type AudienceSegment,
  type SendTargetMode,
  type UpsertNotificationTemplatePayload,
  type UpsertWorkflowPayload,
} from '@/api/automations'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Modal } from '@/components/ui/Modal'
import { Select } from '@/components/ui/Select'
import { TextArea } from '@/components/ui/TextArea'
import type { NotificationRecipientOption, NotificationTemplateOption, WorkflowItem, WorkflowTriggerType } from '@/types'

const variables = ['{{name}}', '{{date}}', '{{procedure}}']

const blastSchema = z.object({
  segment: z.enum(['all_patients', 'future_appointments', 'inactive_patients']),
  title: z.string().trim().min(3, 'Informe um título com pelo menos 3 caracteres').max(80, 'Máximo de 80 caracteres'),
  body: z.string().min(10, 'Mensagem muito curta'),
})

type BlastForm = z.infer<typeof blastSchema>

type WorkflowFormState = {
  id?: string
  name: string
  trigger_type: WorkflowTriggerType
  trigger_offset: string
  template: string
  is_active: boolean
}

type ScheduleFormState = {
  run_at: string
  segment: AudienceSegment
  title: string
  body: string
}

type TemplateFormState = {
  id?: string
  code: string
  title_template: string
  body_template: string
  is_active: boolean
}

const segmentLabels: Record<string, string> = {
  all_patients: 'Todos os pacientes',
  future_appointments: 'Pacientes com consulta futura',
  inactive_patients: 'Pacientes inativos',
  individual_patient: 'Paciente específico',
}

const triggerLabels: Record<WorkflowTriggerType, string> = {
  appointment_created: 'Consulta criada/confirmada',
  reminder_before: 'Lembrete antes da consulta',
  post_op_followup: 'Follow-up pós-operatório',
}

function statusLabel(status: string) {
  if (status === 'sent') return 'Enviado'
  if (status === 'error') return 'Erro'
  if (status === 'rate_limited') return 'Limitado'
  return 'Ignorado'
}

function channelLabel(channel: string) {
  if (channel === 'push') return 'Notificação push'
  return channel || '-'
}

function eventLabel(eventCode?: string) {
  if (!eventCode) return '-'
  if (eventCode === 'manual_push_campaign') return 'Disparo manual'
  if (eventCode === 'manual_scheduled_campaign') return 'Disparo agendado'
  if (eventCode === 'appointment_confirmation') return 'Confirmação de consulta'
  if (eventCode === 'appointment_reminder_24h') return 'Lembrete de consulta'
  if (eventCode === 'postop_daily_alert') return 'Acompanhamento pós-operatório'
  if (eventCode === 'direct_push') return 'Envio direto'
  return eventCode
}

function errorLabel(message?: string) {
  if (!message) return '-'
  if (message === 'Firebase messaging unavailable.') {
    return 'Serviço de push indisponível no momento.'
  }
  if (message === 'No active push tokens for user.') {
    return 'Paciente sem notificações ativas no aplicativo.'
  }
  return message
}

function extractApiError(error: unknown, fallback: string) {
  if (isAxiosError(error)) {
    const payload = error.response?.data as
      | { detail?: string; error?: string; body?: string[] | string }
      | undefined
    if (typeof payload?.detail === 'string' && payload.detail.trim()) return payload.detail
    if (typeof payload?.error === 'string' && payload.error.trim()) return payload.error
    if (Array.isArray(payload?.body) && payload.body.length > 0) return payload.body.join(', ')
    if (typeof payload?.body === 'string' && payload.body.trim()) return payload.body
  }
  return fallback
}

function formatLocalDatetimeInput(date: Date) {
  const copy = new Date(date.getTime() - date.getTimezoneOffset() * 60_000)
  return copy.toISOString().slice(0, 16)
}

function initialWorkflowForm(): WorkflowFormState {
  return {
    name: '',
    trigger_type: 'appointment_created',
    trigger_offset: '',
    template: '',
    is_active: true,
  }
}

function initialTemplateForm(): TemplateFormState {
  return {
    code: '',
    title_template: '',
    body_template: '',
    is_active: true,
  }
}

export default function AutomationsPage() {
  const queryClient = useQueryClient()
  const [targetMode, setTargetMode] = useState<SendTargetMode>('segment')
  const [workflowModalOpen, setWorkflowModalOpen] = useState(false)
  const [templateModalOpen, setTemplateModalOpen] = useState(false)
  const [scheduleModalOpen, setScheduleModalOpen] = useState(false)
  const [logsPage, setLogsPage] = useState(1)
  const [recipientQuery, setRecipientQuery] = useState('')
  const [debouncedRecipientQuery, setDebouncedRecipientQuery] = useState('')
  const [selectedRecipient, setSelectedRecipient] = useState<NotificationRecipientOption | null>(null)
  const [workflowForm, setWorkflowForm] = useState<WorkflowFormState>(initialWorkflowForm)
  const [templateForm, setTemplateForm] = useState<TemplateFormState>(initialTemplateForm)
  const [scheduleForm, setScheduleForm] = useState<ScheduleFormState>({
    run_at: formatLocalDatetimeInput(new Date(Date.now() + 60 * 60 * 1000)),
    segment: 'all_patients',
    title: 'Mensagem da clínica',
    body: '',
  })

  const {
    register,
    handleSubmit,
    setValue,
    control,
    formState: { errors },
  } = useForm<BlastForm>({
    resolver: zodResolver(blastSchema),
    defaultValues: {
      segment: 'all_patients',
      title: 'Mensagem da clínica',
      body: 'Olá {{name}}, confirmamos sua consulta em {{date}} para {{procedure}}.',
    },
  })

  const titleValue = useWatch({
    control,
    name: 'title',
  }) || ''

  const bodyValue = useWatch({
    control,
    name: 'body',
  }) || ''
  const segmentValue = useWatch({
    control,
    name: 'segment',
  })

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setDebouncedRecipientQuery(recipientQuery.trim())
    }, 250)
    return () => window.clearTimeout(timer)
  }, [recipientQuery])

  const { data: workflows = [] } = useQuery({
    queryKey: ['automation-workflows'],
    queryFn: getWorkflows,
  })

  const { data: templates = [] } = useQuery({
    queryKey: ['notification-templates'],
    queryFn: getNotificationTemplates,
  })
  const activeTemplates = useMemo(() => templates.filter((template) => template.is_active), [templates])

  const logsPageSize = 10
  const { data: campaignLogsPage } = useQuery({
    queryKey: ['automation-campaign-logs', logsPage, logsPageSize],
    queryFn: () => getNotificationCampaignLogs({ page: logsPage, pageSize: logsPageSize }),
  })
  const campaignLogs = campaignLogsPage?.results || []
  const logsTotalCount = campaignLogsPage?.count || 0
  const logsTotalPages = Math.max(1, Math.ceil(logsTotalCount / logsPageSize))
  const canGoToPreviousLogsPage = logsPage > 1
  const canGoToNextLogsPage = logsPage < logsTotalPages

  useEffect(() => {
    if (logsPage > logsTotalPages) {
      setLogsPage(logsTotalPages)
    }
  }, [logsPage, logsTotalPages])

  const { data: scheduled = [] } = useQuery({
    queryKey: ['automation-scheduled'],
    queryFn: getScheduledNotifications,
  })

  const { data: recipientSearchPage, isFetching: isSearchingRecipients } = useQuery({
    queryKey: ['notification-recipient-search', debouncedRecipientQuery],
    queryFn: () => searchNotificationRecipients({ query: debouncedRecipientQuery, page: 1, pageSize: 8 }),
    enabled: targetMode === 'patient' && debouncedRecipientQuery.length >= 2,
  })
  const recipientSearchResults = recipientSearchPage?.results || []

  const sendMutation = useMutation({
    mutationFn: sendMassMessage,
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['automation-campaign-logs'] })
      if (result.campaign_status === 'no_recipients') {
        toast('Nenhum paciente do segmento possui token push ativo.')
        return
      }
      if (result.campaign_status === 'partial') {
        toast.success(`Envio parcial: ${result.sent} enviados, ${result.error} falharam.`)
        return
      }
      if (result.campaign_status === 'error') {
        toast.error(`Falha no envio: 0 enviados, ${result.error} falharam.`)
        return
      }
      toast.success(`Enviado para ${result.sent} paciente(s).`)
    },
    onError: (error) => {
      toast.error(extractApiError(error, 'Falha ao enviar disparo'))
    },
  })

  const createWorkflowMutation = useMutation({
    mutationFn: createWorkflow,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['automation-workflows'] })
      toast.success('Workflow criado com sucesso.')
      setWorkflowModalOpen(false)
    },
    onError: (error) => {
      toast.error(extractApiError(error, 'Falha ao criar workflow.'))
    },
  })

  const updateWorkflowMutation = useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: Partial<UpsertWorkflowPayload> }) => updateWorkflow(id, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['automation-workflows'] })
      toast.success('Workflow atualizado com sucesso.')
      setWorkflowModalOpen(false)
    },
    onError: (error) => {
      toast.error(extractApiError(error, 'Falha ao atualizar workflow.'))
    },
  })

  const createTemplateMutation = useMutation({
    mutationFn: createNotificationTemplate,
    onSuccess: (template) => {
      queryClient.invalidateQueries({ queryKey: ['notification-templates'] })
      toast.success('Template criado com sucesso.')
      if (workflowModalOpen) {
        setWorkflowForm((prev) => ({ ...prev, template: template.id }))
      }
      setTemplateModalOpen(false)
    },
    onError: (error) => {
      toast.error(extractApiError(error, 'Falha ao criar template.'))
    },
  })

  const updateTemplateMutation = useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: Partial<UpsertNotificationTemplatePayload> }) =>
      updateNotificationTemplate(id, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['notification-templates'] })
      queryClient.invalidateQueries({ queryKey: ['automation-workflows'] })
      toast.success('Template atualizado com sucesso.')
      setTemplateModalOpen(false)
    },
    onError: (error) => {
      toast.error(extractApiError(error, 'Falha ao atualizar template.'))
    },
  })

  const scheduleMutation = useMutation({
    mutationFn: scheduleMassMessage,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['automation-scheduled'] })
      toast.success('Disparo agendado com sucesso.')
      setScheduleModalOpen(false)
    },
    onError: (error) => {
      toast.error(extractApiError(error, 'Falha ao agendar disparo.'))
    },
  })

  const cancelScheduledMutation = useMutation({
    mutationFn: cancelScheduledNotification,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['automation-scheduled'] })
      toast.success('Agendamento cancelado.')
    },
    onError: (error) => {
      toast.error(extractApiError(error, 'Falha ao cancelar agendamento.'))
    },
  })

  const clearLogsMutation = useMutation({
    mutationFn: () => clearNotificationCampaignLogs('errors'),
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['automation-campaign-logs'] })
      setLogsPage(1)
      toast.success(`${result.deleted_count} registro(s) de erro removido(s).`)
    },
    onError: (error) => {
      toast.error(extractApiError(error, 'Falha ao limpar histórico de erros.'))
    },
  })

  const credits = useMemo(() => Math.ceil((bodyValue?.length || 0) / 70) * 18, [bodyValue])

  const onSubmit = (values: BlastForm) => {
    if (targetMode === 'patient') {
      if (!selectedRecipient) {
        toast.error('Selecione um paciente para envio individual.')
        return
      }
      if (!selectedRecipient.has_active_push_token) {
        toast.error('Este paciente não tem push ativo no aplicativo.')
        return
      }
      sendMutation.mutate({
        targetMode: 'patient',
        patientId: selectedRecipient.id,
        title: values.title,
        body: values.body,
        channel: 'push',
      })
      return
    }

    sendMutation.mutate({
      targetMode: 'segment',
      segment: values.segment,
      title: values.title,
      body: values.body,
      channel: 'push',
    })
  }

  const handleInsertVariable = (value: string) => {
    setValue('body', `${bodyValue} ${value}`.trim(), { shouldValidate: true })
  }

  const openCreateWorkflow = () => {
    setWorkflowForm(initialWorkflowForm())
    setWorkflowModalOpen(true)
  }

  const openCreateTemplate = () => {
    setTemplateForm(initialTemplateForm())
    setTemplateModalOpen(true)
  }

  const openEditTemplate = (template: NotificationTemplateOption) => {
    setTemplateForm({
      id: template.id,
      code: template.code,
      title_template: template.title_template,
      body_template: template.body_template,
      is_active: template.is_active,
    })
    setTemplateModalOpen(true)
  }

  const openEditWorkflow = (workflow: WorkflowItem) => {
    setWorkflowForm({
      id: workflow.id,
      name: workflow.name,
      trigger_type: workflow.trigger_type,
      trigger_offset: workflow.trigger_offset || '',
      template: workflow.template || '',
      is_active: workflow.is_active,
    })
    setWorkflowModalOpen(true)
  }

  const handleSaveWorkflow = () => {
    if (!workflowForm.name.trim()) {
      toast.error('Informe o nome do workflow.')
      return
    }
    if (workflowForm.trigger_type !== 'appointment_created' && !workflowForm.trigger_offset.trim()) {
      toast.error('Informe o offset do workflow, por exemplo 24h ou 7d.')
      return
    }

    const payload = {
      name: workflowForm.name.trim(),
      trigger_type: workflowForm.trigger_type,
      trigger_offset: workflowForm.trigger_type === 'appointment_created' ? '' : workflowForm.trigger_offset.trim(),
      template: workflowForm.template || null,
      is_active: workflowForm.is_active,
    }

    if (workflowForm.id) {
      updateWorkflowMutation.mutate({ id: workflowForm.id, payload })
      return
    }
    createWorkflowMutation.mutate(payload)
  }

  const handleToggleWorkflow = (workflow: WorkflowItem) => {
    updateWorkflowMutation.mutate({
      id: workflow.id,
      payload: { is_active: !workflow.is_active },
    })
  }

  const handleSaveTemplate = () => {
    if (!templateForm.code.trim()) {
      toast.error('Informe o código do template.')
      return
    }
    if (!templateForm.title_template.trim()) {
      toast.error('Informe o título do template.')
      return
    }
    if (!templateForm.body_template.trim()) {
      toast.error('Informe o corpo do template.')
      return
    }

    const payload: UpsertNotificationTemplatePayload = {
      code: templateForm.code.trim().toLowerCase(),
      title_template: templateForm.title_template.trim(),
      body_template: templateForm.body_template.trim(),
      is_active: templateForm.is_active,
    }

    if (templateForm.id) {
      updateTemplateMutation.mutate({ id: templateForm.id, payload })
      return
    }
    createTemplateMutation.mutate(payload)
  }

  const openScheduleModal = () => {
    if (targetMode === 'patient') {
      toast('Agendamento para paciente específico será disponibilizado em breve.')
      return
    }
    setScheduleForm((prev) => ({
      ...prev,
      run_at: formatLocalDatetimeInput(new Date(Date.now() + 60 * 60 * 1000)),
      segment: segmentValue || 'all_patients',
      body: bodyValue,
      title: 'Mensagem da clínica',
    }))
    setScheduleModalOpen(true)
  }

  const handleSchedule = () => {
    if (!scheduleForm.run_at) {
      toast.error('Informe data e hora do envio.')
      return
    }
    const parsedDate = new Date(scheduleForm.run_at)
    if (Number.isNaN(parsedDate.getTime())) {
      toast.error('Data/hora inválida.')
      return
    }

    scheduleMutation.mutate({
      run_at: parsedDate.toISOString(),
      segment: scheduleForm.segment,
      title: scheduleForm.title.trim(),
      body: scheduleForm.body.trim(),
    })
  }

  return (
    <div className="space-y-5">
      <SectionHeader title="Disparo em Massa" subtitle="Gerencie campanhas, workflows e histórico de comunicação." />

      <div className="grid gap-4 lg:grid-cols-12">
        <Card className="lg:col-span-8">
          <form className="space-y-3" onSubmit={handleSubmit(onSubmit)}>
            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Tipo de Envio</label>
                <Select
                  value={targetMode}
                  onChange={(event) => {
                    const value = event.target.value as SendTargetMode
                    setTargetMode(value)
                    if (value === 'segment') {
                      setRecipientQuery('')
                      setDebouncedRecipientQuery('')
                      setSelectedRecipient(null)
                    }
                  }}
                >
                  <option value="segment">Em massa (segmento)</option>
                  <option value="patient">Paciente específico</option>
                </Select>
              </div>

              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Segmento de Público</label>
                {targetMode === 'segment' ? (
                  <Select {...register('segment')}>
                    <option value="all_patients">Todos os pacientes</option>
                    <option value="future_appointments">Pacientes com consulta futura</option>
                    <option value="inactive_patients">Pacientes inativos</option>
                  </Select>
                ) : (
                  <Input
                    value={recipientQuery}
                    onChange={(event) => {
                      setRecipientQuery(event.target.value)
                      setSelectedRecipient(null)
                    }}
                    placeholder="Busque por nome, e-mail ou telefone"
                  />
                )}
                {errors.segment ? <p className="caption mt-1 text-danger">{errors.segment.message}</p> : null}
              </div>
            </div>

            {targetMode === 'patient' ? (
              <div className="space-y-2 rounded-lg border border-slate-200 p-3">
                {selectedRecipient ? (
                  <div className="rounded-md bg-slate-50 p-2 text-sm text-slate-700">
                    <p className="font-semibold text-night">{selectedRecipient.full_name}</p>
                    <p>{selectedRecipient.email}</p>
                    <p className={selectedRecipient.has_active_push_token ? 'text-emerald-600' : 'text-danger'}>
                      {selectedRecipient.has_active_push_token
                        ? `Push ativo (${selectedRecipient.active_push_tokens})`
                        : 'Sem push ativo no aplicativo'}
                    </p>
                  </div>
                ) : null}

                {!selectedRecipient && recipientQuery.trim().length >= 2 ? (
                  <div className="max-h-44 overflow-auto rounded-md border border-slate-200">
                    {isSearchingRecipients ? (
                      <p className="p-2 text-sm text-slate-500">Buscando pacientes...</p>
                    ) : recipientSearchResults.length > 0 ? (
                      recipientSearchResults.map((item) => (
                        <button
                          key={item.id}
                          type="button"
                          className="w-full border-b border-slate-100 px-3 py-2 text-left text-sm last:border-b-0 hover:bg-slate-50"
                          onClick={() => {
                            setSelectedRecipient(item)
                            setRecipientQuery(item.full_name)
                            setDebouncedRecipientQuery(item.full_name)
                          }}
                        >
                          <p className="font-medium text-night">{item.full_name}</p>
                          <p className="text-xs text-slate-600">{item.email}</p>
                          <p className={`text-xs ${item.has_active_push_token ? 'text-emerald-600' : 'text-danger'}`}>
                            {item.has_active_push_token
                              ? `Push ativo (${item.active_push_tokens})`
                              : 'Sem push ativo'}
                          </p>
                        </button>
                      ))
                    ) : (
                      <p className="p-2 text-sm text-slate-500">Nenhum paciente encontrado.</p>
                    )}
                  </div>
                ) : null}
                {targetMode === 'patient' ? (
                  <p className="caption">Digite ao menos 2 caracteres para buscar paciente.</p>
                ) : null}
              </div>
            ) : null}

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Título da Notificação</label>
              <Input {...register('title')} />
              {errors.title ? <p className="caption mt-1 text-danger">{errors.title.message}</p> : null}
            </div>

            <div>
              <p className="mb-2 text-xs font-medium text-slate-600">Variáveis</p>
              <div className="flex flex-wrap gap-2">
                {variables.map((item) => (
                  <button
                    key={item}
                    type="button"
                    onClick={() => handleInsertVariable(item)}
                    className="rounded-full bg-tealIce px-3 py-1 text-xs font-medium text-primary"
                  >
                    {item}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Corpo da Mensagem</label>
              <TextArea rows={5} {...register('body')} />
              {errors.body ? <p className="caption mt-1 text-danger">{errors.body.message}</p> : null}
              <p className="caption mt-1">
                {bodyValue.length} caracteres | Créditos estimados: {credits}
              </p>
            </div>

            <div className="flex justify-end gap-2">
              <Button type="button" variant="secondary" onClick={openScheduleModal}>
                <Timer className="h-4 w-4" />
                Agendar Disparo
              </Button>
              <Button type="submit" disabled={sendMutation.isPending}>
                <Send className="h-4 w-4" />
                {sendMutation.isPending ? 'Enviando...' : 'Enviar Agora'}
              </Button>
            </div>
          </form>
        </Card>

        <Card className="lg:col-span-4">
          <p className="overline mb-3">Pré-visualização</p>
          <div className="mx-auto w-[230px] rounded-[28px] border-[10px] border-night bg-white p-3 shadow-xl">
            <div className="rounded-[18px] bg-slate-100 p-3">
              <div className="rounded-xl border border-slate-200 bg-white p-3">
                <p className="text-xs font-semibold text-night">GoKlinik</p>
                <p className="mt-1 text-sm font-semibold text-night">{titleValue}</p>
                <p className="mt-1 text-sm text-slate-600">{bodyValue}</p>
              </div>
            </div>
          </div>
        </Card>
      </div>

      <Card padded={false}>
        <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
          <h2 className="section-heading">Workflows Automatizados</h2>
          <Button variant="secondary" onClick={openCreateWorkflow}>
            <Plus className="h-4 w-4" />
            Novo Workflow
          </Button>
        </div>
        <div className="grid gap-3 p-4 md:grid-cols-2 xl:grid-cols-3">
          {workflows.map((workflow) => {
            const isActive = workflow.is_active
            return (
              <Card key={workflow.id} className="border border-slate-100">
                <div className="mb-3 flex items-center justify-between">
                  <Badge status={isActive ? 'active' : 'inactive'}>{isActive ? 'ATIVO' : 'INATIVO'}</Badge>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      className="rounded-md border border-slate-200 p-1.5 text-slate-600 hover:bg-slate-50"
                      onClick={() => openEditWorkflow(workflow)}
                    >
                      <Edit3 className="h-4 w-4" />
                    </button>
                    <button
                      type="button"
                      className={`relative inline-flex h-6 w-11 items-center rounded-full ${
                        isActive ? 'bg-secondary' : 'bg-slate-300'
                      }`}
                      onClick={() => handleToggleWorkflow(workflow)}
                    >
                      <span
                        className={`inline-block h-4 w-4 transform rounded-full bg-white transition ${
                          isActive ? 'translate-x-6' : 'translate-x-1'
                        }`}
                      />
                    </button>
                  </div>
                </div>
                <p className="text-sm font-semibold text-night">{workflow.name}</p>
                <p className="mt-3 inline-flex items-center gap-2 text-xs text-slate-600">
                  <Workflow className="h-3.5 w-3.5" /> TRIGGER: {triggerLabels[workflow.trigger_type]}
                </p>
                <p className="mt-2 inline-flex items-center gap-2 text-xs text-slate-600">
                  <Timer className="h-3.5 w-3.5" /> OFFSET: {workflow.trigger_offset || '-'}
                </p>
                <p className="mt-2 inline-flex items-center gap-2 text-xs text-slate-600">
                  <Send className="h-3.5 w-3.5" /> TEMPLATE: {workflow.template_code || 'Padrão automático'}
                </p>
              </Card>
            )
          })}
        </div>
      </Card>

      <Card padded={false}>
        <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
          <h2 className="section-heading">Templates de Mensagem</h2>
          <Button variant="secondary" onClick={openCreateTemplate}>
            <Plus className="h-4 w-4" />
            Novo Template
          </Button>
        </div>
        <div className="grid gap-3 p-4 md:grid-cols-2 xl:grid-cols-3">
          {templates.length === 0 ? (
            <Card className="border border-dashed border-slate-200 bg-slate-50 text-sm text-slate-600">
              Nenhum template personalizado criado ainda.
            </Card>
          ) : (
            templates.map((template) => (
              <Card key={template.id} className="border border-slate-100">
                <div className="mb-2 flex items-center justify-between">
                  <Badge status={template.is_active ? 'active' : 'inactive'}>
                    {template.is_active ? 'ATIVO' : 'INATIVO'}
                  </Badge>
                  <button
                    type="button"
                    className="rounded-md border border-slate-200 p-1.5 text-slate-600 hover:bg-slate-50"
                    onClick={() => openEditTemplate(template)}
                  >
                    <Edit3 className="h-4 w-4" />
                  </button>
                </div>
                <p className="text-sm font-semibold text-night">{template.code}</p>
                <p className="mt-2 line-clamp-2 text-xs text-slate-600">{template.title_template}</p>
                <p className="mt-2 line-clamp-3 text-xs text-slate-500">{template.body_template}</p>
              </Card>
            ))
          )}
        </div>
      </Card>

      <Card padded={false}>
        <div className="border-b border-slate-100 px-5 py-4">
          <h2 className="section-heading">Agendamentos</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">DATA/HORA</th>
                <th className="px-4 py-3 text-left overline">SEGMENTO</th>
                <th className="px-4 py-3 text-left overline">STATUS</th>
                <th className="px-4 py-3 text-left overline">AÇÃO</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {scheduled.map((item) => (
                <tr key={item.id}>
                  <td className="px-4 py-3 text-sm text-slate-600">
                    {new Date(item.run_at).toLocaleString('pt-BR')}
                  </td>
                  <td className="px-4 py-3 text-sm text-slate-600">{segmentLabels[item.segment]}</td>
                  <td className="px-4 py-3 text-sm text-slate-600">{item.status}</td>
                  <td className="px-4 py-3 text-sm text-slate-600">
                    <Button
                      size="sm"
                      variant="secondary"
                      disabled={item.status !== 'pending' || cancelScheduledMutation.isPending}
                      onClick={() => cancelScheduledMutation.mutate(item.id)}
                    >
                      Cancelar
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <Card padded={false}>
        <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
          <h2 className="section-heading">Histórico de Envios</h2>
          <Button
            variant="secondary"
            size="sm"
            onClick={() => clearLogsMutation.mutate()}
            disabled={clearLogsMutation.isPending}
          >
            {clearLogsMutation.isPending ? 'Limpando...' : 'Limpar Erros Antigos'}
          </Button>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">DATA</th>
                <th className="px-4 py-3 text-left overline">CANAL</th>
                <th className="px-4 py-3 text-left overline">SEGMENTO</th>
                <th className="px-4 py-3 text-left overline">STATUS</th>
                <th className="px-4 py-3 text-left overline">EVENTO</th>
                <th className="px-4 py-3 text-left overline">ERRO</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {campaignLogs.map((item) => (
                <tr key={item.id}>
                  <td className="px-4 py-3 text-sm text-slate-600">{new Date(item.created_at).toLocaleDateString('pt-BR')}</td>
                  <td className="px-4 py-3 text-sm text-slate-600">
                    <span className="inline-flex items-center gap-2">
                      <Bell className="h-4 w-4 text-primary" />
                      {channelLabel(item.channel)}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-slate-600">
                    {item.segment ? segmentLabels[item.segment] || item.segment : '-'}
                  </td>
                  <td className="px-4 py-3">
                    <Badge status={item.status === 'sent' ? 'confirmed' : item.status === 'rate_limited' ? 'pending' : 'cancelled'}>
                      {statusLabel(item.status)}
                    </Badge>
                  </td>
                  <td className="px-4 py-3 text-sm text-slate-600">{eventLabel(item.event_code)}</td>
                  <td className="px-4 py-3 text-sm text-slate-600">{errorLabel(item.error_message)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="flex items-center justify-between border-t border-slate-100 px-4 py-3 text-sm text-slate-600">
          <span>{logsTotalCount} envio(s) no histórico</span>
          <div className="flex items-center gap-2">
            <Button
              variant="secondary"
              size="sm"
              disabled={!canGoToPreviousLogsPage}
              onClick={() => setLogsPage((prev) => Math.max(1, prev - 1))}
            >
              Anterior
            </Button>
            <span>
              Página {logsPage} de {logsTotalPages}
            </span>
            <Button
              variant="secondary"
              size="sm"
              disabled={!canGoToNextLogsPage}
              onClick={() => setLogsPage((prev) => Math.min(logsTotalPages, prev + 1))}
            >
              Próxima
            </Button>
          </div>
        </div>
      </Card>

      <Modal
        isOpen={workflowModalOpen}
        onClose={() => setWorkflowModalOpen(false)}
        title={workflowForm.id ? 'Editar Workflow' : 'Novo Workflow'}
      >
        <div className="space-y-3">
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Nome</label>
            <Input
              value={workflowForm.name}
              onChange={(event) => setWorkflowForm((prev) => ({ ...prev, name: event.target.value }))}
              placeholder="Ex: Lembrete 24h antes"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Trigger</label>
            <Select
              value={workflowForm.trigger_type}
              onChange={(event) =>
                setWorkflowForm((prev) => ({
                  ...prev,
                  trigger_type: event.target.value as WorkflowTriggerType,
                  trigger_offset: event.target.value === 'appointment_created' ? '' : prev.trigger_offset,
                }))
              }
            >
              <option value="appointment_created">Consulta criada/confirmada</option>
              <option value="reminder_before">Lembrete antes da consulta</option>
              <option value="post_op_followup">Follow-up pós-operatório</option>
            </Select>
          </div>

          {workflowForm.trigger_type !== 'appointment_created' ? (
            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Offset</label>
              <Input
                value={workflowForm.trigger_offset}
                onChange={(event) => setWorkflowForm((prev) => ({ ...prev, trigger_offset: event.target.value }))}
                placeholder="Ex: 24h, 7d, 30m"
              />
            </div>
          ) : null}

          <div>
            <div className="mb-1 flex items-center justify-between">
              <label className="block text-xs font-medium text-slate-600">Template</label>
              <button
                type="button"
                className="text-xs font-medium text-primary hover:underline"
                onClick={openCreateTemplate}
              >
                Criar template
              </button>
            </div>
            <Select
              value={workflowForm.template}
              onChange={(event) => setWorkflowForm((prev) => ({ ...prev, template: event.target.value }))}
            >
              <option value="">Padrão automático do sistema</option>
              {activeTemplates.map((template) => (
                <option key={template.id} value={template.id}>
                  {template.code}
                </option>
              ))}
            </Select>
            <p className="caption mt-1">
              Se nenhum template for escolhido, o sistema usa a mensagem padrão para esse tipo de workflow.
            </p>
          </div>

          <label className="inline-flex items-center gap-2 text-sm text-slate-700">
            <input
              type="checkbox"
              checked={workflowForm.is_active}
              onChange={(event) => setWorkflowForm((prev) => ({ ...prev, is_active: event.target.checked }))}
            />
            Workflow ativo
          </label>

          <div className="flex justify-end gap-2">
            <Button variant="secondary" onClick={() => setWorkflowModalOpen(false)}>
              Fechar
            </Button>
            <Button
              onClick={handleSaveWorkflow}
              disabled={createWorkflowMutation.isPending || updateWorkflowMutation.isPending}
            >
              Salvar
            </Button>
          </div>
        </div>
      </Modal>

      <Modal
        isOpen={templateModalOpen}
        onClose={() => setTemplateModalOpen(false)}
        title={templateForm.id ? 'Editar Template' : 'Novo Template'}
      >
        <div className="space-y-3">
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Código interno</label>
            <Input
              value={templateForm.code}
              onChange={(event) => setTemplateForm((prev) => ({ ...prev, code: event.target.value }))}
              placeholder="Ex: lembrete_consulta"
            />
            <p className="caption mt-1">Use letras minúsculas, números, "_" ou "-".</p>
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Título da notificação</label>
            <Input
              value={templateForm.title_template}
              onChange={(event) => setTemplateForm((prev) => ({ ...prev, title_template: event.target.value }))}
              placeholder="Ex: Lembrete de consulta"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Corpo da mensagem</label>
            <TextArea
              rows={4}
              value={templateForm.body_template}
              onChange={(event) => setTemplateForm((prev) => ({ ...prev, body_template: event.target.value }))}
              placeholder="Ex: Olá {{name}}, sua consulta é em {{date}} às {{time}}."
            />
            <p className="caption mt-1">Variáveis disponíveis: {'{{name}}'}, {'{{date}}'}, {'{{time}}'}, {'{{procedure}}'}.</p>
          </div>

          <label className="inline-flex items-center gap-2 text-sm text-slate-700">
            <input
              type="checkbox"
              checked={templateForm.is_active}
              onChange={(event) => setTemplateForm((prev) => ({ ...prev, is_active: event.target.checked }))}
            />
            Template ativo
          </label>

          <div className="flex justify-end gap-2">
            <Button variant="secondary" onClick={() => setTemplateModalOpen(false)}>
              Fechar
            </Button>
            <Button
              onClick={handleSaveTemplate}
              disabled={createTemplateMutation.isPending || updateTemplateMutation.isPending}
            >
              {createTemplateMutation.isPending || updateTemplateMutation.isPending ? 'Salvando...' : 'Salvar'}
            </Button>
          </div>
        </div>
      </Modal>

      <Modal isOpen={scheduleModalOpen} onClose={() => setScheduleModalOpen(false)} title="Agendar Disparo">
        <div className="space-y-3">
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Data e hora</label>
            <Input
              type="datetime-local"
              value={scheduleForm.run_at}
              onChange={(event) => setScheduleForm((prev) => ({ ...prev, run_at: event.target.value }))}
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Segmento</label>
            <Select
              value={scheduleForm.segment}
              onChange={(event) =>
                setScheduleForm((prev) => ({
                  ...prev,
                  segment: event.target.value as AudienceSegment,
                }))
              }
            >
              <option value="all_patients">Todos os pacientes</option>
              <option value="future_appointments">Pacientes com consulta futura</option>
              <option value="inactive_patients">Pacientes inativos</option>
            </Select>
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Título</label>
            <Input
              value={scheduleForm.title}
              onChange={(event) => setScheduleForm((prev) => ({ ...prev, title: event.target.value }))}
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Mensagem</label>
            <TextArea
              rows={4}
              value={scheduleForm.body}
              onChange={(event) => setScheduleForm((prev) => ({ ...prev, body: event.target.value }))}
            />
          </div>

          <div className="flex justify-end gap-2">
            <Button variant="secondary" onClick={() => setScheduleModalOpen(false)}>
              Fechar
            </Button>
            <Button onClick={handleSchedule} disabled={scheduleMutation.isPending}>
              {scheduleMutation.isPending ? 'Agendando...' : 'Salvar Agendamento'}
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  )
}
