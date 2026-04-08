import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import {
  GripVertical,
  Luggage,
  Pencil,
  Plane,
  Plus,
  RefreshCw,
  Trash2,
} from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import toast from 'react-hot-toast'

import {
  createTransfer,
  createTravelPlan,
  deleteTransfer,
  getTravelPlanAdminPatients,
  getTravelPlanById,
  type HotelInfo,
  type FlightInfo,
  type FlightDirection,
  type TransferItem,
  type TransferStatus,
  updateTransfer,
  updateTravelPlan,
  upsertFlight,
  upsertHotel,
} from '@/api/travelPlans'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Modal } from '@/components/ui/Modal'
import { Select } from '@/components/ui/Select'
import { TextArea } from '@/components/ui/TextArea'
import { t as translate, type TranslationKey } from '@/i18n/system'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { formatDate } from '@/utils/format'

const QUERY_ADMIN_PATIENTS = ['travel-plans-admin-patients'] as const
const QUERY_PLAN_DETAIL = 'travel-plan-detail'

const CUSTOM_TITLE_OPTION = '__custom__'
const TRANSFER_PRESET_TITLES = [
  { value: 'Transfer Aeroporto Hotel', labelKey: 'travel_plans_preset_airport_hotel' },
  { value: 'Transfer Hotel Clinica Dia da Cirurgia', labelKey: 'travel_plans_preset_hotel_clinic_surgery_day' },
  { value: 'Transfer Clinica Hotel Apos Cirurgia', labelKey: 'travel_plans_preset_clinic_hotel_after_surgery' },
  { value: 'Transfer Hotel Clinica Revisao', labelKey: 'travel_plans_preset_hotel_clinic_followup' },
  { value: 'Transfer Clinica Hotel Apos Revisao', labelKey: 'travel_plans_preset_clinic_hotel_after_followup' },
  { value: 'Transfer Hotel Aeroporto', labelKey: 'travel_plans_preset_hotel_airport' },
] as const satisfies ReadonlyArray<{ value: string; labelKey: TranslationKey }>
const TRANSFER_STATUS_ORDER: TransferStatus[] = ['scheduled', 'confirmed', 'completed', 'cancelled']

const TRANSFER_STATUS_BADGE_CLASS: Record<TransferStatus, string> = {
  scheduled: 'bg-amber-100 text-amber-700',
  confirmed: 'bg-teal-100 text-teal-700',
  completed: 'bg-emerald-100 text-emerald-700',
  cancelled: 'bg-slate-100 text-slate-700',
}

type EditorTab = 'flights' | 'hotel' | 'transfers'

interface FlightFormState {
  flight_number: string
  flight_date: string
  flight_time: string
  airport: string
  airline: string
  observations: string
}

interface HotelFormState {
  hotel_name: string
  address: string
  checkin_date: string
  checkin_time: string
  checkout_date: string
  checkout_time: string
  room_number: string
  hotel_phone: string
  location_link: string
  observations: string
}

interface TransferFormState {
  title_option: string
  custom_title: string
  transfer_date: string
  transfer_time: string
  origin: string
  destination: string
  observations: string
  status: TransferStatus
}

const EMPTY_FLIGHT_FORM: FlightFormState = {
  flight_number: '',
  flight_date: '',
  flight_time: '',
  airport: '',
  airline: '',
  observations: '',
}

const EMPTY_HOTEL_FORM: HotelFormState = {
  hotel_name: '',
  address: '',
  checkin_date: '',
  checkin_time: '',
  checkout_date: '',
  checkout_time: '',
  room_number: '',
  hotel_phone: '',
  location_link: '',
  observations: '',
}

const EMPTY_TRANSFER_FORM: TransferFormState = {
  title_option: TRANSFER_PRESET_TITLES[0].value,
  custom_title: '',
  transfer_date: '',
  transfer_time: '',
  origin: '',
  destination: '',
  observations: '',
  status: 'scheduled',
}

function normalizeApiTime(value: string | null | undefined): string {
  if (!value) return ''
  return value.slice(0, 5)
}

function toApiTime(value: string): string {
  if (!value) return ''
  return value.length === 5 ? `${value}:00` : value
}

function toFlightForm(value: FlightInfo | null): FlightFormState {
  if (!value) return { ...EMPTY_FLIGHT_FORM }
  return {
    flight_number: value.flight_number || '',
    flight_date: value.flight_date || '',
    flight_time: normalizeApiTime(value.flight_time),
    airport: value.airport || '',
    airline: value.airline || '',
    observations: value.observations || '',
  }
}

function toHotelForm(value: HotelInfo | null): HotelFormState {
  if (!value) return { ...EMPTY_HOTEL_FORM }
  return {
    hotel_name: value.hotel_name || '',
    address: value.address || '',
    checkin_date: value.checkin_date || '',
    checkin_time: normalizeApiTime(value.checkin_time),
    checkout_date: value.checkout_date || '',
    checkout_time: normalizeApiTime(value.checkout_time),
    room_number: value.room_number || '',
    hotel_phone: value.hotel_phone || '',
    location_link: value.location_link || '',
    observations: value.observations || '',
  }
}

function normalizeTransfersOrder(items: TransferItem[]): TransferItem[] {
  return [...items]
    .sort((a, b) => {
      if (a.display_order !== b.display_order) {
        return a.display_order - b.display_order
      }
      if (a.transfer_date !== b.transfer_date) {
        return a.transfer_date.localeCompare(b.transfer_date)
      }
      return a.transfer_time.localeCompare(b.transfer_time)
    })
    .map((item, index) => ({ ...item, display_order: index }))
}

function reorderTransfers(items: TransferItem[], fromId: string, toId: string): TransferItem[] {
  const fromIndex = items.findIndex((item) => item.id === fromId)
  const toIndex = items.findIndex((item) => item.id === toId)
  if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return items

  const nextItems = [...items]
  const [moved] = nextItems.splice(fromIndex, 1)
  if (!moved) return items
  nextItems.splice(toIndex, 0, moved)
  return normalizeTransfersOrder(nextItems)
}

function getTransferFormTitle(form: TransferFormState): string {
  if (form.title_option === CUSTOM_TITLE_OPTION) {
    return form.custom_title.trim()
  }
  return form.title_option.trim()
}

function toTransferForm(transfer: TransferItem): TransferFormState {
  const isPreset = TRANSFER_PRESET_TITLES.some((item) => item.value === transfer.title)
  return {
    title_option: isPreset ? transfer.title : CUSTOM_TITLE_OPTION,
    custom_title: isPreset ? '' : transfer.title,
    transfer_date: transfer.transfer_date,
    transfer_time: normalizeApiTime(transfer.transfer_time),
    origin: transfer.origin,
    destination: transfer.destination,
    observations: transfer.observations || '',
    status: transfer.status,
  }
}

function extractErrorMessage(error: unknown, fallback: string): string {
  if (!isAxiosError(error)) return fallback
  const responseData = error.response?.data as
    | {
        detail?: string
        patient_id?: string[]
        non_field_errors?: string[]
      }
    | undefined

  if (responseData?.detail) return responseData.detail
  if (Array.isArray(responseData?.patient_id) && responseData.patient_id[0]) {
    return responseData.patient_id[0]
  }
  if (Array.isArray(responseData?.non_field_errors) && responseData.non_field_errors[0]) {
    return responseData.non_field_errors[0]
  }
  return fallback
}

function transferStatusLabel(status: TransferStatus, t: (key: TranslationKey) => string): string {
  if (status === 'scheduled') return t('travel_plans_status_scheduled')
  if (status === 'confirmed') return t('travel_plans_status_confirmed')
  if (status === 'completed') return t('travel_plans_status_completed')
  return t('travel_plans_status_cancelled')
}

function transferPresetLabel(value: string, t: (key: TranslationKey) => string): string {
  const match = TRANSFER_PRESET_TITLES.find((item) => item.value === value)
  if (!match) return value
  return t(match.labelKey)
}

export default function TravelPlansPage() {
  const language = usePreferencesStore((state) => state.language)
  const t = (key: TranslationKey) => translate(language, key)
  const queryClient = useQueryClient()

  const [isEditorOpen, setIsEditorOpen] = useState(false)
  const [activeTab, setActiveTab] = useState<EditorTab>('flights')
  const [selectedPatientId, setSelectedPatientId] = useState('')
  const [editingPlanId, setEditingPlanId] = useState<string | null>(null)
  const [passportNumber, setPassportNumber] = useState('')
  const [arrivalFlight, setArrivalFlight] = useState<FlightFormState>({ ...EMPTY_FLIGHT_FORM })
  const [departureFlight, setDepartureFlight] = useState<FlightFormState>({ ...EMPTY_FLIGHT_FORM })
  const [hotelForm, setHotelForm] = useState<HotelFormState>({ ...EMPTY_HOTEL_FORM })
  const [transfers, setTransfers] = useState<TransferItem[]>([])
  const [transferForm, setTransferForm] = useState<TransferFormState>({ ...EMPTY_TRANSFER_FORM })
  const [editingTransferId, setEditingTransferId] = useState<string | null>(null)
  const [draggingTransferId, setDraggingTransferId] = useState<string | null>(null)

  const adminPatientsQuery = useQuery({
    queryKey: QUERY_ADMIN_PATIENTS,
    queryFn: getTravelPlanAdminPatients,
    refetchOnMount: 'always',
  })

  const planDetailQuery = useQuery({
    queryKey: [QUERY_PLAN_DETAIL, editingPlanId],
    queryFn: () => getTravelPlanById(editingPlanId || ''),
    enabled: Boolean(isEditorOpen && editingPlanId),
  })

  const currentPatient = useMemo(() => {
    if (!adminPatientsQuery.data || !selectedPatientId) return null
    return adminPatientsQuery.data.find((item) => item.patient_id === selectedPatientId) || null
  }, [adminPatientsQuery.data, selectedPatientId])

  const patientsWithPlans = useMemo(
    () => (adminPatientsQuery.data || []).filter((item) => Boolean(item.travel_plan_id)),
    [adminPatientsQuery.data],
  )

  const availablePatientsForNewPlan = useMemo(
    () => (adminPatientsQuery.data || []).filter((item) => !item.travel_plan_id),
    [adminPatientsQuery.data],
  )

  /* eslint-disable react-hooks/set-state-in-effect */
  useEffect(() => {
    if (!planDetailQuery.data) return

    const plan = planDetailQuery.data
    setSelectedPatientId(plan.patient)
    setPassportNumber(plan.passport_number || '')
    setArrivalFlight(toFlightForm(plan.arrival_flight))
    setDepartureFlight(toFlightForm(plan.departure_flight))
    setHotelForm(toHotelForm(plan.hotel))
    setTransfers(normalizeTransfersOrder(plan.transfers || []))
    setTransferForm({ ...EMPTY_TRANSFER_FORM })
    setEditingTransferId(null)
  }, [planDetailQuery.data])
  /* eslint-enable react-hooks/set-state-in-effect */

  const createPlanMutation = useMutation({
    mutationFn: createTravelPlan,
    onSuccess: async (plan) => {
      setEditingPlanId(plan.id)
      setSelectedPatientId(plan.patient)
      setPassportNumber(plan.passport_number || '')
      setArrivalFlight(toFlightForm(plan.arrival_flight))
      setDepartureFlight(toFlightForm(plan.departure_flight))
      setHotelForm(toHotelForm(plan.hotel))
      setTransfers(normalizeTransfersOrder(plan.transfers || []))
      setActiveTab('flights')
      await queryClient.invalidateQueries({ queryKey: QUERY_ADMIN_PATIENTS })
      toast.success(t('travel_plans_create_success'))
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('travel_plans_create_error')))
    },
  })

  const updatePlanMutation = useMutation({
    mutationFn: ({ planId, passport }: { planId: string; passport: string }) =>
      updateTravelPlan(planId, { passport_number: passport }),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: QUERY_ADMIN_PATIENTS }),
        queryClient.invalidateQueries({ queryKey: [QUERY_PLAN_DETAIL, editingPlanId] }),
      ])
      toast.success(t('travel_plans_plan_updated'))
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('travel_plans_plan_update_error')))
    },
  })

  const upsertFlightMutation = useMutation({
    mutationFn: ({
      planId,
      direction,
      form,
    }: {
      planId: string
      direction: FlightDirection
      form: FlightFormState
    }) =>
      upsertFlight(planId, {
        direction,
        flight_number: form.flight_number.trim(),
        flight_date: form.flight_date,
        flight_time: toApiTime(form.flight_time),
        airport: form.airport.trim(),
        airline: form.airline.trim(),
        observations: form.observations.trim(),
      }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: [QUERY_PLAN_DETAIL, editingPlanId] })
      await queryClient.invalidateQueries({ queryKey: QUERY_ADMIN_PATIENTS })
      toast.success(t('travel_plans_flight_saved'))
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('travel_plans_flight_save_error')))
    },
  })

  const upsertHotelMutation = useMutation({
    mutationFn: ({ planId, form }: { planId: string; form: HotelFormState }) =>
      upsertHotel(planId, {
        hotel_name: form.hotel_name.trim(),
        address: form.address.trim(),
        checkin_date: form.checkin_date,
        checkin_time: toApiTime(form.checkin_time),
        checkout_date: form.checkout_date,
        checkout_time: toApiTime(form.checkout_time),
        room_number: form.room_number.trim(),
        hotel_phone: form.hotel_phone.trim(),
        location_link: form.location_link.trim(),
        observations: form.observations.trim(),
      }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: [QUERY_PLAN_DETAIL, editingPlanId] })
      await queryClient.invalidateQueries({ queryKey: QUERY_ADMIN_PATIENTS })
      toast.success(t('travel_plans_hotel_saved'))
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('travel_plans_hotel_save_error')))
    },
  })

  const createTransferMutation = useMutation({
    mutationFn: ({ planId, transfer }: { planId: string; transfer: TransferFormState }) =>
      createTransfer(planId, {
        title: getTransferFormTitle(transfer),
        transfer_date: transfer.transfer_date,
        transfer_time: toApiTime(transfer.transfer_time),
        origin: transfer.origin.trim(),
        destination: transfer.destination.trim(),
        observations: transfer.observations.trim(),
        status: transfer.status,
        display_order: transfers.length,
      }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: [QUERY_PLAN_DETAIL, editingPlanId] })
      await queryClient.invalidateQueries({ queryKey: QUERY_ADMIN_PATIENTS })
      setTransferForm({ ...EMPTY_TRANSFER_FORM })
      setEditingTransferId(null)
      toast.success(t('travel_plans_transfer_added'))
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('travel_plans_transfer_add_error')))
    },
  })

  const updateTransferMutation = useMutation({
    mutationFn: ({
      transferId,
      payload,
    }: {
      transferId: string
      payload: Partial<{
        title: string
        transfer_date: string
        transfer_time: string
        origin: string
        destination: string
        observations: string
        status: TransferStatus
        display_order: number
      }>
    }) => updateTransfer(transferId, payload),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: [QUERY_PLAN_DETAIL, editingPlanId] })
      await queryClient.invalidateQueries({ queryKey: QUERY_ADMIN_PATIENTS })
    },
  })

  const deleteTransferMutation = useMutation({
    mutationFn: deleteTransfer,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: [QUERY_PLAN_DETAIL, editingPlanId] })
      await queryClient.invalidateQueries({ queryKey: QUERY_ADMIN_PATIENTS })
      setTransferForm({ ...EMPTY_TRANSFER_FORM })
      setEditingTransferId(null)
      toast.success(t('travel_plans_transfer_removed'))
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, t('travel_plans_transfer_remove_error')))
    },
  })

  const closeEditor = () => {
    setIsEditorOpen(false)
    setActiveTab('flights')
    setSelectedPatientId('')
    setEditingPlanId(null)
    setPassportNumber('')
    setArrivalFlight({ ...EMPTY_FLIGHT_FORM })
    setDepartureFlight({ ...EMPTY_FLIGHT_FORM })
    setHotelForm({ ...EMPTY_HOTEL_FORM })
    setTransfers([])
    setTransferForm({ ...EMPTY_TRANSFER_FORM })
    setEditingTransferId(null)
    setDraggingTransferId(null)
  }

  const openCreatePlanModal = () => {
    const firstPatient = availablePatientsForNewPlan[0]?.patient_id || ''
    setIsEditorOpen(true)
    setActiveTab('flights')
    setSelectedPatientId(firstPatient)
    setEditingPlanId(null)
    setPassportNumber('')
    setArrivalFlight({ ...EMPTY_FLIGHT_FORM })
    setDepartureFlight({ ...EMPTY_FLIGHT_FORM })
    setHotelForm({ ...EMPTY_HOTEL_FORM })
    setTransfers([])
    setTransferForm({ ...EMPTY_TRANSFER_FORM })
    setEditingTransferId(null)
  }

  const openEditPlanModal = (travelPlanId: string, patientId: string) => {
    setIsEditorOpen(true)
    setActiveTab('flights')
    setEditingPlanId(travelPlanId)
    setSelectedPatientId(patientId)
    setTransferForm({ ...EMPTY_TRANSFER_FORM })
    setEditingTransferId(null)
  }

  const handleCreatePlan = async () => {
    if (!selectedPatientId) {
      toast.error(t('travel_plans_select_patient_to_create'))
      return
    }

    await createPlanMutation.mutateAsync({ patient_id: selectedPatientId })
  }

  const handleSavePlan = async () => {
    if (!editingPlanId) return
    await updatePlanMutation.mutateAsync({ planId: editingPlanId, passport: passportNumber.trim() })
  }

  const handleSaveFlight = async (direction: FlightDirection, form: FlightFormState) => {
    if (!editingPlanId) return
    if (!form.flight_number || !form.flight_date || !form.flight_time || !form.airport) {
      toast.error(t('travel_plans_required_flight_fields'))
      return
    }

    await upsertFlightMutation.mutateAsync({
      planId: editingPlanId,
      direction,
      form,
    })
  }

  const handleSaveHotel = async () => {
    if (!editingPlanId) return
    if (
      !hotelForm.hotel_name.trim() ||
      !hotelForm.address.trim() ||
      !hotelForm.checkin_date ||
      !hotelForm.checkin_time ||
      !hotelForm.checkout_date ||
      !hotelForm.checkout_time
    ) {
      toast.error(t('travel_plans_required_hotel_fields'))
      return
    }

    await upsertHotelMutation.mutateAsync({ planId: editingPlanId, form: hotelForm })
  }

  const handleSubmitTransfer = async () => {
    if (!editingPlanId) return

    const title = getTransferFormTitle(transferForm)
    if (
      !title ||
      !transferForm.transfer_date ||
      !transferForm.transfer_time ||
      !transferForm.origin.trim() ||
      !transferForm.destination.trim()
    ) {
      toast.error(t('travel_plans_required_transfer_fields'))
      return
    }

    if (!editingTransferId) {
      await createTransferMutation.mutateAsync({
        planId: editingPlanId,
        transfer: transferForm,
      })
      return
    }

    await updateTransferMutation.mutateAsync({
      transferId: editingTransferId,
      payload: {
        title,
        transfer_date: transferForm.transfer_date,
        transfer_time: toApiTime(transferForm.transfer_time),
        origin: transferForm.origin.trim(),
        destination: transferForm.destination.trim(),
        observations: transferForm.observations.trim(),
        status: transferForm.status,
      },
    })

    setTransferForm({ ...EMPTY_TRANSFER_FORM })
    setEditingTransferId(null)
    toast.success(t('travel_plans_transfer_updated'))
  }

  const handleEditTransfer = (transfer: TransferItem) => {
    setTransferForm(toTransferForm(transfer))
    setEditingTransferId(transfer.id)
  }

  const handleDeleteTransfer = async (transferId: string) => {
    const shouldDelete = window.confirm(t('travel_plans_delete_transfer_confirm'))
    if (!shouldDelete) return

    await deleteTransferMutation.mutateAsync(transferId)
  }

  const handleCycleTransferStatus = async (transfer: TransferItem) => {
    const currentIndex = TRANSFER_STATUS_ORDER.indexOf(transfer.status)
    const nextStatus = TRANSFER_STATUS_ORDER[(currentIndex + 1) % TRANSFER_STATUS_ORDER.length]

    await updateTransferMutation.mutateAsync({
      transferId: transfer.id,
      payload: { status: nextStatus },
    })
    toast.success(`${t('travel_plans_status_changed_to')} ${transferStatusLabel(nextStatus, t)}.`)
  }

  const persistTransferOrder = async (orderedTransfers: TransferItem[]) => {
    const updates = orderedTransfers
      .map((item, index) => ({ item, index }))
      .filter(({ item, index }) => item.display_order !== index)

    if (updates.length === 0) return

    try {
      await Promise.all(
        updates.map(({ item, index }) => updateTransfer(item.id, { display_order: index })),
      )
      await queryClient.invalidateQueries({ queryKey: [QUERY_PLAN_DETAIL, editingPlanId] })
      await queryClient.invalidateQueries({ queryKey: QUERY_ADMIN_PATIENTS })
      toast.success(t('travel_plans_order_saved'))
    } catch (error) {
      toast.error(extractErrorMessage(error, t('travel_plans_order_error')))
      await queryClient.invalidateQueries({ queryKey: [QUERY_PLAN_DETAIL, editingPlanId] })
    }
  }

  const handleDropTransfer = (targetTransferId: string) => {
    if (!draggingTransferId) return
    if (draggingTransferId === targetTransferId) {
      setDraggingTransferId(null)
      return
    }

    const reordered = reorderTransfers(transfers, draggingTransferId, targetTransferId)
    setTransfers(reordered)
    setDraggingTransferId(null)
    void persistTransferOrder(reordered)
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title={t('travel_plans_title')}
        subtitle={t('travel_plans_subtitle')}
        actions={(
          <>
            <Button
              type="button"
              variant="secondary"
              onClick={() => void adminPatientsQuery.refetch()}
              disabled={adminPatientsQuery.isFetching}
            >
              <RefreshCw className={`h-4 w-4 ${adminPatientsQuery.isFetching ? 'animate-spin' : ''}`} />
              {t('travel_plans_refresh')}
            </Button>
            <Button type="button" onClick={openCreatePlanModal}>
              <Plus className="h-4 w-4" />
              {t('travel_plans_new_plan')}
            </Button>
          </>
        )}
      />

      <Card padded={false} className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">{t('travel_plans_col_patient')}</th>
                <th className="px-4 py-3 text-left overline">{t('travel_plans_col_arrival_date')}</th>
                <th className="px-4 py-3 text-left overline">{t('travel_plans_col_hotel')}</th>
                <th className="px-4 py-3 text-left overline">{t('travel_plans_col_transfers')}</th>
                <th className="px-4 py-3 text-left overline">{t('travel_plans_col_next_transfer_status')}</th>
                <th className="px-4 py-3 text-right overline">{t('travel_plans_col_actions')}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {adminPatientsQuery.isLoading ? (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-sm text-slate-500">
                    {t('travel_plans_loading')}
                  </td>
                </tr>
              ) : adminPatientsQuery.isError ? (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-sm text-slate-500">
                    {t('travel_plans_load_error')}
                  </td>
                </tr>
              ) : patientsWithPlans.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-sm text-slate-500">
                    {t('travel_plans_empty')}
                  </td>
                </tr>
              ) : (
                patientsWithPlans.map((item) => {
                  const status = item.next_transfer_status as TransferStatus | ''
                  const statusLabel = status ? transferStatusLabel(status, t) : '-'
                  const statusClass = status ? TRANSFER_STATUS_BADGE_CLASS[status] : ''

                  return (
                    <tr key={item.patient_id} className="hover:bg-tealIce/50">
                      <td className="px-4 py-3 text-sm font-semibold text-night">{item.patient_name}</td>
                      <td className="px-4 py-3 text-sm text-slate-600">
                        {item.arrival_date ? formatDate(item.arrival_date) : '-'}
                      </td>
                      <td className="px-4 py-3 text-sm text-slate-600">{item.hotel_name || '-'}</td>
                      <td className="px-4 py-3 text-sm text-slate-600">{item.transfers_count}</td>
                      <td className="px-4 py-3">
                        {status ? (
                          <Badge className={statusClass}>{statusLabel}</Badge>
                        ) : (
                          <span className="text-sm text-slate-500">-</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-right">
                        {item.travel_plan_id ? (
                          <Button
                            type="button"
                            size="sm"
                            variant="secondary"
                            onClick={() => openEditPlanModal(item.travel_plan_id as string, item.patient_id)}
                          >
                            <Pencil className="h-4 w-4" />
                            {t('travel_plans_edit_plan')}
                          </Button>
                        ) : (
                          <span className="text-sm text-slate-500">-</span>
                        )}
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
      </Card>

      <Modal
        isOpen={isEditorOpen}
        onClose={closeEditor}
        title={editingPlanId ? t('travel_plans_modal_edit_title') : t('travel_plans_modal_new_title')}
        className="max-w-6xl"
      >
        {!editingPlanId ? (
          <div className="space-y-4">
            <Card className="border-dashed border-slate-300 bg-slate-50">
              <p className="mb-2 text-sm font-semibold text-night">{t('travel_plans_select_patient')}</p>
              <Select
                value={selectedPatientId}
                onChange={(event) => setSelectedPatientId(event.target.value)}
              >
                <option value="">{t('travel_plans_select')}</option>
                {availablePatientsForNewPlan.map((item) => (
                  <option key={item.patient_id} value={item.patient_id}>
                    {item.patient_name}
                  </option>
                ))}
              </Select>
              {availablePatientsForNewPlan.length === 0 ? (
                <p className="mt-2 text-xs text-slate-500">
                  {t('travel_plans_all_patients_have_plan')}
                </p>
              ) : null}
              <div className="mt-3 flex justify-end">
                <Button
                  type="button"
                  onClick={() => void handleCreatePlan()}
                  disabled={!selectedPatientId || createPlanMutation.isPending}
                >
                  <Luggage className="h-4 w-4" />
                  {createPlanMutation.isPending ? t('travel_plans_creating') : t('travel_plans_create')}
                </Button>
              </div>
            </Card>
          </div>
        ) : planDetailQuery.isLoading ? (
          <div className="py-10 text-center text-sm text-slate-500">{t('travel_plans_loading_plan')}</div>
        ) : planDetailQuery.isError ? (
          <div className="py-10 text-center text-sm text-slate-500">
            {t('travel_plans_load_plan_error')}
          </div>
        ) : (
          <div className="space-y-4">
            <Card>
              <div className="grid gap-3 md:grid-cols-[1fr_300px_auto] md:items-end">
                <div>
                  <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{t('travel_plans_patient_label')}</p>
                  <p className="text-sm font-semibold text-night">{currentPatient?.patient_name || '-'}</p>
                </div>
                <div>
                  <p className="mb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
                    {t('travel_plans_passport_label')}
                  </p>
                  <Input
                    value={passportNumber}
                    onChange={(event) => setPassportNumber(event.target.value)}
                    placeholder={t('travel_plans_passport_placeholder')}
                  />
                </div>
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => void handleSavePlan()}
                  disabled={updatePlanMutation.isPending}
                >
                  {t('travel_plans_save_plan')}
                </Button>
              </div>
            </Card>

            <Card>
              <div className="flex flex-wrap gap-2">
                <Button
                  type="button"
                  variant={activeTab === 'flights' ? 'primary' : 'secondary'}
                  onClick={() => setActiveTab('flights')}
                >
                  <Plane className="h-4 w-4" />
                  {t('travel_plans_tab_flights')}
                </Button>
                <Button
                  type="button"
                  variant={activeTab === 'hotel' ? 'primary' : 'secondary'}
                  onClick={() => setActiveTab('hotel')}
                >
                  {t('travel_plans_tab_hotel')}
                </Button>
                <Button
                  type="button"
                  variant={activeTab === 'transfers' ? 'primary' : 'secondary'}
                  onClick={() => setActiveTab('transfers')}
                >
                  {t('travel_plans_tab_transfers')}
                </Button>
              </div>
            </Card>

            {activeTab === 'flights' ? (
              <div className="grid gap-4 xl:grid-cols-2">
                <Card>
                  <h3 className="section-heading mb-3">{t('travel_plans_arrival_flight')}</h3>
                  <div className="grid gap-3 md:grid-cols-2">
                    <Input
                      value={arrivalFlight.flight_number}
                      onChange={(event) =>
                        setArrivalFlight((prev) => ({ ...prev, flight_number: event.target.value }))
                      }
                      placeholder={t('travel_plans_flight_number_placeholder')}
                    />
                    <Input
                      type="date"
                      value={arrivalFlight.flight_date}
                      onChange={(event) =>
                        setArrivalFlight((prev) => ({ ...prev, flight_date: event.target.value }))
                      }
                    />
                    <Input
                      type="time"
                      value={arrivalFlight.flight_time}
                      onChange={(event) =>
                        setArrivalFlight((prev) => ({ ...prev, flight_time: event.target.value }))
                      }
                    />
                    <Input
                      value={arrivalFlight.airline}
                      onChange={(event) =>
                        setArrivalFlight((prev) => ({ ...prev, airline: event.target.value }))
                      }
                      placeholder={t('travel_plans_airline_placeholder')}
                    />
                    <Input
                      className="md:col-span-2"
                      value={arrivalFlight.airport}
                      onChange={(event) =>
                        setArrivalFlight((prev) => ({ ...prev, airport: event.target.value }))
                      }
                      placeholder={t('travel_plans_airport_placeholder')}
                    />
                    <TextArea
                      className="md:col-span-2"
                      rows={3}
                      value={arrivalFlight.observations}
                      onChange={(event) =>
                        setArrivalFlight((prev) => ({ ...prev, observations: event.target.value }))
                      }
                      placeholder={t('travel_plans_observations_placeholder')}
                    />
                  </div>
                  <div className="mt-3 flex justify-end">
                    <Button
                      type="button"
                      onClick={() => void handleSaveFlight('arrival', arrivalFlight)}
                      disabled={upsertFlightMutation.isPending}
                    >
                      {t('travel_plans_save_arrival_flight')}
                    </Button>
                  </div>
                </Card>

                <Card>
                  <h3 className="section-heading mb-3">{t('travel_plans_departure_flight')}</h3>
                  <div className="grid gap-3 md:grid-cols-2">
                    <Input
                      value={departureFlight.flight_number}
                      onChange={(event) =>
                        setDepartureFlight((prev) => ({ ...prev, flight_number: event.target.value }))
                      }
                      placeholder={t('travel_plans_flight_number_placeholder')}
                    />
                    <Input
                      type="date"
                      value={departureFlight.flight_date}
                      onChange={(event) =>
                        setDepartureFlight((prev) => ({ ...prev, flight_date: event.target.value }))
                      }
                    />
                    <Input
                      type="time"
                      value={departureFlight.flight_time}
                      onChange={(event) =>
                        setDepartureFlight((prev) => ({ ...prev, flight_time: event.target.value }))
                      }
                    />
                    <Input
                      value={departureFlight.airline}
                      onChange={(event) =>
                        setDepartureFlight((prev) => ({ ...prev, airline: event.target.value }))
                      }
                      placeholder={t('travel_plans_airline_placeholder')}
                    />
                    <Input
                      className="md:col-span-2"
                      value={departureFlight.airport}
                      onChange={(event) =>
                        setDepartureFlight((prev) => ({ ...prev, airport: event.target.value }))
                      }
                      placeholder={t('travel_plans_airport_placeholder')}
                    />
                    <TextArea
                      className="md:col-span-2"
                      rows={3}
                      value={departureFlight.observations}
                      onChange={(event) =>
                        setDepartureFlight((prev) => ({ ...prev, observations: event.target.value }))
                      }
                      placeholder={t('travel_plans_observations_placeholder')}
                    />
                  </div>
                  <div className="mt-3 flex justify-end">
                    <Button
                      type="button"
                      onClick={() => void handleSaveFlight('departure', departureFlight)}
                      disabled={upsertFlightMutation.isPending}
                    >
                      {t('travel_plans_save_departure_flight')}
                    </Button>
                  </div>
                </Card>
              </div>
            ) : null}

            {activeTab === 'hotel' ? (
              <Card>
                <h3 className="section-heading mb-3">{t('travel_plans_hotel_info')}</h3>
                <div className="grid gap-3 md:grid-cols-2">
                  <Input
                    value={hotelForm.hotel_name}
                    onChange={(event) => setHotelForm((prev) => ({ ...prev, hotel_name: event.target.value }))}
                    placeholder={t('travel_plans_hotel_name_placeholder')}
                  />
                  <Input
                    value={hotelForm.hotel_phone}
                    onChange={(event) => setHotelForm((prev) => ({ ...prev, hotel_phone: event.target.value }))}
                    placeholder={t('travel_plans_hotel_phone_placeholder')}
                  />
                  <Input
                    className="md:col-span-2"
                    value={hotelForm.address}
                    onChange={(event) => setHotelForm((prev) => ({ ...prev, address: event.target.value }))}
                    placeholder={t('travel_plans_address_placeholder')}
                  />
                  <Input
                    type="date"
                    value={hotelForm.checkin_date}
                    onChange={(event) => setHotelForm((prev) => ({ ...prev, checkin_date: event.target.value }))}
                  />
                  <Input
                    type="time"
                    value={hotelForm.checkin_time}
                    onChange={(event) => setHotelForm((prev) => ({ ...prev, checkin_time: event.target.value }))}
                  />
                  <Input
                    type="date"
                    value={hotelForm.checkout_date}
                    onChange={(event) => setHotelForm((prev) => ({ ...prev, checkout_date: event.target.value }))}
                  />
                  <Input
                    type="time"
                    value={hotelForm.checkout_time}
                    onChange={(event) => setHotelForm((prev) => ({ ...prev, checkout_time: event.target.value }))}
                  />
                  <Input
                    value={hotelForm.room_number}
                    onChange={(event) => setHotelForm((prev) => ({ ...prev, room_number: event.target.value }))}
                    placeholder={t('travel_plans_room_number_placeholder')}
                  />
                  <Input
                    value={hotelForm.location_link}
                    onChange={(event) => setHotelForm((prev) => ({ ...prev, location_link: event.target.value }))}
                    placeholder={t('travel_plans_maps_link_placeholder')}
                  />
                  <TextArea
                    className="md:col-span-2"
                    rows={3}
                    value={hotelForm.observations}
                    onChange={(event) => setHotelForm((prev) => ({ ...prev, observations: event.target.value }))}
                    placeholder={t('travel_plans_observations_placeholder')}
                  />
                </div>

                <div className="mt-3 flex justify-end">
                  <Button
                    type="button"
                    onClick={() => void handleSaveHotel()}
                    disabled={upsertHotelMutation.isPending}
                  >
                    {t('travel_plans_save_hotel')}
                  </Button>
                </div>
              </Card>
            ) : null}

            {activeTab === 'transfers' ? (
              <div className="space-y-4">
                <Card>
                  <div className="mb-3 flex items-center justify-between">
                    <h3 className="section-heading">
                      {editingTransferId ? t('travel_plans_transfer_edit_title') : t('travel_plans_transfer_add_title')}
                    </h3>
                    {editingTransferId ? (
                      <Button
                        type="button"
                        size="sm"
                        variant="secondary"
                        onClick={() => {
                          setEditingTransferId(null)
                          setTransferForm({ ...EMPTY_TRANSFER_FORM })
                        }}
                      >
                        {t('travel_plans_cancel_edit')}
                      </Button>
                    ) : null}
                  </div>

                  <div className="grid gap-3 md:grid-cols-2">
                    <Select
                      value={transferForm.title_option}
                      onChange={(event) =>
                        setTransferForm((prev) => ({
                          ...prev,
                          title_option: event.target.value,
                        }))
                      }
                    >
                      {TRANSFER_PRESET_TITLES.map((option) => (
                        <option key={option.value} value={option.value}>
                          {t(option.labelKey)}
                        </option>
                      ))}
                      <option value={CUSTOM_TITLE_OPTION}>{t('travel_plans_custom_title_option')}</option>
                    </Select>

                    <Select
                      value={transferForm.status}
                      onChange={(event) =>
                        setTransferForm((prev) => ({
                          ...prev,
                          status: event.target.value as TransferStatus,
                        }))
                      }
                    >
                      <option value="scheduled">{t('travel_plans_status_scheduled')}</option>
                      <option value="confirmed">{t('travel_plans_status_confirmed')}</option>
                      <option value="completed">{t('travel_plans_status_completed')}</option>
                      <option value="cancelled">{t('travel_plans_status_cancelled')}</option>
                    </Select>

                    {transferForm.title_option === CUSTOM_TITLE_OPTION ? (
                      <Input
                        className="md:col-span-2"
                        value={transferForm.custom_title}
                        onChange={(event) =>
                          setTransferForm((prev) => ({ ...prev, custom_title: event.target.value }))
                        }
                        placeholder={t('travel_plans_custom_title_placeholder')}
                      />
                    ) : null}

                    <Input
                      type="date"
                      value={transferForm.transfer_date}
                      onChange={(event) =>
                        setTransferForm((prev) => ({ ...prev, transfer_date: event.target.value }))
                      }
                    />
                    <Input
                      type="time"
                      value={transferForm.transfer_time}
                      onChange={(event) =>
                        setTransferForm((prev) => ({ ...prev, transfer_time: event.target.value }))
                      }
                    />
                    <Input
                      value={transferForm.origin}
                      onChange={(event) =>
                        setTransferForm((prev) => ({ ...prev, origin: event.target.value }))
                      }
                      placeholder={t('travel_plans_origin_placeholder')}
                    />
                    <Input
                      value={transferForm.destination}
                      onChange={(event) =>
                        setTransferForm((prev) => ({ ...prev, destination: event.target.value }))
                      }
                      placeholder={t('travel_plans_destination_placeholder')}
                    />
                    <TextArea
                      className="md:col-span-2"
                      rows={3}
                      value={transferForm.observations}
                      onChange={(event) =>
                        setTransferForm((prev) => ({ ...prev, observations: event.target.value }))
                      }
                      placeholder={t('travel_plans_observations_placeholder')}
                    />
                  </div>

                  <div className="mt-3 flex justify-end">
                    <Button
                      type="button"
                      onClick={() => void handleSubmitTransfer()}
                      disabled={createTransferMutation.isPending || updateTransferMutation.isPending}
                    >
                      <Plus className="h-4 w-4" />
                      {editingTransferId ? t('travel_plans_save_changes') : t('travel_plans_add_transfer')}
                    </Button>
                  </div>
                </Card>

                <div className="space-y-3">
                  {transfers.length === 0 ? (
                    <Card>
                      <p className="text-sm text-slate-500">{t('travel_plans_no_transfers')}</p>
                    </Card>
                  ) : (
                    transfers.map((transfer) => {
                      const statusLabel = transferStatusLabel(transfer.status, t)
                      const statusClass = TRANSFER_STATUS_BADGE_CLASS[transfer.status]

                      return (
                        <Card
                          key={transfer.id}
                          className="cursor-move"
                          draggable
                          onDragStart={() => setDraggingTransferId(transfer.id)}
                          onDragOver={(event) => event.preventDefault()}
                          onDrop={() => handleDropTransfer(transfer.id)}
                        >
                          <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                            <div className="min-w-0 flex-1">
                              <div className="mb-2 flex items-center gap-2">
                                <GripVertical className="h-4 w-4 text-slate-400" />
                                <p className="text-sm font-semibold text-night">{transferPresetLabel(transfer.title, t)}</p>
                                <Badge className={statusClass}>{statusLabel}</Badge>
                                {transfer.confirmed_by_patient ? (
                                  <Badge className="bg-emerald-100 text-emerald-700">
                                    {t('travel_plans_seen_by_patient')}
                                  </Badge>
                                ) : null}
                              </div>
                              <p className="text-xs text-slate-500">
                                {formatDate(transfer.transfer_date)} {t('travel_plans_at')} {normalizeApiTime(transfer.transfer_time)}
                              </p>
                              <p className="mt-1 text-sm text-slate-700">
                                {transfer.origin} → {transfer.destination}
                              </p>
                              {transfer.observations ? (
                                <p className="mt-1 text-sm text-slate-500">{transfer.observations}</p>
                              ) : null}
                            </div>

                            <div className="flex items-center gap-2">
                              <Button
                                type="button"
                                size="sm"
                                variant="secondary"
                                onClick={() => handleEditTransfer(transfer)}
                              >
                                <Pencil className="h-4 w-4" />
                                {t('travel_plans_edit')}
                              </Button>
                              <Button
                                type="button"
                                size="sm"
                                variant="secondary"
                                onClick={() => void handleCycleTransferStatus(transfer)}
                              >
                                {t('travel_plans_change_status')}
                              </Button>
                              <Button
                                type="button"
                                size="sm"
                                variant="danger"
                                onClick={() => void handleDeleteTransfer(transfer.id)}
                              >
                                <Trash2 className="h-4 w-4" />
                                {t('travel_plans_delete')}
                              </Button>
                            </div>
                          </div>
                        </Card>
                      )
                    })
                  )}
                </div>
              </div>
            ) : null}
          </div>
        )}
      </Modal>
    </div>
  )
}
