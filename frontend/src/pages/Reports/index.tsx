import { useQuery } from '@tanstack/react-query'
import { Download, FileSpreadsheet } from 'lucide-react'
import { Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import toast from 'react-hot-toast'

import { getReportsData } from '@/api/reports'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Select } from '@/components/ui/Select'
import { getLocaleForLanguage, t as translate, type TranslationKey } from '@/i18n/system'
import { useAuthStore } from '@/stores/authStore'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { useTenantStore } from '@/stores/tenantStore'
import { formatCurrency } from '@/utils/format'

export default function ReportsPage() {
  const language = usePreferencesStore((state) => state.language)
  const t = (key: TranslationKey) => translate(language, key)
  const locale = getLocaleForLanguage(language)
  const tenantConfigName = useTenantStore((state) => state.tenantConfig.name)
  const tenantName = useAuthStore((state) => state.tenant?.name || state.user?.tenant?.name)
  const clinicName = tenantConfigName || tenantName || t('reports_title')

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['reports-data', language],
    queryFn: () => getReportsData(language),
  })

  if (isLoading) {
    return <p className="body-copy">{t('reports_loading')}</p>
  }

  if (isError) {
    return (
      <div className="space-y-3">
        <p className="body-copy">{t('reports_load_error')}</p>
        <p className="caption">{error instanceof Error ? error.message : t('reports_unexpected_error')}</p>
        <Button onClick={() => void refetch()}>{t('reports_retry')}</Button>
      </div>
    )
  }

  if (!data) {
    return <p className="body-copy">{t('reports_empty')}</p>
  }

  const handleExport = () => {
    const header = [
      t('reports_date'),
      t('reports_patient'),
      t('reports_professional'),
      t('reports_specialty'),
      t('reports_value'),
      t('reports_status'),
    ]
    const rows = data.procedures.map((item) => [
      item.date,
      item.patient,
      item.professional,
      item.specialty,
      item.value,
      item.status,
    ])

    const csv = [header, ...rows]
      .map((line) => line.map((col) => `"${String(col).replace(/"/g, '""')}"`).join(','))
      .join('\n')

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `goklinik-relatório-${new Date().toISOString().slice(0, 10)}.csv`
    link.click()
    URL.revokeObjectURL(url)
    toast.success(t('reports_export_success'))
  }

  const periodFormatter = new Intl.DateTimeFormat(locale, { month: 'long', year: 'numeric' })
  const currentMonthLabel = periodFormatter.format(new Date())
  const previousMonthLabel = periodFormatter.format(new Date(new Date().getFullYear(), new Date().getMonth() - 1, 1))

  const kpiLabels: Record<(typeof data.kpis)[number]['key'], string> = {
    total_revenue: t('reports_kpi_total_revenue'),
    average_ticket: t('reports_kpi_average_ticket'),
    procedures_total: t('reports_kpi_procedures_total'),
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title={clinicName}
        subtitle={t('reports_subtitle')}
        actions={
          <>
            <Button variant="secondary" onClick={handleExport}>
              <Download className="h-4 w-4" />
              {t('reports_export')}
            </Button>
            <Button onClick={() => void refetch()}>
              <FileSpreadsheet className="h-4 w-4" />
              {t('reports_generate')}
            </Button>
          </>
        }
      />

      <Card>
        <div className="grid gap-3 md:grid-cols-4">
          <Select>
            <option>{t('reports_period')}</option>
            <option>{currentMonthLabel}</option>
            <option>{previousMonthLabel}</option>
          </Select>
          <Select>
            <option>{t('reports_professional')}</option>
            <option>{t('reports_all')}</option>
          </Select>
          <Select>
            <option>{t('reports_specialty')}</option>
            <option>{t('reports_all')}</option>
          </Select>
          <Button variant="accent">{t('reports_apply_filters')}</Button>
        </div>
      </Card>

      <div className="grid gap-4 md:grid-cols-3">
        {data.kpis.map((item) => (
          <Card key={item.key}>
            <p className="overline">{kpiLabels[item.key]}</p>
            <p className="mt-2 text-3xl font-bold text-night">
              {item.key === 'total_revenue' || item.key === 'average_ticket'
                ? formatCurrency(item.value)
                : item.value.toLocaleString(locale)}
            </p>
            <span className="mt-2 inline-flex rounded-full bg-secondary/15 px-2 py-1 text-xs font-semibold text-secondary">
              {item.variation}
            </span>
          </Card>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-12">
        <Card className="lg:col-span-7" padded={false}>
          <div className="border-b border-slate-100 p-5">
            <h2 className="section-heading">{t('reports_patient_evolution')}</h2>
          </div>
          <div className="h-[310px] p-4">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={data.patientEvolution}>
                <XAxis dataKey="week" axisLine={false} tickLine={false} />
                <YAxis axisLine={false} tickLine={false} />
                <Tooltip />
                <Line type="monotone" dataKey="new" stroke="#1A1F2E" strokeWidth={3} dot={{ r: 4 }} />
                <Line type="monotone" dataKey="recurring" stroke="#4A7C59" strokeWidth={3} dot={{ r: 4 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card className="lg:col-span-5" padded={false}>
          <div className="border-b border-slate-100 p-5">
            <h2 className="section-heading">{t('reports_performance_by_professional')}</h2>
          </div>
          <div className="space-y-3 p-4">
            {data.professionals.map((professional) => {
              const topRevenue = data.professionals[0]?.revenue || 1
              const revenuePercent = Math.round((professional.revenue / topRevenue) * 100)
              return (
                <div key={professional.id} className="rounded-lg border border-slate-100 p-3">
                  <div className="mb-2 flex items-start justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <Avatar name={professional.name} className="h-9 w-9" />
                      <div>
                        <p className="text-sm font-semibold text-night">{professional.name}</p>
                        <p className="caption">{professional.specialty}</p>
                      </div>
                    </div>
                    <Badge className="bg-primary/10 text-primary">{t('reports_nps')} {professional.nps}</Badge>
                  </div>
                  <div className="grid grid-cols-3 gap-2 text-xs text-slate-600">
                    <span>{t('reports_patients')}: {professional.patients}</span>
                    <span>{t('reports_revenue')}: {formatCurrency(professional.revenue)}</span>
                    <span>{t('reports_reop_rate')}: {professional.reop}</span>
                  </div>
                  <div className="mt-2 h-2 rounded-full bg-slate-100">
                    <div className="h-2 rounded-full bg-primary" style={{ width: `${revenuePercent}%` }} />
                  </div>
                </div>
              )
            })}
          </div>
        </Card>
      </div>

      <Card padded={false}>
        <div className="border-b border-slate-100 p-5">
          <h2 className="section-heading">{t('reports_procedure_details')}</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">{t('reports_date')}</th>
                <th className="px-4 py-3 text-left overline">{t('reports_patient')}</th>
                <th className="px-4 py-3 text-left overline">{t('reports_professional')}</th>
                <th className="px-4 py-3 text-left overline">{t('reports_specialty')}</th>
                <th className="px-4 py-3 text-left overline">{t('reports_value')}</th>
                <th className="px-4 py-3 text-left overline">{t('reports_status')}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {data.procedures.map((item) => (
                <tr key={item.id}>
                  <td className="px-4 py-3 text-sm text-slate-600">{item.date}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <Avatar name={item.patient} className="h-8 w-8" />
                      <span className="text-sm font-medium text-night">{item.patient}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-sm text-slate-600">{item.professional}</td>
                  <td className="px-4 py-3"><Badge className="bg-primary/10 text-primary">{item.specialty}</Badge></td>
                  <td className="px-4 py-3 text-sm font-semibold text-night">{formatCurrency(item.value)}</td>
                  <td className="px-4 py-3"><Badge status={item.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="flex items-center justify-between border-t border-slate-100 px-4 py-3 text-sm text-slate-600">
          <span>{t('reports_showing_prefix')} {data.procedures.length} {t('reports_entries')}</span>
          <div className="space-x-2"><button>{t('reports_previous')}</button><button>{t('reports_next')}</button></div>
        </div>
      </Card>
    </div>
  )
}
