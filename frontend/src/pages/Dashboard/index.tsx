import { useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { useMemo } from 'react'
import {
  Calendar,
  CircleDollarSign,
  PieChart,
  Plus,
  Users,
  AlertTriangle,
  Sparkles,
} from 'lucide-react'
import {
  Bar,
  BarChart,
  Cell,
  Pie,
  PieChart as RechartsPieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'

import { getDashboard } from '@/api/dashboard'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { KpiCard } from '@/components/shared/KpiCard'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Avatar } from '@/components/ui/Avatar'
import { useGreeting } from '@/hooks/useGreeting'
import { getLocaleForLanguage, t as translate, type TranslationKey } from '@/i18n/system'
import { useAuthStore } from '@/stores/authStore'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { formatCurrency } from '@/utils/format'

export default function DashboardPage() {
  const { user } = useAuthStore()
  const language = usePreferencesStore((state) => state.language)
  const currency = usePreferencesStore((state) => state.currency)
  const greeting = useGreeting(language)
  const navigate = useNavigate()
  const locale = getLocaleForLanguage(language)
  const t = (key: TranslationKey) => translate(language, key)

  const { data } = useQuery({
    queryKey: ['dashboard-data'],
    queryFn: getDashboard,
  })

  const revenueSeries = data?.revenue_series || []
  const specialtyDistribution = data?.specialty_distribution || []
  const localizedRevenueSeries = useMemo(() => {
    const total = revenueSeries.length
    return revenueSeries.map((item, index) => {
      const offsetFromCurrentMonth = total - index - 1
      const monthDate = new Date()
      monthDate.setDate(1)
      monthDate.setMonth(monthDate.getMonth() - offsetFromCurrentMonth)
      return {
        ...item,
        name: new Intl.DateTimeFormat(locale, { month: 'short' }).format(monthDate),
      }
    })
  }, [locale, revenueSeries])

  const compactCurrencyFormatter = useMemo(
    () =>
      new Intl.NumberFormat(locale, {
        style: 'currency',
        currency,
        notation: 'compact',
        maximumFractionDigits: 1,
      }),
    [currency, locale],
  )

  const alertMessageByType: Record<string, string> = {
    inactive_patient: t('dashboard_alert_inactive_patient'),
    postop_pending: t('dashboard_alert_postop_pending'),
    birthday: t('dashboard_alert_birthday'),
  }

  if (!data) {
    return <p className="body-copy">{t('dashboard_loading')}</p>
  }

  return (
    <div className="space-y-6">
      <SectionHeader
        title={`${greeting}, ${user?.full_name?.split(' ')[0] || t('dashboard_team_fallback')}!`}
        subtitle={t('dashboard_summary')}
      />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <KpiCard
          title={t('dashboard_revenue')}
          value={data.faturamento_mes_atual}
          icon={CircleDollarSign}
          isCurrency
          variation={data.variacao_percentual_faturamento}
          caption={t('dashboard_vs_previous_month')}
        />
        <KpiCard
          title={t('dashboard_total_patients')}
          value={data.total_pacientes_ativos + data.total_pacientes_inativos}
          icon={Users}
          caption={`${t('dashboard_new_leads')}: ${data.novos_pacientes_mes}`}
        />
        <KpiCard
          title={t('dashboard_appointments')}
          value={data.agendamentos_hoje.length}
          icon={Calendar}
          caption={`${t('dashboard_confirmed')}: ${
            data.agendamentos_hoje.filter((item) => item.status === 'confirmed').length
          }`}
        />

        <Card className="space-y-3">
          <div className="flex items-center justify-between">
            <p className="overline">{t('dashboard_occupancy_rate')}</p>
            <PieChart className="h-4 w-4 text-primary" />
          </div>
          <div className="flex items-center gap-4">
            <svg viewBox="0 0 100 100" className="h-16 w-16 -rotate-90">
              <circle cx="50" cy="50" r="44" stroke="#E5E7EB" strokeWidth="10" fill="none" />
              <circle
                cx="50"
                cy="50"
                r="44"
                stroke="#0D5C73"
                strokeWidth="10"
                fill="none"
                strokeDasharray={276}
                strokeDashoffset={276 - (276 * data.taxa_ocupacao_semana) / 100}
                strokeLinecap="round"
              />
            </svg>
            <div>
              <p className="text-[28px] font-bold text-night">{data.taxa_ocupacao_semana.toFixed(1)}%</p>
              <p className="caption">{t('dashboard_optimized_capacity')}</p>
            </div>
          </div>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-12">
        <Card className="lg:col-span-8" padded={false}>
          <div className="flex items-center justify-between border-b border-slate-100 p-5">
            <h2 className="section-heading">{t('dashboard_revenue_evolution')}</h2>
            <div className="flex items-center gap-3 text-xs text-slate-500">
              <span className="inline-flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-primary" /> {t('dashboard_current')}</span>
              <span className="inline-flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-slate-300" /> {t('dashboard_projected')}</span>
            </div>
          </div>
          <div className="h-[290px] p-3">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={localizedRevenueSeries}>
                <XAxis dataKey="name" tickLine={false} axisLine={false} />
                <YAxis
                  tickFormatter={(value) => compactCurrencyFormatter.format(Number(value) || 0)}
                  tickLine={false}
                  axisLine={false}
                />
                <Tooltip formatter={(value) => formatCurrency(Number(value))} />
                <Bar dataKey="atual" radius={[6, 6, 0, 0]} fill="#0D5C73" />
                <Bar dataKey="projetado" radius={[6, 6, 0, 0]} fill="#CBD5E1" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card className="lg:col-span-4" padded={false}>
          <div className="border-b border-slate-100 p-5">
            <h2 className="section-heading">{t('dashboard_specialty_distribution')}</h2>
          </div>
          <div className="space-y-3 p-5">
            <div className="h-48">
              <ResponsiveContainer width="100%" height="100%">
                <RechartsPieChart>
                  <Pie data={specialtyDistribution} dataKey="value" nameKey="name" innerRadius={55} outerRadius={85}>
                    {specialtyDistribution.map((entry) => (
                      <Cell key={entry.name} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip />
                </RechartsPieChart>
              </ResponsiveContainer>
            </div>
            {specialtyDistribution.map((specialty) => (
              <div key={specialty.name} className="flex items-center justify-between text-sm">
                <span className="inline-flex items-center gap-2 text-slate-600">
                  <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: specialty.color }} />
                  {specialty.name}
                </span>
                <span className="font-semibold text-night">{specialty.value}%</span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-12">
        <Card className="lg:col-span-8" padded={false}>
          <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
            <h2 className="section-heading">{t('dashboard_upcoming_appointments')}</h2>
            <button
              className="text-sm font-semibold text-primary hover:underline"
              onClick={() => navigate('/schedule')}
            >
              {t('dashboard_view_full_schedule')}
            </button>
          </div>

          <div className="space-y-3 p-4">
            {data.agendamentos_hoje.map((appointment) => (
              <div key={appointment.id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-100 bg-slate-50 p-3">
                <div className="flex items-center gap-3">
                  <Avatar name={appointment.paciente_nome} className="h-11 w-11" />
                  <div>
                    <p className="text-sm font-semibold text-night">{appointment.paciente_nome}</p>
                    <p className="caption">{appointment.procedimento || appointment.tipo}</p>
                  </div>
                </div>

                <div className="flex items-center gap-4 text-sm text-slate-600">
                  <span>{appointment.horario}</span>
                  <span>{appointment.localizacao || t('dashboard_main_room')}</span>
                  <Badge status={appointment.status} />
                </div>
              </div>
            ))}
          </div>
        </Card>

        <div className="space-y-4 lg:col-span-4">
          <Card>
            <h2 className="section-heading mb-3">{t('dashboard_smart_alerts')}</h2>
            <div className="space-y-2">
              {data.alertas.map((alert) => (
                <div key={alert.patient_id} className="flex items-start gap-2 rounded-lg bg-danger/5 p-3">
                  <AlertTriangle className="mt-0.5 h-4 w-4 text-danger" />
                  <div>
                    <p className="text-sm font-semibold text-night">{alert.name}</p>
                    <p className="caption">{alertMessageByType[alert.type] || alert.message}</p>
                  </div>
                </div>
              ))}
            </div>
          </Card>

          <Card className="border-amber-200 bg-amber-50">
            <p className="overline text-amber-700">{t('dashboard_daily_insight')}</p>
            <p className="mt-2 text-sm font-medium text-amber-900">
              {t('dashboard_daily_insight_text')}
            </p>
            <Button className="mt-4" variant="accent" onClick={() => navigate('/automations')}>
              <Sparkles className="h-4 w-4" />
              {t('dashboard_activate_campaign')}
            </Button>
          </Card>
        </div>
      </div>

      <Button
        className="fixed bottom-6 right-6 z-20 h-12 w-12 rounded-full p-0 shadow-xl"
        title={t('dashboard_new_appointment')}
        onClick={() => navigate('/schedule')}
      >
        <Plus className="h-5 w-5" />
      </Button>
    </div>
  )
}
