import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { addDays, format } from 'date-fns'
import { AlertTriangle, CalendarDays, Clock4, MapPin, Plus, RefreshCw } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import toast from 'react-hot-toast'
import { z } from 'zod'

import {
  cancelAppointment,
  createAppointment,
  getAppointments,
  getAvailableSlots,
  updateAppointment,
  type AppointmentItem,
  type UpdateAppointmentPayload,
} from '@/api/appointments'
import { getPatients } from '@/api/patients'
import { getTeamMembers } from '@/api/team'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Modal } from '@/components/ui/Modal'
import { Select } from '@/components/ui/Select'
import { TextArea } from '@/components/ui/TextArea'
import {
  getLocaleForLanguage,
  t as translate,
  type TranslationKey,
} from '@/i18n/system'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { formatLongDate } from '@/utils/format'

const appointmentTypeValues = [
  'first_visit',
  'return',
  'surgery',
  'post_op_7d',
  'post_op_30d',
  'post_op_90d',
] as const

type AppointmentTypeValue = (typeof appointmentTypeValues)[number]

type SlotsByDay = Record<string, string[]>
const DATE_ONLY_PATTERN = /^\d{4}-\d{2}-\d{2}$/

interface AppointmentForm {
  patient: string
  professional: string
  appointment_date: string
  appointment_time: string
  appointment_type: AppointmentTypeValue
  notes?: string
}

interface AppointmentEditForm {
  patient: string
  professional: string
  appointment_date: string
  appointment_time: string
  appointment_type: AppointmentTypeValue
  status: string
  clinic_location: string
  duration_minutes: number
  notes: string
}

interface AppointmentCancelState {
  appointment: AppointmentItem
  reason: string
}

function normalizeAppointmentType(value?: string | null): AppointmentTypeValue {
  if (appointmentTypeValues.includes((value || '') as AppointmentTypeValue)) {
    return value as AppointmentTypeValue
  }
  return 'first_visit'
}

function toInputTime(value?: string | null): string {
  if (!value) return ''
  return value.slice(0, 5)
}

function toApiTime(value?: string | null): string {
  if (!value) return ''
  if (value.length === 5) return `${value}:00`
  return value
}

function extractErrorMessage(error: unknown, fallback: string): string {
  if (!isAxiosError(error)) {
    return fallback
  }

  const responseData = error.response?.data as Record<string, unknown> | undefined
  if (!responseData) {
    return fallback
  }

  const detail = responseData.detail
  if (typeof detail === 'string' && detail.trim()) {
    return detail
  }

  const firstValue = Object.values(responseData)[0]
  if (Array.isArray(firstValue) && firstValue[0]) {
    return String(firstValue[0])
  }
  if (typeof firstValue === 'string' && firstValue.trim()) {
    return firstValue
  }

  return fallback
}

function readAvatarFromNestedEntity(value: unknown): string {
  if (!value || typeof value !== 'object') return ''
  const entry = value as Record<string, unknown>
  return (
    (entry.avatar_url ?? entry.avatar ?? entry.photo ?? '')
      .toString()
      .trim()
  )
}

function resolvePatientAvatar(appointment: AppointmentItem): string {
  const direct = (appointment.patient_avatar_url || '').trim()
  if (direct) return direct

  const raw = appointment as unknown as Record<string, unknown>
  const rootFallback = (raw.patient_avatar ?? raw.patient_photo ?? '').toString().trim()
  if (rootFallback) return rootFallback
  return readAvatarFromNestedEntity(raw.patient)
}

function resolveProfessionalAvatar(appointment: AppointmentItem): string {
  const direct = (appointment.professional_avatar_url || '').trim()
  if (direct) return direct

  const raw = appointment as unknown as Record<string, unknown>
  const rootFallback = (raw.professional_avatar ?? raw.professional_photo ?? '').toString().trim()
  if (rootFallback) return rootFallback
  return readAvatarFromNestedEntity(raw.professional)
}

export default function SchedulePage() {
  const language = usePreferencesStore((state) => state.language)
  const locale = getLocaleForLanguage(language)
  const t = (key: TranslationKey) => translate(language, key)

  const [isModalOpen, setIsModalOpen] = useState(false)
  const [selectedDay, setSelectedDay] = useState('')
  const [selectedSlot, setSelectedSlot] = useState('')
  const [isDetailsModalOpen, setIsDetailsModalOpen] = useState(false)
  const [selectedAppointment, setSelectedAppointment] = useState<AppointmentItem | null>(null)
  const [editForm, setEditForm] = useState<AppointmentEditForm | null>(null)
  const [cancelState, setCancelState] = useState<AppointmentCancelState | null>(null)

  const queryClient = useQueryClient()

  const appointmentSchema = useMemo(
    () =>
      z.object({
        patient: z.string().uuid(t('schedule_error_patient_required')),
        professional: z.string().uuid(t('schedule_error_professional_required')),
        appointment_date: z.string().min(1, t('schedule_error_date_required')),
        appointment_time: z.string().min(1, t('schedule_error_time_required')),
        appointment_type: z.enum(appointmentTypeValues),
        notes: z.string().optional(),
      }),
    [language],
  )

  const appointmentTypeLabels = useMemo<Record<AppointmentTypeValue, string>>(
    () => ({
      first_visit: t('schedule_type_first_visit'),
      return: t('schedule_type_return'),
      surgery: t('schedule_type_surgery'),
      post_op_7d: t('schedule_type_post_op_7d'),
      post_op_30d: t('schedule_type_post_op_30d'),
      post_op_90d: t('schedule_type_post_op_90d'),
    }),
    [language],
  )

  const statusOptions = useMemo(
    () => [
      { value: 'pending', label: t('schedule_status_pending') },
      { value: 'confirmed', label: t('schedule_status_confirmed') },
      { value: 'in_progress', label: t('schedule_status_in_progress') },
      { value: 'completed', label: t('schedule_status_completed') },
      { value: 'cancelled', label: t('schedule_status_cancelled') },
      { value: 'rescheduled', label: t('schedule_status_rescheduled') },
    ],
    [language],
  )

  const today = format(new Date(), 'yyyy-MM-dd')
  const nextYear = format(addDays(new Date(), 365), 'yyyy-MM-dd')
  const bookingDays = useMemo(
    () => Array.from({ length: 14 }, (_, index) => format(addDays(new Date(), index + 1), 'yyyy-MM-dd')),
    [],
  )

  const {
    data: appointments = [],
    isLoading: isLoadingAppointments,
    isError: isAppointmentsError,
    error: appointmentsError,
    refetch: refetchAppointments,
    isFetching: isFetchingAppointments,
  } = useQuery({
    queryKey: ['schedule-appointments', today, nextYear],
    queryFn: () =>
      getAppointments({
        date_from: today,
        date_to: nextYear,
      }),
    refetchOnMount: 'always',
    refetchInterval: 15000,
  })

  const { data: patients = [] } = useQuery({
    queryKey: ['patients-list'],
    queryFn: getPatients,
  })

  const { data: teamMembers = [] } = useQuery({
    queryKey: ['team-members'],
    queryFn: getTeamMembers,
  })

  const surgeons = useMemo(() => teamMembers.filter((member) => member.role === 'Surgeon'), [teamMembers])

  const groupedAppointments = useMemo(() => {
    const groups = new Map<string, typeof appointments>()
    appointments.forEach((item) => {
      const dateKey = item.appointment_date
      const current = groups.get(dateKey) || []
      current.push(item)
      groups.set(dateKey, current)
    })

    return Array.from(groups.entries())
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([date, items]) => ({
        date,
        items: items.sort((a, b) => a.appointment_time.localeCompare(b.appointment_time)),
      }))
  }, [appointments])

  const appointmentsErrorMessage = useMemo(() => {
    return extractErrorMessage(appointmentsError, t('schedule_load_error'))
  }, [appointmentsError, language])

  const {
    register,
    handleSubmit,
    reset,
    setValue,
    setError,
    clearErrors,
    control,
    formState: { errors },
  } = useForm<AppointmentForm>({
    resolver: zodResolver(appointmentSchema),
    defaultValues: {
      patient: '',
      professional: '',
      appointment_date: '',
      appointment_time: '',
      appointment_type: 'first_visit',
      notes: '',
    },
  })

  const selectedProfessional = useWatch({
    control,
    name: 'professional',
  })

  const {
    data: slotsByDay = {},
    isFetching: isFetchingAvailability,
  } = useQuery({
    queryKey: ['schedule-availability', selectedProfessional, bookingDays],
    enabled: isModalOpen && Boolean(selectedProfessional),
    queryFn: async () => {
      if (!selectedProfessional) return {}
      const entries = await Promise.all(
        bookingDays.map(async (date) => {
          try {
            const slots = await getAvailableSlots({
              professional_id: selectedProfessional,
              date,
            })
            return [date, slots] as const
          } catch {
            return [date, []] as const
          }
        }),
      )
      return Object.fromEntries(entries) as SlotsByDay
    },
  })

  const dayHasAvailability = useMemo(
    () =>
      Object.fromEntries(
        bookingDays.map((day) => [day, selectedProfessional ? (slotsByDay[day] || []).length > 0 : null]),
      ) as Record<string, boolean | null>,
    [bookingDays, selectedProfessional, slotsByDay],
  )

  const firstAvailableDay =
    bookingDays.find((day) => (slotsByDay[day] || []).length > 0) || bookingDays[0] || ''
  const effectiveSelectedDay = selectedProfessional
    ? (slotsByDay[selectedDay] || []).length > 0
      ? selectedDay
      : firstAvailableDay
    : selectedDay || bookingDays[0] || ''
  const selectedDaySlots = slotsByDay[effectiveSelectedDay] || []

  const createMutation = useMutation({
    mutationFn: createAppointment,
    onSuccess: () => {
      toast.success(t('schedule_create_success'))
      setIsModalOpen(false)
      setSelectedDay('')
      setSelectedSlot('')
      reset({
        patient: '',
        professional: '',
        appointment_date: '',
        appointment_time: '',
        appointment_type: 'first_visit',
        notes: '',
      })
      void queryClient.invalidateQueries({ queryKey: ['schedule-appointments'], exact: false })
      void queryClient.refetchQueries({ queryKey: ['schedule-appointments'], exact: false })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-data'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('schedule_create_error')))
    },
  })

  const updateMutation = useMutation({
    mutationFn: ({
      appointmentId,
      payload,
    }: {
      appointmentId: string
      payload: UpdateAppointmentPayload
    }) => updateAppointment(appointmentId, payload),
    onSuccess: () => {
      toast.success(t('schedule_update_success'))
      setIsDetailsModalOpen(false)
      setSelectedAppointment(null)
      setEditForm(null)
      void queryClient.invalidateQueries({ queryKey: ['schedule-appointments'], exact: false })
      void queryClient.refetchQueries({ queryKey: ['schedule-appointments'], exact: false })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-data'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('schedule_update_error')))
    },
  })

  const cancelMutation = useMutation({
    mutationFn: ({ appointmentId, reason }: { appointmentId: string; reason: string }) =>
      cancelAppointment(appointmentId, reason),
    onSuccess: (_, variables) => {
      toast.success(t('schedule_cancel_success'))
      setCancelState(null)

      if (selectedAppointment?.id === variables.appointmentId) {
        setIsDetailsModalOpen(false)
        setSelectedAppointment(null)
        setEditForm(null)
      }

      void queryClient.invalidateQueries({ queryKey: ['schedule-appointments'], exact: false })
      void queryClient.refetchQueries({ queryKey: ['schedule-appointments'], exact: false })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-data'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('schedule_cancel_error')))
    },
  })

  const onSubmit = (values: AppointmentForm) => {
    if (!effectiveSelectedDay) {
      setError('appointment_date', { type: 'manual', message: t('schedule_error_date_required') })
      return
    }
    if (!selectedSlot) {
      setError('appointment_time', { type: 'manual', message: t('schedule_error_time_required') })
      return
    }
    createMutation.mutate({
      ...values,
      appointment_date: effectiveSelectedDay,
      appointment_time: selectedSlot,
    })
  }

  const openCreateModal = () => {
    const firstDay = bookingDays[0] || ''
    setSelectedDay(firstDay)
    setSelectedSlot('')
    setIsModalOpen(true)
    reset({
      patient: '',
      professional: '',
      appointment_date: '',
      appointment_time: '',
      appointment_type: 'first_visit',
      notes: '',
    })
  }

  const openDetailsModal = (appointment: AppointmentItem) => {
    const isoDate = DATE_ONLY_PATTERN.test(appointment.appointment_date)
      ? appointment.appointment_date
      : appointment.appointment_date.slice(0, 10)

    setSelectedAppointment(appointment)
    setEditForm({
      patient: appointment.patient,
      professional: appointment.professional,
      appointment_date: isoDate,
      appointment_time: toInputTime(appointment.appointment_time),
      appointment_type: normalizeAppointmentType(appointment.appointment_type),
      status: appointment.status || 'pending',
      clinic_location: appointment.clinic_location || '',
      duration_minutes: Number(appointment.duration_minutes || 60),
      notes: appointment.notes || '',
    })
    setIsDetailsModalOpen(true)
  }

  const closeDetailsModal = () => {
    setIsDetailsModalOpen(false)
    setSelectedAppointment(null)
    setEditForm(null)
  }

  const openCancelModal = (appointment: AppointmentItem) => {
    setCancelState({
      appointment,
      reason: t('schedule_cancel_default_reason'),
    })
  }

  const closeCancelModal = () => {
    if (cancelMutation.isPending) return
    setCancelState(null)
  }

  const handleConfirmCancel = () => {
    if (!cancelState) return

    const reason = cancelState.reason.trim()
    if (!reason) {
      toast.error(t('schedule_cancel_reason_required'))
      return
    }

    cancelMutation.mutate({
      appointmentId: cancelState.appointment.id,
      reason,
    })
  }

  const handleSaveDetails = () => {
    if (!selectedAppointment || !editForm) return

    if (!editForm.patient) {
      toast.error(t('schedule_error_patient_required'))
      return
    }
    if (!editForm.professional) {
      toast.error(t('schedule_error_professional_required'))
      return
    }
    if (!editForm.appointment_date || !DATE_ONLY_PATTERN.test(editForm.appointment_date)) {
      toast.error(t('schedule_error_date_required'))
      return
    }
    if (!editForm.appointment_time) {
      toast.error(t('schedule_error_time_required'))
      return
    }

    updateMutation.mutate({
      appointmentId: selectedAppointment.id,
      payload: {
        patient: editForm.patient,
        professional: editForm.professional,
        appointment_date: editForm.appointment_date,
        appointment_time: toApiTime(editForm.appointment_time),
        appointment_type: editForm.appointment_type,
        status: editForm.status,
        clinic_location: editForm.clinic_location,
        duration_minutes: Number(editForm.duration_minutes || 60),
        notes: editForm.notes,
      },
    })
  }

  const formatDateTime = (value?: string | null): string => {
    if (!value) return t('schedule_not_informed')
    const date = new Date(value)
    if (Number.isNaN(date.getTime())) return t('schedule_not_informed')
    return new Intl.DateTimeFormat(locale, {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(date)
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title={t('schedule_title')}
        subtitle={t('schedule_subtitle')}
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="secondary"
              onClick={() => void refetchAppointments()}
              disabled={isFetchingAppointments}
            >
              <RefreshCw className="h-4 w-4" />
              {isFetchingAppointments ? t('schedule_refreshing') : t('schedule_refresh')}
            </Button>
            <Button onClick={openCreateModal}>
              <Plus className="h-4 w-4" />
              {t('schedule_new_appointment')}
            </Button>
          </div>
        }
      />

      <Card className="space-y-4">
        {isLoadingAppointments ? (
          <p className="text-sm text-slate-500">{t('schedule_loading')}</p>
        ) : isAppointmentsError ? (
          <div className="space-y-2">
            <p className="text-sm text-rose-600">{appointmentsErrorMessage}</p>
            <Button variant="secondary" onClick={() => void refetchAppointments()}>
              <RefreshCw className="h-4 w-4" />
              {t('schedule_retry')}
            </Button>
          </div>
        ) : groupedAppointments.length ? (
          groupedAppointments.map((group) => (
            <div key={group.date} className="space-y-3">
              <div className="flex items-center gap-2 text-sm text-slate-600">
                <CalendarDays className="h-4 w-4" />
                {formatLongDate(group.date)}
              </div>

              {group.items.map((appointment) => {
                const patientAvatar = resolvePatientAvatar(appointment)
                const professionalAvatar = resolveProfessionalAvatar(appointment)

                return (
                  <div
                    key={appointment.id}
                    className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-slate-100 p-3"
                  >
                    <div className="flex items-center gap-3">
                      <Avatar
                        name={appointment.patient_name}
                        src={patientAvatar || professionalAvatar || undefined}
                        className="h-10 w-10"
                      />
                      <div>
                        <p className="text-sm font-semibold text-night">{appointment.patient_name}</p>
                        <p className="caption">
                          {appointmentTypeLabels[normalizeAppointmentType(appointment.appointment_type)]}
                        </p>
                        <div className="caption flex items-center gap-1 text-slate-500">
                          <Avatar
                            name={appointment.professional_name}
                            src={professionalAvatar || undefined}
                            className="h-5 w-5 text-[10px]"
                          />
                          <span>
                            {t('schedule_professional_prefix')}: {appointment.professional_name}
                          </span>
                        </div>
                      </div>
                    </div>

                    <div className="flex flex-wrap items-center gap-3 text-sm text-slate-600">
                      <span className="inline-flex items-center gap-1">
                        <Clock4 className="h-4 w-4" /> {toInputTime(appointment.appointment_time)}
                      </span>
                      <span className="inline-flex items-center gap-1">
                        <MapPin className="h-4 w-4" /> {appointment.clinic_location || t('schedule_default_room')}
                      </span>
                      <Badge status={appointment.status} />
                      {appointment.status !== 'cancelled' ? (
                        <Button
                          size="sm"
                          variant="danger"
                          onClick={() => openCancelModal(appointment)}
                          disabled={cancelMutation.isPending}
                        >
                          {t('schedule_cancel_appointment_button')}
                        </Button>
                      ) : null}
                      <Button size="sm" variant="secondary" onClick={() => openDetailsModal(appointment)}>
                        {t('schedule_details_button')}
                      </Button>
                    </div>
                  </div>
                )
              })}
            </div>
          ))
        ) : (
          <p className="text-sm text-slate-500">{t('schedule_empty')}</p>
        )}
      </Card>

      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title={t('schedule_modal_new_title')}
        className="max-w-3xl overflow-x-hidden"
      >
        <form className="grid min-w-0 gap-3" onSubmit={handleSubmit(onSubmit)}>
          <Select {...register('patient')}>
            <option value="">{t('schedule_select_patient')}</option>
            {patients.map((patient) => (
              <option key={patient.id} value={patient.id}>
                {patient.full_name}
              </option>
            ))}
          </Select>
          {errors.patient ? <p className="caption text-danger">{errors.patient.message}</p> : null}

          <Select
            {...register('professional', {
              onChange: () => {
                setSelectedSlot('')
                setValue('appointment_date', '')
                setValue('appointment_time', '')
                clearErrors(['appointment_date', 'appointment_time'])
              },
            })}
          >
            <option value="">{t('schedule_select_professional')}</option>
            {surgeons.map((surgeon) => (
              <option key={surgeon.id} value={surgeon.id}>
                {surgeon.name}
              </option>
            ))}
          </Select>
          {errors.professional ? <p className="caption text-danger">{errors.professional.message}</p> : null}

          <input type="hidden" {...register('appointment_date')} />
          <input type="hidden" {...register('appointment_time')} />

          <div className="min-w-0 rounded-lg border border-slate-200 p-3">
            <p className="text-sm font-semibold text-night">{t('schedule_availability_title')}</p>
            <p className="mt-1 text-xs text-slate-500">{t('schedule_availability_subtitle')}</p>

            <div className="mt-3 overflow-x-auto pb-1">
              <div className="flex min-w-max gap-2">
                {bookingDays.map((day) => {
                  const hasAvailability = dayHasAvailability[day]
                  const dayDate = new Date(`${day}T00:00:00`)
                  const weekday = new Intl.DateTimeFormat(locale, { weekday: 'short' })
                    .format(dayDate)
                    .replace('.', '')
                    .toUpperCase()
                  const dayNumber = new Intl.DateTimeFormat(locale, { day: '2-digit' }).format(dayDate)

                  return (
                    <button
                      key={day}
                      type="button"
                      onClick={() => {
                        setSelectedDay(day)
                        setSelectedSlot('')
                        setValue('appointment_date', day, { shouldValidate: true })
                        setValue('appointment_time', '', { shouldValidate: true })
                        clearErrors(['appointment_date', 'appointment_time'])
                      }}
                      className={[
                        'w-20 shrink-0 rounded-lg border px-2 py-2 text-center text-xs font-medium transition',
                        effectiveSelectedDay === day
                          ? 'border-primary bg-primary text-white'
                          : hasAvailability === true
                            ? 'border-emerald-300 bg-emerald-100 text-emerald-900'
                            : hasAvailability === false
                              ? 'border-rose-300 bg-rose-100 text-rose-900'
                              : 'border-slate-200 bg-white text-slate-700',
                      ].join(' ')}
                    >
                      <div className="uppercase">{weekday}</div>
                      <div className="text-base font-bold">{dayNumber}</div>
                    </button>
                  )
                })}
              </div>
            </div>

            {selectedProfessional ? (
              <div className="mt-3 flex items-center gap-4 text-xs text-slate-600">
                <span className="inline-flex items-center gap-1">
                  <span className="h-2.5 w-2.5 rounded-full border border-emerald-300 bg-emerald-100" />
                  {t('schedule_with_slots')}
                </span>
                <span className="inline-flex items-center gap-1">
                  <span className="h-2.5 w-2.5 rounded-full border border-rose-300 bg-rose-100" />
                  {t('schedule_without_slots')}
                </span>
              </div>
            ) : null}

            <div className="mt-3">
              {!selectedProfessional ? (
                <p className="text-xs text-slate-500">{t('schedule_select_professional_hint')}</p>
              ) : isFetchingAvailability ? (
                <p className="text-xs text-slate-500">{t('schedule_loading_availability')}</p>
              ) : selectedDaySlots.length ? (
                <div className="flex flex-wrap gap-2">
                  {selectedDaySlots.map((slot) => (
                    <button
                      key={slot}
                      type="button"
                      onClick={() => {
                        setSelectedSlot(slot)
                        setValue('appointment_date', effectiveSelectedDay, { shouldValidate: true })
                        setValue('appointment_time', slot, { shouldValidate: true })
                        clearErrors(['appointment_date', 'appointment_time'])
                      }}
                      className={[
                        'rounded-lg border px-3 py-1.5 text-xs font-medium transition',
                        selectedSlot === slot
                          ? 'border-primary bg-primary text-white'
                          : 'border-slate-200 bg-white text-slate-700 hover:bg-slate-50',
                      ].join(' ')}
                    >
                      {slot}
                    </button>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-rose-600">{t('schedule_no_slots_day')}</p>
              )}
            </div>
          </div>
          {errors.appointment_date ? <p className="caption text-danger">{errors.appointment_date.message}</p> : null}
          {errors.appointment_time ? <p className="caption text-danger">{errors.appointment_time.message}</p> : null}

          <Select {...register('appointment_type')}>
            <option value="first_visit">{t('schedule_type_first_visit')}</option>
            <option value="return">{t('schedule_type_return')}</option>
            <option value="surgery">{t('schedule_type_surgery')}</option>
            <option value="post_op_7d">{t('schedule_type_post_op_7d')}</option>
            <option value="post_op_30d">{t('schedule_type_post_op_30d')}</option>
            <option value="post_op_90d">{t('schedule_type_post_op_90d')}</option>
          </Select>
          {errors.appointment_type ? <p className="caption text-danger">{errors.appointment_type.message}</p> : null}

          <TextArea rows={3} placeholder={t('schedule_notes_optional')} {...register('notes')} />

          <div className="mt-2 flex justify-end gap-2">
            <Button type="button" variant="secondary" onClick={() => setIsModalOpen(false)}>
              {t('schedule_cancel')}
            </Button>
            <Button type="submit" disabled={createMutation.isPending || !selectedSlot}>
              {createMutation.isPending ? t('schedule_saving') : t('schedule_save')}
            </Button>
          </div>
        </form>
      </Modal>

      <Modal
        isOpen={isDetailsModalOpen}
        onClose={closeDetailsModal}
        title={t('schedule_modal_detail_title')}
        className="max-w-2xl"
      >
        {selectedAppointment && editForm ? (
          <div className="space-y-3">
            <div className="grid gap-2 rounded-lg border border-slate-200 bg-slate-50 p-3 text-xs text-slate-600 md:grid-cols-3">
              <p>
                <span className="overline block">{t('schedule_field_created_at')}</span>
                {formatDateTime(selectedAppointment.created_at)}
              </p>
              <p>
                <span className="overline block">{t('schedule_field_updated_at')}</span>
                {formatDateTime(selectedAppointment.updated_at)}
              </p>
              <p>
                <span className="overline block">{t('schedule_field_cancellation_reason')}</span>
                {selectedAppointment.cancellation_reason || t('schedule_not_informed')}
              </p>
            </div>

            <div>
              <p className="mb-1 text-xs font-semibold text-slate-600">{t('schedule_field_patient')}</p>
              <Select
                value={editForm.patient}
                onChange={(event) => setEditForm((prev) => (prev ? { ...prev, patient: event.target.value } : prev))}
              >
                <option value="">{t('schedule_select_patient')}</option>
                {patients.map((patient) => (
                  <option key={patient.id} value={patient.id}>
                    {patient.full_name}
                  </option>
                ))}
              </Select>
            </div>

            <div>
              <p className="mb-1 text-xs font-semibold text-slate-600">{t('schedule_field_professional')}</p>
              <Select
                value={editForm.professional}
                onChange={(event) =>
                  setEditForm((prev) => (prev ? { ...prev, professional: event.target.value } : prev))
                }
              >
                <option value="">{t('schedule_select_professional')}</option>
                {surgeons.map((surgeon) => (
                  <option key={surgeon.id} value={surgeon.id}>
                    {surgeon.name}
                  </option>
                ))}
              </Select>
            </div>

            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <p className="mb-1 text-xs font-semibold text-slate-600">{t('schedule_field_date')}</p>
                <Input
                  type="date"
                  value={editForm.appointment_date}
                  onChange={(event) =>
                    setEditForm((prev) => (prev ? { ...prev, appointment_date: event.target.value } : prev))
                  }
                />
              </div>
              <div>
                <p className="mb-1 text-xs font-semibold text-slate-600">{t('schedule_field_time')}</p>
                <Input
                  type="time"
                  value={editForm.appointment_time}
                  onChange={(event) =>
                    setEditForm((prev) => (prev ? { ...prev, appointment_time: event.target.value } : prev))
                  }
                />
              </div>
            </div>

            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <p className="mb-1 text-xs font-semibold text-slate-600">{t('schedule_field_type')}</p>
                <Select
                  value={editForm.appointment_type}
                  onChange={(event) =>
                    setEditForm((prev) =>
                      prev ? { ...prev, appointment_type: normalizeAppointmentType(event.target.value) } : prev,
                    )
                  }
                >
                  <option value="first_visit">{t('schedule_type_first_visit')}</option>
                  <option value="return">{t('schedule_type_return')}</option>
                  <option value="surgery">{t('schedule_type_surgery')}</option>
                  <option value="post_op_7d">{t('schedule_type_post_op_7d')}</option>
                  <option value="post_op_30d">{t('schedule_type_post_op_30d')}</option>
                  <option value="post_op_90d">{t('schedule_type_post_op_90d')}</option>
                </Select>
              </div>
              <div>
                <p className="mb-1 text-xs font-semibold text-slate-600">{t('schedule_field_status')}</p>
                <Select
                  value={editForm.status}
                  onChange={(event) =>
                    setEditForm((prev) => (prev ? { ...prev, status: event.target.value } : prev))
                  }
                >
                  {statusOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </Select>
              </div>
            </div>

            <div>
              <p className="mb-1 text-xs font-semibold text-slate-600">{t('schedule_field_location')}</p>
              <Input
                value={editForm.clinic_location}
                onChange={(event) =>
                  setEditForm((prev) => (prev ? { ...prev, clinic_location: event.target.value } : prev))
                }
                placeholder={t('schedule_default_room')}
              />
            </div>

            <div>
              <p className="mb-1 text-xs font-semibold text-slate-600">{t('schedule_field_duration')}</p>
              <Input
                type="number"
                min={15}
                step={5}
                value={String(editForm.duration_minutes || 60)}
                onChange={(event) =>
                  setEditForm((prev) =>
                    prev
                      ? {
                          ...prev,
                          duration_minutes: Number(event.target.value || 60),
                        }
                      : prev,
                  )
                }
              />
            </div>

            <div>
              <p className="mb-1 text-xs font-semibold text-slate-600">{t('schedule_field_notes')}</p>
              <TextArea
                rows={3}
                value={editForm.notes}
                onChange={(event) =>
                  setEditForm((prev) => (prev ? { ...prev, notes: event.target.value } : prev))
                }
                placeholder={t('schedule_notes_optional')}
              />
            </div>

            <div className="mt-2 flex justify-end gap-2">
              {selectedAppointment.status !== 'cancelled' ? (
                <Button
                  variant="danger"
                  onClick={() => openCancelModal(selectedAppointment)}
                  disabled={cancelMutation.isPending || updateMutation.isPending}
                >
                  {t('schedule_cancel_appointment_button')}
                </Button>
              ) : null}
              <Button variant="secondary" onClick={closeDetailsModal}>
                {t('schedule_cancel')}
              </Button>
              <Button onClick={handleSaveDetails} disabled={updateMutation.isPending}>
                {updateMutation.isPending ? t('schedule_saving') : t('schedule_save_changes')}
              </Button>
            </div>
          </div>
        ) : null}
      </Modal>

      <Modal
        isOpen={Boolean(cancelState)}
        onClose={closeCancelModal}
        title={t('schedule_cancel_modal_title')}
        className="max-w-lg"
      >
        {cancelState ? (
          <div className="space-y-5">
            <div className="rounded-2xl border border-danger/20 bg-danger/5 p-4">
              <div className="flex items-start gap-3">
                <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-danger/10 text-danger">
                  <AlertTriangle className="h-5 w-5" />
                </span>
                <div>
                  <p className="text-sm font-semibold text-night">{cancelState.appointment.patient_name}</p>
                  <p className="mt-1 text-sm text-slate-700">{t('schedule_cancel_modal_message')}</p>
                  <p className="mt-2 text-xs text-slate-500">{t('schedule_cancel_modal_hint')}</p>
                </div>
              </div>
            </div>

            <div>
              <p className="mb-1 text-xs font-semibold text-slate-600">{t('schedule_cancel_reason_label')}</p>
              <TextArea
                rows={3}
                value={cancelState.reason}
                onChange={(event) =>
                  setCancelState((prev) =>
                    prev
                      ? {
                          ...prev,
                          reason: event.target.value,
                        }
                      : prev,
                  )
                }
                placeholder={t('schedule_cancel_reason_placeholder')}
              />
            </div>

            <div className="flex justify-end gap-2">
              <Button
                variant="secondary"
                onClick={closeCancelModal}
                disabled={cancelMutation.isPending}
              >
                {t('schedule_cancel')}
              </Button>
              <Button
                variant="danger"
                onClick={handleConfirmCancel}
                disabled={cancelMutation.isPending}
              >
                {cancelMutation.isPending
                  ? t('schedule_saving')
                  : t('schedule_cancel_confirm_button')}
              </Button>
            </div>
          </div>
        ) : null}
      </Modal>
    </div>
  )
}
