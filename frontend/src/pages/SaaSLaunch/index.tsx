import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Edit, Trash2, X } from 'lucide-react'
import { useEffect, useMemo, useState, type FormEvent } from 'react'

import { deleteLead, getLeads, updateLead, type Lead, type LeadUpdatePayload } from '@/api/leads'
import { getSaaSSellers } from '@/api/saas'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Select } from '@/components/ui/Select'
import { formatDate } from '@/utils/format'

const LEADS_PAGE_SIZE = 10

export default function SaaSLaunchPage() {
  const queryClient = useQueryClient()
  const [sellerFilter, setSellerFilter] = useState('')
  const [refCodeFilter, setRefCodeFilter] = useState('')
  const [startDateFilter, setStartDateFilter] = useState('')
  const [endDateFilter, setEndDateFilter] = useState('')
  const [page, setPage] = useState(1)
  const [leadToDelete, setLeadToDelete] = useState<Lead | null>(null)
  const [leadToEdit, setLeadToEdit] = useState<Lead | null>(null)
  const [editValues, setEditValues] = useState({ name: '', email: '', phone: '' })
  const [editError, setEditError] = useState('')

  const { data: sellers = [] } = useQuery({
    queryKey: ['saas-sellers'],
    queryFn: getSaaSSellers,
  })

  const { data: leadsData, isLoading } = useQuery({
    queryKey: ['saas-launch-leads', sellerFilter, refCodeFilter, startDateFilter, endDateFilter, page],
    queryFn: () =>
      getLeads({
        seller: sellerFilter || undefined,
        ref_code: refCodeFilter.trim() || undefined,
        start_date: startDateFilter || undefined,
        end_date: endDateFilter || undefined,
        page,
      }),
  })

  const leads = leadsData?.results ?? []
  const totalLeads = leadsData?.count ?? 0
  const totalPages = useMemo(
    () => Math.max(1, Math.ceil(totalLeads / LEADS_PAGE_SIZE)),
    [totalLeads],
  )

  useEffect(() => {
    if (page > totalPages) {
      setPage(totalPages)
    }
  }, [page, totalPages])

  const deleteMutation = useMutation({
    mutationFn: deleteLead,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['saas-launch-leads'] })
    },
  })

  const updateMutation = useMutation({
    mutationFn: ({ leadId, payload }: { leadId: string; payload: LeadUpdatePayload }) =>
      updateLead(leadId, payload),
    onSuccess: () => {
      setLeadToEdit(null)
      setEditError('')
      void queryClient.invalidateQueries({ queryKey: ['saas-launch-leads'] })
    },
    onError: () => {
      setEditError('Não foi possível salvar as alterações. Tente novamente.')
    },
  })

  const handleDelete = () => {
    if (!leadToDelete) return

    deleteMutation.mutate(leadToDelete.id, {
      onSuccess: () => {
        if (leads.length === 1 && page > 1) {
          setPage((current) => current - 1)
        }
        setLeadToDelete(null)
      },
    })
  }

  const openEditModal = (lead: Lead) => {
    setLeadToEdit(lead)
    setEditError('')
    setEditValues({
      name: lead.name,
      email: lead.email,
      phone: lead.phone,
    })
  }

  const handleEditSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!leadToEdit) return

    const payload = {
      name: editValues.name.trim(),
      email: editValues.email.trim(),
      phone: editValues.phone.trim(),
    }

    if (!payload.name || !payload.email || !payload.phone) {
      setEditError('Preencha nome, e-mail e telefone.')
      return
    }

    updateMutation.mutate({
      leadId: leadToEdit.id,
      payload,
    })
  }

  const sellerTotals = useMemo(() => {
    const totals = new Map<string, { name: string; total: number }>()
    leads.forEach((lead) => {
      const sellerId = lead.seller?.id || 'no-seller'
      const sellerName = lead.seller?.name || 'Sem vendedor'
      const current = totals.get(sellerId)
      if (current) {
        current.total += 1
        return
      }
      totals.set(sellerId, { name: sellerName, total: 1 })
    })
    return Array.from(totals.values()).sort((a, b) => b.total - a.total)
  }, [leads])

  const topSeller = sellerTotals.find((item) => item.name !== 'Sem vendedor') || null
  const leadsWithSeller = useMemo(
    () => leads.filter((lead) => Boolean(lead.seller?.id)).length,
    [leads],
  )

  return (
    <div className="space-y-5">
      <SectionHeader
        title="Lançamento"
        subtitle="Acompanhe os leads capturados por vendedor e período."
      />

      <Card>
        <div className="grid gap-3 md:grid-cols-4">
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Vendedor</label>
            <Select
              value={sellerFilter}
              onChange={(event) => {
                setSellerFilter(event.target.value)
                setPage(1)
              }}
            >
              <option value="">Todos</option>
              {sellers.map((seller) => (
                <option key={seller.id} value={seller.id}>
                  {seller.full_name}
                </option>
              ))}
            </Select>
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Ref code</label>
            <Input
              value={refCodeFilter}
              onChange={(event) => {
                setRefCodeFilter(event.target.value)
                setPage(1)
              }}
              placeholder="ABC123XYZ9"
            />
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Data inicial</label>
            <Input
              type="date"
              value={startDateFilter}
              onChange={(event) => {
                setStartDateFilter(event.target.value)
                setPage(1)
              }}
            />
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Data final</label>
            <Input
              type="date"
              value={endDateFilter}
              onChange={(event) => {
                setEndDateFilter(event.target.value)
                setPage(1)
              }}
            />
          </div>
        </div>
      </Card>

      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <p className="overline">TOTAL DE LEADS</p>
          <p className="mt-2 text-3xl font-bold text-night">{totalLeads}</p>
        </Card>
        <Card>
          <p className="overline">TOTAL POR VENDEDOR</p>
          <p className="mt-2 text-3xl font-bold text-night">{leadsWithSeller}</p>
          <p className="caption mt-2">leads vinculados a vendedores</p>
        </Card>
        <Card>
          <p className="overline">MAIOR CONVERSÃO</p>
          <p className="mt-2 text-lg font-bold text-night">{topSeller?.name || 'Sem dados'}</p>
          <p className="caption mt-2">{topSeller ? `${topSeller.total} leads` : '-'}</p>
        </Card>
      </div>

      <Card padded={false}>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">NOME</th>
                <th className="px-4 py-3 text-left overline">E-MAIL</th>
                <th className="px-4 py-3 text-left overline">TELEFONE</th>
                <th className="px-4 py-3 text-left overline">VENDEDOR</th>
                <th className="px-4 py-3 text-left overline">REF CODE</th>
                <th className="px-4 py-3 text-left overline">DATA</th>
                <th className="px-4 py-3 text-left overline">AÇÕES</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {isLoading ? (
                <tr>
                  <td className="px-4 py-4 text-sm text-slate-500" colSpan={7}>
                    Carregando leads...
                  </td>
                </tr>
              ) : leads.length === 0 ? (
                <tr>
                  <td className="px-4 py-4 text-sm text-slate-500" colSpan={7}>
                    Nenhum lead encontrado para os filtros selecionados.
                  </td>
                </tr>
              ) : (
                leads.map((lead) => (
                  <tr key={lead.id}>
                    <td className="px-4 py-3 text-sm text-night">{lead.name}</td>
                    <td className="px-4 py-3 text-sm text-slate-600">{lead.email}</td>
                    <td className="px-4 py-3 text-sm text-slate-600">{lead.phone}</td>
                    <td className="px-4 py-3 text-sm text-slate-600">{lead.seller?.name || 'Sem vendedor'}</td>
                    <td className="px-4 py-3 text-sm text-slate-600">{lead.ref_code || '-'}</td>
                    <td className="px-4 py-3 text-sm text-slate-600">{formatDate(lead.created_at)}</td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <button
                          type="button"
                          aria-label={`Editar lead ${lead.name}`}
                          className="cursor-pointer rounded-md p-1 text-blue-500 transition-colors hover:bg-blue-50 hover:text-blue-700"
                          onClick={() => openEditModal(lead)}
                          disabled={updateMutation.isPending || deleteMutation.isPending}
                        >
                          <Edit size={18} />
                        </button>
                        <button
                          type="button"
                          aria-label={`Excluir lead ${lead.name}`}
                          className="cursor-pointer rounded-md p-1 text-red-500 transition-colors hover:bg-red-50 hover:text-red-700"
                          onClick={() => setLeadToDelete(lead)}
                          disabled={updateMutation.isPending || deleteMutation.isPending}
                        >
                          <Trash2 size={18} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </Card>

      <div className="flex items-center justify-end gap-2">
        <Button
          variant="secondary"
          onClick={() => setPage((current) => Math.max(1, current - 1))}
          disabled={page === 1 || isLoading}
        >
          Anterior
        </Button>
        <span className="text-sm text-slate-600">
          Página {page} de {totalPages}
        </span>
        <Button
          variant="secondary"
          onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
          disabled={page >= totalPages || isLoading}
        >
          Próxima
        </Button>
      </div>

      {leadToDelete ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <button
            type="button"
            aria-label="Fechar confirmação de exclusão"
            className="absolute inset-0 bg-night/45 transition-opacity duration-200"
            onClick={() => setLeadToDelete(null)}
          />
          <div className="relative z-10 w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl transition-all duration-200 ease-out">
            <h3 className="text-xl font-semibold text-night">Excluir lead</h3>
            <p className="mt-3 text-sm leading-relaxed text-slate-600">
              Tem certeza que deseja excluir este lead? Essa ação não pode ser desfeita.
            </p>
            <div className="mt-6 flex items-center justify-end gap-2">
              <Button
                type="button"
                variant="secondary"
                onClick={() => setLeadToDelete(null)}
                disabled={deleteMutation.isPending}
              >
                Cancelar
              </Button>
              <Button
                type="button"
                variant="danger"
                onClick={handleDelete}
                disabled={deleteMutation.isPending}
              >
                {deleteMutation.isPending ? 'Excluindo...' : 'Excluir'}
              </Button>
            </div>
          </div>
        </div>
      ) : null}

      {leadToEdit ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <button
            type="button"
            aria-label="Fechar edição de lead"
            className="absolute inset-0 bg-night/45 transition-opacity duration-200"
            onClick={() => {
              setLeadToEdit(null)
              setEditError('')
            }}
          />
          <div className="relative z-10 w-full max-w-lg rounded-2xl bg-white p-6 shadow-2xl transition-all duration-200 ease-out">
            <div className="mb-4 flex items-center justify-between">
              <h3 className="text-xl font-semibold text-night">Editar lead</h3>
              <button
                type="button"
                className="rounded-md p-1 text-slate-500 transition-colors hover:bg-slate-100 hover:text-slate-700"
                onClick={() => {
                  setLeadToEdit(null)
                  setEditError('')
                }}
                aria-label="Fechar modal de edição"
              >
                <X size={18} />
              </button>
            </div>

            <form className="space-y-3" onSubmit={handleEditSubmit}>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Nome</label>
                <Input
                  value={editValues.name}
                  onChange={(event) =>
                    setEditValues((current) => ({ ...current, name: event.target.value }))
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">E-mail</label>
                <Input
                  type="email"
                  value={editValues.email}
                  onChange={(event) =>
                    setEditValues((current) => ({ ...current, email: event.target.value }))
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Telefone</label>
                <Input
                  value={editValues.phone}
                  onChange={(event) =>
                    setEditValues((current) => ({ ...current, phone: event.target.value }))
                  }
                />
              </div>
              {editError ? <p className="text-sm text-danger">{editError}</p> : null}
              <div className="pt-2">
                <Button type="submit" fullWidth disabled={updateMutation.isPending}>
                  {updateMutation.isPending ? 'Salvando...' : 'Salvar alterações'}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  )
}
