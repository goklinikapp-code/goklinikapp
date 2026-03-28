import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQuery } from '@tanstack/react-query'
import { BarChart3, Bell, MessageCircle, Plus, Send, Timer, Workflow } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import toast from 'react-hot-toast'
import { z } from 'zod'

import { getWorkflows, sendMassMessage } from '@/api/automations'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Select } from '@/components/ui/Select'
import { TextArea } from '@/components/ui/TextArea'

const variables = ['{{name}}', '{{date}}', '{{procedure}}']

const blastSchema = z.object({
  segment: z.string().min(1, 'Selecione um segmento'),
  channel: z.enum(['whatsapp', 'push']),
  body: z.string().min(10, 'Mensagem muito curta'),
})

type BlastForm = z.infer<typeof blastSchema>

const history = [
  { id: '1', date: '2026-03-22', channel: 'whatsapp', segment: 'Todos os pacientes', status: 'Enviado', openRate: 84 },
  { id: '2', date: '2026-03-21', channel: 'push', segment: 'Pacientes +6 meses', status: 'Erro', openRate: 22 },
  { id: '3', date: '2026-03-20', channel: 'whatsapp', segment: 'Rinoplastia', status: 'Enviado', openRate: 73 },
]

export default function AutomationsPage() {
  const [channel, setChannel] = useState<'whatsapp' | 'push'>('whatsapp')
  const [workflowState, setWorkflowState] = useState<Record<string, boolean>>({})

  const {
    register,
    handleSubmit,
    setValue,
    control,
    formState: { errors },
  } = useForm<BlastForm>({
    resolver: zodResolver(blastSchema),
    defaultValues: {
      segment: 'Todos os pacientes',
      channel: 'whatsapp',
      body: 'Olá {{name}}, confirmamos sua consulta em {{date}} para {{procedure}}.',
    },
  })

  const bodyValue = useWatch({
    control,
    name: 'body',
  }) || ''

  const { data: workflows = [] } = useQuery({
    queryKey: ['automation-workflows'],
    queryFn: getWorkflows,
  })

  const sendMutation = useMutation({
    mutationFn: sendMassMessage,
    onSuccess: () => {
      toast.success('Disparo enviado com sucesso')
    },
    onError: () => {
      toast.error('Falha ao enviar disparo')
    },
  })

  const credits = useMemo(() => Math.ceil((bodyValue?.length || 0) / 70) * 18, [bodyValue])

  const onSubmit = (values: BlastForm) => {
    sendMutation.mutate(values)
  }

  const handleInsertVariable = (value: string) => {
    setValue('body', `${bodyValue} ${value}`.trim(), { shouldValidate: true })
  }

  return (
    <div className="space-y-5">
      <SectionHeader title="Disparo em Massa" subtitle="Gerencie campanhas, workflows e histórico de comunicação." />

      <div className="grid gap-4 lg:grid-cols-12">
        <Card className="lg:col-span-8">
          <form className="space-y-3" onSubmit={handleSubmit(onSubmit)}>
            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Segmento de Público</label>
                <Select {...register('segment')}>
                  <option value="Todos os pacientes">Todos os pacientes</option>
                  <option value="Pacientes com +6 meses sem consulta">Pacientes com +6 meses sem consulta</option>
                  <option value="Por especialidade">Por especialidade</option>
                </Select>
                {errors.segment ? <p className="caption mt-1 text-danger">{errors.segment.message}</p> : null}
              </div>

              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Canal de Envio</label>
                <div className="inline-flex rounded-lg border border-slate-200 bg-slate-50 p-1">
                  <button
                    type="button"
                    className={`rounded-md px-4 py-2 text-sm ${channel === 'whatsapp' ? 'bg-secondary text-white' : 'text-slate-600'}`}
                    onClick={() => {
                      setChannel('whatsapp')
                      setValue('channel', 'whatsapp')
                    }}
                  >
                    WhatsApp
                  </button>
                  <button
                    type="button"
                    className={`rounded-md px-4 py-2 text-sm ${channel === 'push' ? 'bg-primary text-white' : 'text-slate-600'}`}
                    onClick={() => {
                      setChannel('push')
                      setValue('channel', 'push')
                    }}
                  >
                    Push
                  </button>
                </div>
              </div>
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
              <Button type="button" variant="secondary" onClick={() => toast('Agendamento de disparo será disponibilizado em breve.')}>
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
              {channel === 'whatsapp' ? (
                <div className="rounded-xl bg-[#DCF8C6] p-3 text-sm text-slate-700">
                  {bodyValue}
                </div>
              ) : (
                <div className="rounded-xl border border-slate-200 bg-white p-3">
                  <p className="text-xs font-semibold text-night">GoKlinik</p>
                  <p className="mt-1 text-sm text-slate-600">{bodyValue}</p>
                </div>
              )}
            </div>
          </div>
        </Card>
      </div>

      <Card padded={false}>
        <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
          <h2 className="section-heading">Workflows Automatizados</h2>
          <Button variant="secondary" onClick={() => toast('Criação de workflow customizado em breve.')}>
            <Plus className="h-4 w-4" />
            Novo Workflow
          </Button>
        </div>
        <div className="grid gap-3 p-4 md:grid-cols-2 xl:grid-cols-3">
          {workflows.map((workflow) => {
            const isActive = workflowState[workflow.id] ?? workflow.is_active
            return (
              <Card key={workflow.id} className="border border-slate-100">
                <div className="mb-3 flex items-center justify-between">
                  <Badge status={isActive ? 'active' : 'inactive'}>{isActive ? 'ATIVO' : 'INATIVO'}</Badge>
                  <button
                    type="button"
                    className={`relative inline-flex h-6 w-11 items-center rounded-full ${
                      isActive ? 'bg-secondary' : 'bg-slate-300'
                    }`}
                    onClick={() =>
                      setWorkflowState((prev) => ({
                        ...prev,
                        [workflow.id]: !isActive,
                      }))
                    }
                  >
                    <span
                      className={`inline-block h-4 w-4 transform rounded-full bg-white transition ${
                        isActive ? 'translate-x-6' : 'translate-x-1'
                      }`}
                    />
                  </button>
                </div>
                <p className="text-sm font-semibold text-night">{workflow.title}</p>
                <p className="mt-3 text-xs text-slate-600 inline-flex items-center gap-2"><Workflow className="h-3.5 w-3.5" /> TRIGGER: {workflow.trigger}</p>
                <p className="mt-2 text-xs text-slate-600 inline-flex items-center gap-2"><Send className="h-3.5 w-3.5" /> AÇÃO: {workflow.action}</p>
              </Card>
            )
          })}
        </div>
      </Card>

      <Card padded={false}>
        <div className="border-b border-slate-100 px-5 py-4">
          <h2 className="section-heading">Histórico de Envios</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">DATA</th>
                <th className="px-4 py-3 text-left overline">CANAL</th>
                <th className="px-4 py-3 text-left overline">SEGMENTO</th>
                <th className="px-4 py-3 text-left overline">STATUS</th>
                <th className="px-4 py-3 text-left overline">TAXA DE ABERTURA</th>
                <th className="px-4 py-3 text-left overline">AÇÕES</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {history.map((item) => (
                <tr key={item.id}>
                  <td className="px-4 py-3 text-sm text-slate-600">{item.date}</td>
                  <td className="px-4 py-3 text-sm text-slate-600">
                    <span className="inline-flex items-center gap-2">
                      {item.channel === 'whatsapp' ? <MessageCircle className="h-4 w-4 text-secondary" /> : <Bell className="h-4 w-4 text-primary" />}
                      {item.channel}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-slate-600">{item.segment}</td>
                  <td className="px-4 py-3"><Badge status={item.status === 'Enviado' ? 'confirmed' : 'cancelled'}>{item.status}</Badge></td>
                  <td className="px-4 py-3">
                    <div className="h-2 rounded-full bg-slate-100">
                      <div className="h-2 rounded-full bg-primary" style={{ width: `${item.openRate}%` }} />
                    </div>
                  </td>
                  <td className="px-4 py-3"><BarChart3 className="h-4 w-4 text-slate-500" /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="flex items-center justify-between border-t border-slate-100 px-4 py-3 text-sm text-slate-600">
          <span>1-10 de 42 envios</span>
          <div className="space-x-2"><button>Anterior</button><button>Próxima</button></div>
        </div>
      </Card>
    </div>
  )
}
