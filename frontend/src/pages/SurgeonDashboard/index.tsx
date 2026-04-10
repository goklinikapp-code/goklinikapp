import { useQuery } from '@tanstack/react-query'
import { CalendarDays, ClipboardCheck, HeartPulse, RefreshCw, Users } from 'lucide-react'
import { useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  CartesianGrid,
  Cell,
  Line,
  LineChart,
  Pie,
  PieChart as RechartsPieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'

import type { AppointmentItem } from '@/api/appointments'
import { getAppointments } from '@/api/appointments'
import { getPatients } from '@/api/patients'
import { listTenantPostOperatory } from '@/api/postOperatory'
import { listTenantPreOperatory } from '@/api/preOperatory'
import { preOperatoryStatusLabel } from '@/components/patients/preOperatoryStatus'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { KpiCard } from '@/components/shared/KpiCard'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { useGreeting } from '@/hooks/useGreeting'
import { getLocaleForLanguage, t as translate, type TranslationKey } from '@/i18n/system'
import { useAuthStore } from '@/stores/authStore'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { formatDate } from '@/utils/format'

const ACTIVE_APPOINTMENT_STATUSES = new Set([
  'pending',
  'confirmed',
  'in_progress',
  'rescheduled',
  'completed',
])

function localIsoDate(date: Date) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function formatTimeLabel(raw: string) {
  const value = (raw || '').trim()
  if (!value) return '--:--'
  return value.slice(0, 5)
}

function compareAppointments(a: AppointmentItem, b: AppointmentItem) {
  const left = `${a.appointment_date}T${formatTimeLabel(a.appointment_time)}`
  const right = `${b.appointment_date}T${formatTimeLabel(b.appointment_time)}`
  return left.localeCompare(right)
}

function appointmentTypeLabel(type: string, t: (key: TranslationKey) => string) {
  switch (type) {
    case 'first_visit':
      return t('schedule_type_first_visit')
    case 'return':
      return t('schedule_type_return')
    case 'surgery':
      return t('schedule_type_surgery')
    case 'post_op_7d':
      return t('schedule_type_post_op_7d')
    case 'post_op_30d':
      return t('schedule_type_post_op_30d')
    case 'post_op_90d':
      return t('schedule_type_post_op_90d')
    default:
      return type || t('schedule_not_informed')
  }
}

export default function SurgeonDashboardPage() {
  const navigate = useNavigate()
  const user = useAuthStore((state) => state.user)
  const language = usePreferencesStore((state) => state.language)
  const locale = getLocaleForLanguage(language)
  const greeting = useGreeting(language)
  const t = (key: TranslationKey) => translate(language, key)
  const today = new Date()
  const todayIso = localIsoDate(today)
  const weekEnd = new Date(today)
  weekEnd.setDate(weekEnd.getDate() + 6)
  const weekEndIso = localIsoDate(weekEnd)

  const patientsQuery = useQuery({
    queryKey: ['surgeon-dashboard', 'patients', user?.id],
    queryFn: () => getPatients(),
    enabled: user?.role === 'surgeon',
    refetchInterval: 30000,
  })

  const appointmentsQuery = useQuery({
    queryKey: ['surgeon-dashboard', 'appointments', user?.id],
    queryFn: () => getAppointments(),
    enabled: user?.role === 'surgeon',
    refetchInterval: 30000,
  })

  const preOperatoryPendingQuery = useQuery({
    queryKey: ['surgeon-dashboard', 'pre-operatory', 'pending', user?.id],
    queryFn: () => listTenantPreOperatory('pending'),
    enabled: user?.role === 'surgeon',
    refetchInterval: 30000,
  })

  const preOperatoryInReviewQuery = useQuery({
    queryKey: ['surgeon-dashboard', 'pre-operatory', 'in_review', user?.id],
    queryFn: () => listTenantPreOperatory('in_review'),
    enabled: user?.role === 'surgeon',
    refetchInterval: 30000,
  })

  const postOperatoryActiveQuery = useQuery({
    queryKey: ['surgeon-dashboard', 'post-operatory', 'active', user?.id],
    queryFn: () => listTenantPostOperatory('active'),
    enabled: user?.role === 'surgeon',
    refetchInterval: 30000,
  })

  const isLoading =
    patientsQuery.isLoading ||
    appointmentsQuery.isLoading ||
    preOperatoryPendingQuery.isLoading ||
    preOperatoryInReviewQuery.isLoading ||
    postOperatoryActiveQuery.isLoading

  const hasBlockingError =
    (patientsQuery.isError && !patientsQuery.data) ||
    (appointmentsQuery.isError && !appointmentsQuery.data) ||
    (preOperatoryPendingQuery.isError && !preOperatoryPendingQuery.data) ||
    (preOperatoryInReviewQuery.isError && !preOperatoryInReviewQuery.data) ||
    (postOperatoryActiveQuery.isError && !postOperatoryActiveQuery.data)

  const patients = patientsQuery.data || []
  const appointments = useMemo(
    () =>
      (appointmentsQuery.data || []).filter((item) =>
        ACTIVE_APPOINTMENT_STATUSES.has(item.status),
      ),
    [appointmentsQuery.data],
  )
  const pendingPreOperatory = preOperatoryPendingQuery.data || []
  const inReviewPreOperatory = preOperatoryInReviewQuery.data || []
  const activePostOperatory = postOperatoryActiveQuery.data || []

  const appointmentsToday = useMemo(
    () => appointments.filter((item) => item.appointment_date === todayIso),
    [appointments, todayIso],
  )
  const appointmentsWeek = useMemo(
    () =>
      appointments.filter(
        (item) =>
          item.appointment_date >= todayIso && item.appointment_date <= weekEndIso,
      ),
    [appointments, todayIso, weekEndIso],
  )
  const nextAppointments = useMemo(
    () =>
      appointments
        .filter(
          (item) =>
            item.status !== 'completed' &&
            item.appointment_date >= todayIso,
        )
        .sort(compareAppointments)
        .slice(0, 6),
    [appointments, todayIso],
  )
  const preOperatoryQueue = useMemo(
    () =>
      [...(preOperatoryPendingQuery.data || []), ...(preOperatoryInReviewQuery.data || [])]
        .sort((a, b) => (b.created_at || '').localeCompare(a.created_at || ''))
        .slice(0, 6),
    [preOperatoryInReviewQuery.data, preOperatoryPendingQuery.data],
  )

  const confirmedToday = appointmentsToday.filter(
    (item) => item.status === 'confirmed',
  ).length
  const appointmentsCountByDate = useMemo(() => {
    const counts = new Map<string, number>()
    appointments.forEach((item) => {
      const dateKey = item.appointment_date
      counts.set(dateKey, (counts.get(dateKey) || 0) + 1)
    })
    return counts
  }, [appointments])
  const appointmentTrendSeries = useMemo(
    () =>
      Array.from({ length: 14 }, (_, index) => {
        const date = new Date()
        date.setDate(date.getDate() + index)
        const dateKey = localIsoDate(date)
        return {
          date: dateKey,
          label: new Intl.DateTimeFormat(locale, {
            day: '2-digit',
            month: '2-digit',
          }).format(date),
          count: appointmentsCountByDate.get(dateKey) || 0,
        }
      }),
    [appointmentsCountByDate, locale],
  )
  const appointmentStatusSeries = useMemo(() => {
    const statusConfig: Array<{
      key: string
      label: string
      color: string
    }> = [
      {
        key: 'pending',
        label: translate(language, 'schedule_status_pending'),
        color: '#C8992E',
      },
      {
        key: 'confirmed',
        label: translate(language, 'schedule_status_confirmed'),
        color: '#4A7C59',
      },
      {
        key: 'in_progress',
        label: translate(language, 'schedule_status_in_progress'),
        color: '#0D5C73',
      },
      {
        key: 'rescheduled',
        label: translate(language, 'schedule_status_rescheduled'),
        color: '#7C3AED',
      },
      {
        key: 'completed',
        label: translate(language, 'schedule_status_completed'),
        color: '#14B8A6',
      },
    ]

    return statusConfig
      .map((item) => ({
        name: item.label,
        value: appointments.filter((appointment) => appointment.status === item.key).length,
        color: item.color,
      }))
      .filter((item) => item.value > 0)
  }, [appointments, language])
  const isRefetching =
    patientsQuery.isFetching ||
    appointmentsQuery.isFetching ||
    preOperatoryPendingQuery.isFetching ||
    preOperatoryInReviewQuery.isFetching ||
    postOperatoryActiveQuery.isFetching

  const refreshAll = async () => {
    await Promise.all([
      patientsQuery.refetch(),
      appointmentsQuery.refetch(),
      preOperatoryPendingQuery.refetch(),
      preOperatoryInReviewQuery.refetch(),
      postOperatoryActiveQuery.refetch(),
    ])
  }

  if (isLoading) {
    return <p className="body-copy">{t('dashboard_loading')}</p>
  }

  if (hasBlockingError) {
    return (
      <Card className="space-y-3">
        <p className="body-copy text-danger">{t('doctor_dashboard_load_error')}</p>
        <Button type="button" variant="secondary" onClick={() => void refreshAll()}>
          <RefreshCw className="h-4 w-4" />
          {t('doctor_dashboard_refresh')}
        </Button>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      <SectionHeader
        title={`${greeting}, ${user?.full_name?.split(' ')[0] || t('dashboard_team_fallback')}!`}
        subtitle={t('doctor_dashboard_summary')}
        actions={
          <Button
            type="button"
            variant="secondary"
            disabled={isRefetching}
            onClick={() => void refreshAll()}
          >
            <RefreshCw className={`h-4 w-4 ${isRefetching ? 'animate-spin' : ''}`} />
            {t('doctor_dashboard_refresh')}
          </Button>
        }
      />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <KpiCard
          title={t('doctor_dashboard_my_patients')}
          value={patients.length}
          icon={Users}
        />
        <KpiCard
          title={t('doctor_dashboard_today_appointments')}
          value={appointmentsToday.length}
          icon={CalendarDays}
          caption={`${t('doctor_dashboard_today_confirmed_caption')}: ${confirmedToday}`}
        />
        <KpiCard
          title={t('doctor_dashboard_week_appointments')}
          value={appointmentsWeek.length}
          icon={CalendarDays}
          caption={t('doctor_dashboard_week_caption')}
        />
        <KpiCard
          title={t('doctor_dashboard_preop_pending')}
          value={pendingPreOperatory.length}
          icon={ClipboardCheck}
        />
        <KpiCard
          title={t('doctor_dashboard_preop_in_review')}
          value={inReviewPreOperatory.length}
          icon={ClipboardCheck}
        />
        <KpiCard
          title={t('doctor_dashboard_postop_active')}
          value={activePostOperatory.length}
          icon={HeartPulse}
          caption={t('doctor_dashboard_postop_caption')}
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-12">
        <Card className="lg:col-span-8" padded={false}>
          <div className="border-b border-slate-100 px-5 py-4">
            <h2 className="section-heading">{t('doctor_dashboard_appointments_trend')}</h2>
            <p className="mt-1 text-xs text-slate-500">
              {t('doctor_dashboard_appointments_trend_caption')}
            </p>
          </div>
          <div className="h-72 p-3">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={appointmentTrendSeries}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E2E8F0" />
                <XAxis dataKey="label" tickLine={false} axisLine={false} />
                <YAxis allowDecimals={false} tickLine={false} axisLine={false} />
                <Tooltip
                  formatter={(value) => [value, t('doctor_dashboard_appointments_count')]}
                />
                <Line
                  type="monotone"
                  dataKey="count"
                  stroke="#0D5C73"
                  strokeWidth={3}
                  dot={{ r: 3 }}
                  activeDot={{ r: 5 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card className="lg:col-span-4" padded={false}>
          <div className="border-b border-slate-100 px-5 py-4">
            <h2 className="section-heading">{t('doctor_dashboard_appointment_status')}</h2>
          </div>
          <div className="space-y-3 p-4">
            {appointmentStatusSeries.length === 0 ? (
              <p className="text-sm text-slate-500">{t('doctor_dashboard_no_chart_data')}</p>
            ) : (
              <>
                <div className="h-48">
                  <ResponsiveContainer width="100%" height="100%">
                    <RechartsPieChart>
                      <Pie
                        data={appointmentStatusSeries}
                        dataKey="value"
                        nameKey="name"
                        innerRadius={50}
                        outerRadius={80}
                      >
                        {appointmentStatusSeries.map((entry) => (
                          <Cell key={entry.name} fill={entry.color} />
                        ))}
                      </Pie>
                      <Tooltip />
                    </RechartsPieChart>
                  </ResponsiveContainer>
                </div>
                <div className="space-y-2">
                  {appointmentStatusSeries.map((item) => (
                    <div key={item.name} className="flex items-center justify-between text-sm">
                      <span className="inline-flex items-center gap-2 text-slate-600">
                        <span
                          className="h-2.5 w-2.5 rounded-full"
                          style={{ backgroundColor: item.color }}
                        />
                        {item.name}
                      </span>
                      <span className="font-semibold text-night">{item.value}</span>
                    </div>
                  ))}
                </div>
              </>
            )}
          </div>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-12">
        <Card className="lg:col-span-8" padded={false}>
          <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
            <h2 className="section-heading">{t('doctor_dashboard_upcoming_appointments')}</h2>
            <button
              className="text-sm font-semibold text-primary hover:underline"
              onClick={() => navigate('/schedule')}
            >
              {t('doctor_dashboard_view_schedule')}
            </button>
          </div>
          <div className="space-y-3 p-4">
            {nextAppointments.length === 0 ? (
              <p className="text-sm text-slate-500">{t('doctor_dashboard_no_upcoming')}</p>
            ) : (
              nextAppointments.map((appointment) => {
                const formattedDate = new Intl.DateTimeFormat(locale, {
                  day: '2-digit',
                  month: '2-digit',
                }).format(new Date(`${appointment.appointment_date}T00:00:00`))

                return (
                  <div
                    key={appointment.id}
                    className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-100 bg-slate-50 p-3"
                  >
                    <div className="flex items-center gap-3">
                      <Avatar
                        name={appointment.patient_name}
                        src={appointment.patient_avatar_url || undefined}
                        className="h-11 w-11"
                      />
                      <div>
                        <p className="text-sm font-semibold text-night">{appointment.patient_name}</p>
                        <p className="caption">
                          {appointmentTypeLabel(appointment.appointment_type, t)}
                        </p>
                      </div>
                    </div>

                    <div className="flex flex-wrap items-center gap-3 text-sm text-slate-600">
                      <span>{formattedDate}</span>
                      <span>{formatTimeLabel(appointment.appointment_time)}</span>
                      <span>{appointment.clinic_location || t('dashboard_main_room')}</span>
                      <Badge status={appointment.status} />
                    </div>
                  </div>
                )
              })
            )}
          </div>
        </Card>

        <Card className="lg:col-span-4" padded={false}>
          <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
            <h2 className="section-heading">{t('doctor_dashboard_preop_queue')}</h2>
            <button
              className="text-sm font-semibold text-primary hover:underline"
              onClick={() => navigate('/pre-operatory')}
            >
              {t('doctor_dashboard_view_preop')}
            </button>
          </div>
          <div className="space-y-3 p-4">
            {preOperatoryQueue.length === 0 ? (
              <p className="text-sm text-slate-500">{t('doctor_dashboard_no_preop')}</p>
            ) : (
              preOperatoryQueue.map((record) => (
                <div
                  key={record.id}
                  className="rounded-xl border border-slate-100 bg-slate-50 p-3"
                >
                  <div className="flex items-start justify-between gap-2">
                    <p className="text-sm font-semibold text-night">
                      {record.patient_name || t('reports_patient_fallback')}
                    </p>
                    <Badge>{preOperatoryStatusLabel(record.status, t)}</Badge>
                  </div>
                  <p className="caption mt-2">{formatDate(record.created_at)}</p>
                </div>
              ))
            )}
          </div>
        </Card>
      </div>
    </div>
  )
}
