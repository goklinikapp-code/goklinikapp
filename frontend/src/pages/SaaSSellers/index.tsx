import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { Copy, Pencil, Plus, Trash2, UserRoundCheck, UserRoundX } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { z } from 'zod'

import {
  createSaaSSeller,
  deleteSaaSSeller,
  getSaaSSeller,
  getSaaSSellers,
  type SaaSSeller,
  updateSaaSSeller,
} from '@/api/saas'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Modal } from '@/components/ui/Modal'
import { getSellerSignupLink } from '@/utils/baseUrl'
import { formatDate } from '@/utils/format'

const sellerSchema = z.object({
  full_name: z.string().min(3, 'Informe o nome completo'),
  email: z.string().email('Informe um e-mail válido'),
  phone: z.string().optional(),
})

type SellerFormValues = z.infer<typeof sellerSchema>

function extractErrorMessage(error: unknown, fallback: string): string {
  if (!isAxiosError(error)) return fallback
  const data = error.response?.data as Record<string, unknown> | undefined
  if (!data) return fallback
  if (typeof data.detail === 'string' && data.detail.trim()) return data.detail
  const firstValue = Object.values(data)[0]
  if (typeof firstValue === 'string' && firstValue.trim()) return firstValue
  if (Array.isArray(firstValue) && firstValue.length > 0) return String(firstValue[0])
  return fallback
}

export default function SaaSSellersPage() {
  const queryClient = useQueryClient()
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false)
  const [isDetailModalOpen, setIsDetailModalOpen] = useState(false)
  const [isEditModalOpen, setIsEditModalOpen] = useState(false)
  const [selectedSeller, setSelectedSeller] = useState<SaaSSeller | null>(null)
  const [isLoadingDetail, setIsLoadingDetail] = useState(false)
  const [sellerToDelete, setSellerToDelete] = useState<SaaSSeller | null>(null)

  const { data: sellers = [], isLoading } = useQuery({
    queryKey: ['saas-sellers'],
    queryFn: getSaaSSellers,
  })

  const {
    register: registerCreate,
    handleSubmit: handleSubmitCreate,
    reset: resetCreate,
    formState: { errors: createErrors },
  } = useForm<SellerFormValues>({
    resolver: zodResolver(sellerSchema),
    defaultValues: {
      full_name: '',
      email: '',
      phone: '',
    },
  })

  const {
    register: registerEdit,
    handleSubmit: handleSubmitEdit,
    reset: resetEdit,
    formState: { errors: editErrors },
  } = useForm<SellerFormValues>({
    resolver: zodResolver(sellerSchema),
    defaultValues: {
      full_name: '',
      email: '',
      phone: '',
    },
  })

  const createMutation = useMutation({
    mutationFn: createSaaSSeller,
    onSuccess: () => {
      toast.success('Vendedor cadastrado com sucesso')
      setIsCreateModalOpen(false)
      resetCreate()
      void queryClient.invalidateQueries({ queryKey: ['saas-sellers'] })
      void queryClient.invalidateQueries({ queryKey: ['saas-dashboard'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, 'Não foi possível cadastrar o vendedor'))
    },
  })

  const updateMutation = useMutation({
    mutationFn: ({ sellerId, payload }: { sellerId: string; payload: Partial<SellerFormValues> & { is_active?: boolean } }) =>
      updateSaaSSeller(sellerId, payload),
    onSuccess: (seller) => {
      setSelectedSeller(seller)
      toast.success('Vendedor atualizado com sucesso')
      setIsEditModalOpen(false)
      void queryClient.invalidateQueries({ queryKey: ['saas-sellers'] })
      void queryClient.invalidateQueries({ queryKey: ['saas-dashboard'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, 'Não foi possível atualizar o vendedor'))
    },
  })

  const deleteMutation = useMutation({
    mutationFn: deleteSaaSSeller,
    onSuccess: () => {
      toast.success('Vendedor excluído com sucesso')
      setSellerToDelete(null)
      setIsDetailModalOpen(false)
      void queryClient.invalidateQueries({ queryKey: ['saas-sellers'] })
      void queryClient.invalidateQueries({ queryKey: ['saas-dashboard'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, 'Não foi possível excluir o vendedor'))
    },
  })

  const totalInvites = useMemo(
    () => sellers.reduce((acc, seller) => acc + seller.metrics.invites_sent, 0),
    [sellers],
  )
  const totalLeads = useMemo(
    () => sellers.reduce((acc, seller) => acc + seller.metrics.leads_total, 0),
    [sellers],
  )

  const openSellerDetail = async (sellerId: string) => {
    setIsLoadingDetail(true)
    setIsDetailModalOpen(true)
    try {
      const seller = await getSaaSSeller(sellerId)
      setSelectedSeller(seller)
    } catch (error) {
      toast.error(extractErrorMessage(error, 'Não foi possível carregar os dados'))
      setSelectedSeller(null)
      setIsDetailModalOpen(false)
    } finally {
      setIsLoadingDetail(false)
    }
  }

  const openEditModal = (seller: SaaSSeller) => {
    setSelectedSeller(seller)
    resetEdit({
      full_name: seller.full_name,
      email: seller.email,
      phone: seller.phone || '',
    })
    setIsEditModalOpen(true)
  }

  const getInviteLink = (seller: Pick<SaaSSeller, 'ref_code' | 'invite_code'>): string =>
    getSellerSignupLink(seller.ref_code || seller.invite_code)
  const selectedSellerInviteLink = selectedSeller ? getInviteLink(selectedSeller) : ''

  const handleCopyInviteLink = async (link: string) => {
    try {
      await navigator.clipboard.writeText(link)
      toast.success('Link copiado')
    } catch {
      toast.error('Não foi possível copiar o link')
    }
  }

  const handleToggleSellerStatus = (seller: SaaSSeller) => {
    updateMutation.mutate({
      sellerId: seller.id,
      payload: { is_active: !seller.is_active },
    })
  }

  const onCreateSubmit = (values: SellerFormValues) => {
    createMutation.mutate({
      full_name: values.full_name.trim(),
      email: values.email.trim(),
      phone: values.phone?.trim(),
      is_active: true,
    })
  }

  const onEditSubmit = (values: SellerFormValues) => {
    if (!selectedSeller) return
    updateMutation.mutate({
      sellerId: selectedSeller.id,
      payload: {
        full_name: values.full_name.trim(),
        email: values.email.trim(),
        phone: values.phone?.trim(),
      },
    })
  }

  if (isLoading) {
    return <p className="body-copy">Carregando vendedores...</p>
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title="Vendedores SaaS"
        subtitle="Gerencie vendedores, links de convite e métricas de conversão."
        actions={(
          <Button onClick={() => setIsCreateModalOpen(true)}>
            <Plus className="h-4 w-4" />
            Novo Vendedor
          </Button>
        )}
      />

      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <p className="overline">TOTAL DE VENDEDORES</p>
          <p className="mt-2 text-3xl font-bold text-night">{sellers.length}</p>
          <p className="caption mt-2">
            {sellers.filter((seller) => seller.is_active).length} ativos
          </p>
        </Card>
        <Card>
          <p className="overline">CONVITES ENVIADOS</p>
          <p className="mt-2 text-3xl font-bold text-night">{totalInvites}</p>
          <p className="caption mt-2">Via links de vendedor</p>
        </Card>
        <Card>
          <p className="overline">LEADS CAPTURADOS</p>
          <p className="mt-2 text-3xl font-bold text-night">{totalLeads}</p>
          <p className="caption mt-2">Leads vinculados por ref_code</p>
        </Card>
      </div>

      <Card padded={false}>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">VENDEDOR</th>
                <th className="px-4 py-3 text-left overline">CONVITES</th>
                <th className="px-4 py-3 text-left overline">LEADS REAIS</th>
                <th className="px-4 py-3 text-left overline">LINK</th>
                <th className="px-4 py-3 text-left overline">STATUS</th>
                <th className="px-4 py-3 text-left overline">AÇÕES</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {sellers.map((seller) => {
                const inviteLink = getInviteLink(seller)
                return (
                  <tr key={seller.id}>
                    <td className="px-4 py-3">
                      <p className="text-sm font-semibold text-night">{seller.full_name}</p>
                      <p className="caption">{seller.email}</p>
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-600">
                      <p>Enviados: {seller.metrics.invites_sent}</p>
                      <p>Aceitos: {seller.metrics.invites_accepted}</p>
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-600">
                      {seller.metrics.leads_total}
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-600">
                      <div className="flex items-center gap-2">
                        <span className="max-w-[220px] truncate">{inviteLink}</span>
                        <Button
                          type="button"
                          size="sm"
                          variant="secondary"
                          onClick={() => void handleCopyInviteLink(inviteLink)}
                        >
                          <Copy className="h-3.5 w-3.5" />
                        </Button>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <Badge status={seller.is_active ? 'active' : 'inactive'}>
                        {seller.is_active ? 'ATIVO' : 'INATIVO'}
                      </Badge>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap gap-2">
                        <Button size="sm" variant="secondary" onClick={() => void openSellerDetail(seller.id)}>
                          Detalhes
                        </Button>
                        <Button size="sm" variant="secondary" onClick={() => openEditModal(seller)}>
                          <Pencil className="h-3.5 w-3.5" />
                          Editar
                        </Button>
                        <Button
                          size="sm"
                          variant="secondary"
                          onClick={() => handleToggleSellerStatus(seller)}
                          disabled={updateMutation.isPending}
                        >
                          {seller.is_active ? (
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
                        <Button size="sm" variant="danger" onClick={() => setSellerToDelete(seller)}>
                          <Trash2 className="h-3.5 w-3.5" />
                          Excluir
                        </Button>
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </Card>

      <Modal isOpen={isCreateModalOpen} onClose={() => setIsCreateModalOpen(false)} title="Cadastrar vendedor">
        <form className="space-y-4" onSubmit={handleSubmitCreate(onCreateSubmit)}>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Nome completo</label>
            <Input {...registerCreate('full_name')} placeholder="Nome do vendedor" />
            {createErrors.full_name ? <p className="caption mt-1 text-danger">{createErrors.full_name.message}</p> : null}
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">E-mail</label>
            <Input {...registerCreate('email')} type="email" placeholder="nome@empresa.com" />
            {createErrors.email ? <p className="caption mt-1 text-danger">{createErrors.email.message}</p> : null}
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Telefone</label>
            <Input {...registerCreate('phone')} placeholder="+55 11 99999-9999" />
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="secondary" onClick={() => setIsCreateModalOpen(false)}>
              Cancelar
            </Button>
            <Button type="submit" disabled={createMutation.isPending}>
              {createMutation.isPending ? 'Salvando...' : 'Salvar vendedor'}
            </Button>
          </div>
        </form>
      </Modal>

      <Modal isOpen={isEditModalOpen} onClose={() => setIsEditModalOpen(false)} title="Editar vendedor">
        <form className="space-y-4" onSubmit={handleSubmitEdit(onEditSubmit)}>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Nome completo</label>
            <Input {...registerEdit('full_name')} placeholder="Nome do vendedor" />
            {editErrors.full_name ? <p className="caption mt-1 text-danger">{editErrors.full_name.message}</p> : null}
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">E-mail</label>
            <Input {...registerEdit('email')} type="email" placeholder="nome@empresa.com" />
            {editErrors.email ? <p className="caption mt-1 text-danger">{editErrors.email.message}</p> : null}
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Telefone</label>
            <Input {...registerEdit('phone')} placeholder="+55 11 99999-9999" />
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
      </Modal>

      <Modal
        isOpen={isDetailModalOpen}
        onClose={() => setIsDetailModalOpen(false)}
        title={selectedSeller ? `Detalhes de ${selectedSeller.full_name}` : 'Detalhes do vendedor'}
      >
        {isLoadingDetail ? (
          <p className="body-copy">Carregando vendedor...</p>
        ) : selectedSeller ? (
          <div className="space-y-4">
            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <p className="overline">E-MAIL</p>
                <p className="text-sm text-night">{selectedSeller.email}</p>
              </div>
              <div>
                <p className="overline">TELEFONE</p>
                <p className="text-sm text-night">{selectedSeller.phone || 'Não informado'}</p>
              </div>
              <div>
                <p className="overline">CÓDIGO DE CONVITE</p>
                <p className="text-sm text-night">{selectedSeller.invite_code}</p>
              </div>
              <div>
                <p className="overline">CRIADO EM</p>
                <p className="text-sm text-night">{formatDate(selectedSeller.created_at)}</p>
              </div>
            </div>

            <div className="rounded-lg border border-slate-200 bg-slate-50 p-3">
              <p className="caption">Link de convite</p>
              <p className="mt-1 break-all text-sm text-night">{selectedSellerInviteLink}</p>
              <Button className="mt-2" size="sm" variant="secondary" onClick={() => void handleCopyInviteLink(selectedSellerInviteLink)}>
                <Copy className="h-3.5 w-3.5" />
                Copiar link
              </Button>
            </div>

            <div className="grid gap-3 md:grid-cols-3">
              <Card className="p-3">
                <p className="overline">ENVIADOS</p>
                <p className="mt-1 text-2xl font-bold text-night">{selectedSeller.metrics.invites_sent}</p>
              </Card>
              <Card className="p-3">
                <p className="overline">ACEITOS</p>
                <p className="mt-1 text-2xl font-bold text-night">{selectedSeller.metrics.invites_accepted}</p>
              </Card>
              <Card className="p-3">
                <p className="overline">CADASTROS</p>
                <p className="mt-1 text-2xl font-bold text-night">{selectedSeller.metrics.leads_total}</p>
              </Card>
            </div>
          </div>
        ) : null}
      </Modal>

      <Modal
        isOpen={Boolean(sellerToDelete)}
        onClose={() => setSellerToDelete(null)}
        title="Excluir vendedor"
      >
        <p className="body-copy">
          Deseja realmente excluir <strong>{sellerToDelete?.full_name}</strong>? Esta ação não pode ser desfeita.
        </p>
        <div className="mt-4 flex justify-end gap-2">
          <Button type="button" variant="secondary" onClick={() => setSellerToDelete(null)}>
            Cancelar
          </Button>
          <Button
            type="button"
            variant="danger"
            onClick={() => sellerToDelete && deleteMutation.mutate(sellerToDelete.id)}
            disabled={deleteMutation.isPending}
          >
            {deleteMutation.isPending ? 'Excluindo...' : 'Excluir vendedor'}
          </Button>
        </div>
      </Modal>
    </div>
  )
}
