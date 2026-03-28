import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { Pencil, Plus, Send, UserRoundX, UserRoundCheck } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { z } from 'zod'

import {
  createSaaSClient,
  getSaaSClient,
  getSaaSClients,
  getSaaSSellers,
  type SaaSClient,
  type SaaSClientCreateInviteResponse,
  type SaaSClientPlan,
  type SaaSClientUpdatePayload,
  updateSaaSClient,
} from '@/api/saas'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Modal } from '@/components/ui/Modal'
import { Select } from '@/components/ui/Select'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { formatDate } from '@/utils/format'

const createClientSchema = z
  .object({
    mode: z.enum(['direct', 'invite']),
    clinic_name: z.string().min(3, 'Informe o nome da clínica'),
    plan: z.enum(['starter', 'professional', 'enterprise']),
    clinic_addresses_raw: z.string().optional(),
    owner_full_name: z.string().min(3, 'Informe o nome do responsável'),
    owner_email: z.string().email('Informe um e-mail válido'),
    owner_phone: z.string().optional(),
    owner_tax_number: z.string().optional(),
    password: z.string().optional(),
    seller_id: z.string().optional(),
  })
  .superRefine((values, ctx) => {
    if (values.mode === 'direct' && (!values.password || values.password.length < 8)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['password'],
        message: 'A senha deve ter no mínimo 8 caracteres no cadastro direto.',
      })
    }
  })

const editClientSchema = z.object({
  clinic_name: z.string().min(3, 'Informe o nome da clínica'),
  plan: z.enum(['starter', 'professional', 'enterprise']),
  clinic_addresses_raw: z.string().optional(),
  owner_full_name: z.string().min(3, 'Informe o nome do responsável'),
  owner_email: z.string().email('Informe um e-mail válido'),
  owner_phone: z.string().optional(),
  owner_tax_number: z.string().optional(),
  password: z.string().optional(),
  is_active: z.boolean(),
})

type CreateClientValues = z.infer<typeof createClientSchema>
type EditClientValues = z.infer<typeof editClientSchema>

function planLabel(plan: SaaSClientPlan): string {
  if (plan === 'starter') return 'Starter'
  if (plan === 'professional') return 'Professional'
  return 'Enterprise'
}

function splitAddresses(value?: string): string[] {
  if (!value) return []
  return value
    .split(';')
    .map((item) => item.trim())
    .filter(Boolean)
}

function extractErrorMessage(error: unknown, fallback: string): string {
  if (!isAxiosError(error)) return fallback
  const data = error.response?.data as Record<string, unknown> | undefined
  if (!data) return fallback
  if (typeof data.detail === 'string' && data.detail.trim()) return data.detail
  const firstValue = Object.values(data)[0]
  if (typeof firstValue === 'string' && firstValue.trim()) return firstValue
  if (Array.isArray(firstValue) && firstValue.length > 0) return String(firstValue[0])
  if (firstValue && typeof firstValue === 'object') {
    const nested = Object.values(firstValue as Record<string, unknown>)[0]
    if (typeof nested === 'string' && nested.trim()) return nested
    if (Array.isArray(nested) && nested.length > 0) return String(nested[0])
  }
  return fallback
}

export default function SaaSClientsPage() {
  const queryClient = useQueryClient()
  const language = usePreferencesStore((state) => state.language)

  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false)
  const [isDetailModalOpen, setIsDetailModalOpen] = useState(false)
  const [isEditModalOpen, setIsEditModalOpen] = useState(false)
  const [isLoadingDetail, setIsLoadingDetail] = useState(false)
  const [selectedClient, setSelectedClient] = useState<SaaSClient | null>(null)

  const { data: clients = [], isLoading } = useQuery({
    queryKey: ['saas-clients'],
    queryFn: getSaaSClients,
  })

  const { data: sellers = [] } = useQuery({
    queryKey: ['saas-sellers'],
    queryFn: getSaaSSellers,
  })

  const {
    register: registerCreate,
    handleSubmit: handleSubmitCreate,
    watch: watchCreate,
    reset: resetCreate,
    formState: { errors: createErrors },
  } = useForm<CreateClientValues>({
    resolver: zodResolver(createClientSchema),
    defaultValues: {
      mode: 'direct',
      clinic_name: '',
      plan: 'starter',
      clinic_addresses_raw: '',
      owner_full_name: '',
      owner_email: '',
      owner_phone: '',
      owner_tax_number: '',
      password: '',
      seller_id: '',
    },
  })

  const {
    register: registerEdit,
    handleSubmit: handleSubmitEdit,
    reset: resetEdit,
    formState: { errors: editErrors },
  } = useForm<EditClientValues>({
    resolver: zodResolver(editClientSchema),
    defaultValues: {
      clinic_name: '',
      plan: 'starter',
      clinic_addresses_raw: '',
      owner_full_name: '',
      owner_email: '',
      owner_phone: '',
      owner_tax_number: '',
      password: '',
      is_active: true,
    },
  })

  const createMutation = useMutation({
    mutationFn: createSaaSClient,
    onSuccess: (response) => {
      setIsCreateModalOpen(false)
      resetCreate()

      const isInvite = (response as SaaSClientCreateInviteResponse).mode === 'invite'
      if (isInvite) {
        toast.success('Convite enviado para o e-mail da clínica')
      } else {
        toast.success('Cliente cadastrado com sucesso')
      }

      void queryClient.invalidateQueries({ queryKey: ['saas-clients'] })
      void queryClient.invalidateQueries({ queryKey: ['saas-dashboard'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, 'Não foi possível cadastrar o cliente'))
    },
  })

  const updateMutation = useMutation({
    mutationFn: ({ clientId, payload }: { clientId: string; payload: SaaSClientUpdatePayload }) =>
      updateSaaSClient(clientId, payload),
    onSuccess: (updatedClient) => {
      setSelectedClient(updatedClient)
      toast.success('Cliente atualizado com sucesso')
      setIsEditModalOpen(false)
      void queryClient.invalidateQueries({ queryKey: ['saas-clients'] })
      void queryClient.invalidateQueries({ queryKey: ['saas-dashboard'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, 'Não foi possível atualizar o cliente'))
    },
  })

  const openDetailModal = async (clientId: string) => {
    setIsDetailModalOpen(true)
    setIsLoadingDetail(true)
    try {
      const client = await getSaaSClient(clientId)
      setSelectedClient(client)
    } catch (error) {
      toast.error(extractErrorMessage(error, 'Não foi possível carregar os dados da clínica'))
      setSelectedClient(null)
      setIsDetailModalOpen(false)
    } finally {
      setIsLoadingDetail(false)
    }
  }

  const openEditModal = async (clientId: string) => {
    setIsLoadingDetail(true)
    setIsEditModalOpen(true)
    try {
      const client = await getSaaSClient(clientId)
      setSelectedClient(client)
      resetEdit({
        clinic_name: client.name,
        plan: client.plan,
        clinic_addresses_raw: (client.clinic_addresses || []).join('; '),
        owner_full_name: client.primary_contact_name || '',
        owner_email: client.primary_contact_email || '',
        owner_phone: client.primary_contact_phone || '',
        owner_tax_number: client.primary_contact_tax_number || '',
        password: '',
        is_active: client.is_active,
      })
    } catch (error) {
      toast.error(extractErrorMessage(error, 'Não foi possível carregar os dados da clínica'))
      setSelectedClient(null)
      setIsEditModalOpen(false)
    } finally {
      setIsLoadingDetail(false)
    }
  }

  const onSubmitCreate = (values: CreateClientValues) => {
    createMutation.mutate({
      mode: values.mode,
      clinic_name: values.clinic_name.trim(),
      plan: values.plan,
      clinic_addresses: splitAddresses(values.clinic_addresses_raw),
      owner_full_name: values.owner_full_name.trim(),
      owner_email: values.owner_email.trim(),
      owner_phone: values.owner_phone?.trim(),
      owner_tax_number: values.owner_tax_number?.trim(),
      password: values.password?.trim(),
      seller_id: values.seller_id?.trim() || undefined,
      language,
    })
  }

  const onSubmitEdit = (values: EditClientValues) => {
    if (!selectedClient) return
    updateMutation.mutate({
      clientId: selectedClient.id,
      payload: {
        clinic_name: values.clinic_name.trim(),
        plan: values.plan,
        clinic_addresses: splitAddresses(values.clinic_addresses_raw),
        owner_full_name: values.owner_full_name.trim(),
        owner_email: values.owner_email.trim(),
        owner_phone: values.owner_phone?.trim(),
        owner_tax_number: values.owner_tax_number?.trim(),
        password: values.password?.trim() || undefined,
        is_active: values.is_active,
      },
    })
  }

  const handleToggleClient = (client: SaaSClient) => {
    updateMutation.mutate({
      clientId: client.id,
      payload: { is_active: !client.is_active },
    })
  }

  if (isLoading) {
    return <p className="body-copy">Carregando clientes...</p>
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title="Clientes (Clínicas)"
        subtitle="Gerencie e acompanhe as clínicas que utilizam o GoKlinik."
        actions={(
          <Button onClick={() => setIsCreateModalOpen(true)}>
            <Plus className="h-4 w-4" />
            Cadastrar Cliente
          </Button>
        )}
      />

      <Card padded={false}>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">CLÍNICA</th>
                <th className="px-4 py-3 text-left overline">CONTATO PRINCIPAL</th>
                <th className="px-4 py-3 text-left overline">PLANO</th>
                <th className="px-4 py-3 text-left overline">PACIENTES</th>
                <th className="px-4 py-3 text-left overline">AGEND. 30 DIAS</th>
                <th className="px-4 py-3 text-left overline">STATUS</th>
                <th className="px-4 py-3 text-left overline">CRIAÇÃO</th>
                <th className="px-4 py-3 text-left overline">AÇÕES</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {clients.map((client) => (
                <tr key={client.id}>
                  <td className="px-4 py-3">
                    <p className="text-sm font-semibold text-night">{client.name}</p>
                    <p className="caption">{client.slug}</p>
                  </td>
                  <td className="px-4 py-3 text-sm text-slate-600">
                    <p>{client.primary_contact_name || 'Sem nome'}</p>
                    <p className="caption">{client.primary_contact_email || 'Sem e-mail'}</p>
                  </td>
                  <td className="px-4 py-3">
                    <Badge className="bg-primary/10 text-primary">{planLabel(client.plan)}</Badge>
                  </td>
                  <td className="px-4 py-3 text-sm text-slate-600">{client.patients_count}</td>
                  <td className="px-4 py-3 text-sm text-slate-600">{client.appointments_next_30_days}</td>
                  <td className="px-4 py-3">
                    <Badge status={client.is_active ? 'active' : 'inactive'}>
                      {client.is_active ? 'ATIVA' : 'INATIVA'}
                    </Badge>
                  </td>
                  <td className="px-4 py-3 text-sm text-slate-600">{formatDate(client.created_at)}</td>
                  <td className="px-4 py-3">
                    <div className="flex flex-wrap gap-2">
                      <Button size="sm" variant="secondary" onClick={() => void openDetailModal(client.id)}>
                        Detalhes
                      </Button>
                      <Button size="sm" variant="secondary" onClick={() => void openEditModal(client.id)}>
                        <Pencil className="h-3.5 w-3.5" />
                        Editar
                      </Button>
                      <Button
                        size="sm"
                        variant="secondary"
                        onClick={() => handleToggleClient(client)}
                        disabled={updateMutation.isPending}
                      >
                        {client.is_active ? (
                          <>
                            <UserRoundX className="h-3.5 w-3.5" />
                            Desativar
                          </>
                        ) : (
                          <>
                            <UserRoundCheck className="h-3.5 w-3.5" />
                            Ativar
                          </>
                        )}
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <Modal isOpen={isCreateModalOpen} onClose={() => setIsCreateModalOpen(false)} title="Cadastrar cliente">
        <form className="space-y-4" onSubmit={handleSubmitCreate(onSubmitCreate)}>
          <div className="grid gap-4 md:grid-cols-2">
            <div className="md:col-span-2">
              <label className="mb-1 block text-xs font-medium text-slate-600">Modo de cadastro</label>
              <Select {...registerCreate('mode')}>
                <option value="direct">Cadastro direto (defino a senha)</option>
                <option value="invite">Enviar convite por e-mail</option>
              </Select>
            </div>

            <div className="md:col-span-2">
              <label className="mb-1 block text-xs font-medium text-slate-600">Nome da clínica</label>
              <Input {...registerCreate('clinic_name')} placeholder="Nome da clínica" />
              {createErrors.clinic_name ? (
                <p className="caption mt-1 text-danger">{createErrors.clinic_name.message}</p>
              ) : null}
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Plano</label>
              <Select {...registerCreate('plan')}>
                <option value="starter">Starter</option>
                <option value="professional">Professional</option>
                <option value="enterprise">Enterprise</option>
              </Select>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Vendedor (opcional)</label>
              <Select {...registerCreate('seller_id')}>
                <option value="">Sem vendedor</option>
                {sellers.map((seller) => (
                  <option key={seller.id} value={seller.id}>
                    {seller.full_name}
                  </option>
                ))}
              </Select>
            </div>

            <div className="md:col-span-2">
              <label className="mb-1 block text-xs font-medium text-slate-600">
                Endereços (separe por ponto e vírgula)
              </label>
              <Input {...registerCreate('clinic_addresses_raw')} placeholder="Matriz; Filial 1; Filial 2" />
            </div>

            <div className="md:col-span-2">
              <label className="mb-1 block text-xs font-medium text-slate-600">Responsável principal</label>
              <Input {...registerCreate('owner_full_name')} placeholder="Nome do responsável" />
              {createErrors.owner_full_name ? (
                <p className="caption mt-1 text-danger">{createErrors.owner_full_name.message}</p>
              ) : null}
            </div>

            <div className="md:col-span-2">
              <label className="mb-1 block text-xs font-medium text-slate-600">E-mail do responsável</label>
              <Input {...registerCreate('owner_email')} type="email" placeholder="contato@clinica.com" />
              {createErrors.owner_email ? (
                <p className="caption mt-1 text-danger">{createErrors.owner_email.message}</p>
              ) : null}
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Telefone</label>
              <Input {...registerCreate('owner_phone')} placeholder="+55 11 99999-9999" />
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Número fiscal</label>
              <Input {...registerCreate('owner_tax_number')} placeholder="123456789" />
            </div>

            {watchCreate('mode') === 'direct' ? (
              <div className="md:col-span-2">
                <label className="mb-1 block text-xs font-medium text-slate-600">Senha inicial</label>
                <Input {...registerCreate('password')} type="password" placeholder="Mínimo 8 caracteres" />
                {createErrors.password ? (
                  <p className="caption mt-1 text-danger">{createErrors.password.message}</p>
                ) : null}
              </div>
            ) : (
              <div className="md:col-span-2 rounded-lg border border-secondary/20 bg-secondary/5 p-3 text-sm text-secondary">
                <p className="inline-flex items-center gap-2">
                  <Send className="h-4 w-4" />
                  Um convite será enviado para o e-mail informado. O cliente definirá a senha no link recebido.
                </p>
              </div>
            )}
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="secondary" onClick={() => setIsCreateModalOpen(false)}>
              Cancelar
            </Button>
            <Button type="submit" disabled={createMutation.isPending}>
              {createMutation.isPending ? 'Salvando...' : 'Cadastrar cliente'}
            </Button>
          </div>
        </form>
      </Modal>

      <Modal
        isOpen={isDetailModalOpen}
        onClose={() => setIsDetailModalOpen(false)}
        title={selectedClient ? `Detalhes de ${selectedClient.name}` : 'Detalhes da clínica'}
      >
        {isLoadingDetail ? (
          <p className="body-copy">Carregando dados da clínica...</p>
        ) : selectedClient ? (
          <div className="space-y-4">
            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <p className="overline">CLÍNICA</p>
                <p className="text-sm text-night">{selectedClient.name}</p>
                <p className="caption">{selectedClient.slug}</p>
              </div>
              <div>
                <p className="overline">PLANO</p>
                <p className="text-sm text-night">{planLabel(selectedClient.plan)}</p>
              </div>
              <div>
                <p className="overline">RESPONSÁVEL</p>
                <p className="text-sm text-night">{selectedClient.primary_contact_name || 'Não informado'}</p>
                <p className="caption">{selectedClient.primary_contact_email || 'Sem e-mail'}</p>
              </div>
              <div>
                <p className="overline">CONTATO</p>
                <p className="text-sm text-night">{selectedClient.primary_contact_phone || 'Não informado'}</p>
                <p className="caption">
                  Número fiscal: {selectedClient.primary_contact_tax_number || 'Não informado'}
                </p>
              </div>
              <div>
                <p className="overline">PACIENTES</p>
                <p className="text-sm text-night">{selectedClient.patients_count}</p>
              </div>
              <div>
                <p className="overline">AGENDAMENTOS (30 DIAS)</p>
                <p className="text-sm text-night">{selectedClient.appointments_next_30_days}</p>
              </div>
              <div>
                <p className="overline">STAFF CLÍNICO</p>
                <p className="text-sm text-night">{selectedClient.staff_count}</p>
              </div>
              <div>
                <p className="overline">CRIADA EM</p>
                <p className="text-sm text-night">{formatDate(selectedClient.created_at)}</p>
              </div>
            </div>

            <div className="rounded-lg border border-slate-200 bg-slate-50 p-3">
              <p className="overline">ENDEREÇOS / FILIAIS</p>
              {selectedClient.clinic_addresses.length > 0 ? (
                <ul className="mt-2 space-y-1 text-sm text-night">
                  {selectedClient.clinic_addresses.map((address) => (
                    <li key={address}>• {address}</li>
                  ))}
                </ul>
              ) : (
                <p className="mt-2 text-sm text-slate-500">Nenhum endereço cadastrado.</p>
              )}
            </div>
          </div>
        ) : null}
      </Modal>

      <Modal
        isOpen={isEditModalOpen}
        onClose={() => setIsEditModalOpen(false)}
        title={selectedClient ? `Editar ${selectedClient.name}` : 'Editar cliente'}
      >
        {isLoadingDetail ? (
          <p className="body-copy">Carregando dados da clínica...</p>
        ) : (
          <form className="space-y-4" onSubmit={handleSubmitEdit(onSubmitEdit)}>
            <div className="grid gap-4 md:grid-cols-2">
              <div className="md:col-span-2">
                <label className="mb-1 block text-xs font-medium text-slate-600">Nome da clínica</label>
                <Input {...registerEdit('clinic_name')} placeholder="Nome da clínica" />
                {editErrors.clinic_name ? (
                  <p className="caption mt-1 text-danger">{editErrors.clinic_name.message}</p>
                ) : null}
              </div>

              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Plano</label>
                <Select {...registerEdit('plan')}>
                  <option value="starter">Starter</option>
                  <option value="professional">Professional</option>
                  <option value="enterprise">Enterprise</option>
                </Select>
              </div>

              <div className="flex items-end gap-2">
                <input type="checkbox" {...registerEdit('is_active')} className="h-4 w-4 rounded border-slate-300" />
                <span className="text-sm text-night">Clínica ativa</span>
              </div>

              <div className="md:col-span-2">
                <label className="mb-1 block text-xs font-medium text-slate-600">
                  Endereços (separe por ponto e vírgula)
                </label>
                <Input {...registerEdit('clinic_addresses_raw')} placeholder="Matriz; Filial 1; Filial 2" />
              </div>

              <div className="md:col-span-2">
                <label className="mb-1 block text-xs font-medium text-slate-600">Responsável principal</label>
                <Input {...registerEdit('owner_full_name')} placeholder="Nome do responsável" />
                {editErrors.owner_full_name ? (
                  <p className="caption mt-1 text-danger">{editErrors.owner_full_name.message}</p>
                ) : null}
              </div>

              <div className="md:col-span-2">
                <label className="mb-1 block text-xs font-medium text-slate-600">E-mail do responsável</label>
                <Input {...registerEdit('owner_email')} type="email" placeholder="contato@clinica.com" />
                {editErrors.owner_email ? (
                  <p className="caption mt-1 text-danger">{editErrors.owner_email.message}</p>
                ) : null}
              </div>

              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Telefone</label>
                <Input {...registerEdit('owner_phone')} placeholder="+55 11 99999-9999" />
              </div>

              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Número fiscal</label>
                <Input {...registerEdit('owner_tax_number')} placeholder="123456789" />
              </div>

              <div className="md:col-span-2">
                <label className="mb-1 block text-xs font-medium text-slate-600">
                  Nova senha (opcional)
                </label>
                <Input {...registerEdit('password')} type="password" placeholder="Preencha apenas se quiser alterar" />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <Button type="button" variant="secondary" onClick={() => setIsEditModalOpen(false)}>
                Cancelar
              </Button>
              <Button type="submit" disabled={updateMutation.isPending}>
                {updateMutation.isPending ? 'Salvando...' : 'Salvar alterações'}
              </Button>
            </div>
          </form>
        )}
      </Modal>
    </div>
  )
}
