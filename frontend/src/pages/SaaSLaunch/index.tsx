import { useQuery } from '@tanstack/react-query'
import { useMemo, useState } from 'react'

import { getLeads } from '@/api/leads'
import { getSaaSSellers } from '@/api/saas'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Select } from '@/components/ui/Select'
import { formatDate } from '@/utils/format'

export default function SaaSLaunchPage() {
  const [sellerFilter, setSellerFilter] = useState('')
  const [refCodeFilter, setRefCodeFilter] = useState('')
  const [startDateFilter, setStartDateFilter] = useState('')
  const [endDateFilter, setEndDateFilter] = useState('')

  const { data: sellers = [] } = useQuery({
    queryKey: ['saas-sellers'],
    queryFn: getSaaSSellers,
  })

  const { data: leads = [], isLoading } = useQuery({
    queryKey: ['saas-launch-leads', sellerFilter, refCodeFilter, startDateFilter, endDateFilter],
    queryFn: () =>
      getLeads({
        seller: sellerFilter || undefined,
        ref_code: refCodeFilter.trim() || undefined,
        start_date: startDateFilter || undefined,
        end_date: endDateFilter || undefined,
      }),
  })

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
            <Select value={sellerFilter} onChange={(event) => setSellerFilter(event.target.value)}>
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
              onChange={(event) => setRefCodeFilter(event.target.value)}
              placeholder="ABC123XYZ9"
            />
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Data inicial</label>
            <Input type="date" value={startDateFilter} onChange={(event) => setStartDateFilter(event.target.value)} />
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Data final</label>
            <Input type="date" value={endDateFilter} onChange={(event) => setEndDateFilter(event.target.value)} />
          </div>
        </div>
      </Card>

      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <p className="overline">TOTAL DE LEADS</p>
          <p className="mt-2 text-3xl font-bold text-night">{leads.length}</p>
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
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {isLoading ? (
                <tr>
                  <td className="px-4 py-4 text-sm text-slate-500" colSpan={6}>
                    Carregando leads...
                  </td>
                </tr>
              ) : leads.length === 0 ? (
                <tr>
                  <td className="px-4 py-4 text-sm text-slate-500" colSpan={6}>
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
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  )
}
