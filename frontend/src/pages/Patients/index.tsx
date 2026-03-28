import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { Mail, Phone, Plus, SlidersHorizontal, Stethoscope } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { useNavigate } from 'react-router-dom'
import { z } from 'zod'

import { assignDoctorToPatient, createPatient, getDoctors, getPatients } from '@/api/patients'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Modal } from '@/components/ui/Modal'
import { Select } from '@/components/ui/Select'
import { TextArea } from '@/components/ui/TextArea'
import { t as translate, type TranslationKey } from '@/i18n/system'
import { useAuthStore } from '@/stores/authStore'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { formatDate } from '@/utils/format'

const patientSchema = z.object({
  full_name: z.string().min(3, 'Informe o nome completo'),
  cpf: z.string().min(11, 'Número Fiscal inválido'),
  email: z.string().email('E-mail inválido'),
  phone: z.string().min(8, 'Telefone inválido'),
  date_of_birth: z.string().min(1, 'Informe a data de nascimento'),
  password: z.string().min(8, 'Senha temporária mínima de 8 caracteres'),
  specialty_name: z.string().optional(),
  referral_source: z.enum(['google', 'instagram', 'indication', 'other']),
})

type PatientForm = z.infer<typeof patientSchema>

export default function PatientsPage() {
  const navigate = useNavigate()
  const language = usePreferencesStore((state) => state.language)
  const t = (key: TranslationKey) => translate(language, key)
  const userRole = useAuthStore((state) => state.user?.role)
  const canAssignDoctor = userRole === 'clinic_master' || userRole === 'secretary'
  const [statusFilter, setStatusFilter] = useState('all')
  const [specialtyFilter, setSpecialtyFilter] = useState('all')
  const [dateFilter, setDateFilter] = useState('')
  const [page, setPage] = useState(1)
  const [itemsPerPage, setItemsPerPage] = useState(25)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [isAssignModalOpen, setIsAssignModalOpen] = useState(false)
  const [selectedDoctorId, setSelectedDoctorId] = useState('')
  const [assignmentNotes, setAssignmentNotes] = useState('')

  const queryClient = useQueryClient()
  const { data: patients = [], isLoading } = useQuery({
    queryKey: ['patients-list'],
    queryFn: getPatients,
    refetchInterval: 10000,
    refetchOnMount: 'always',
  })

  const selectedPatient = useMemo(
    () => patients.find((patient) => patient.id === selectedId) || null,
    [patients, selectedId],
  )

  const { data: doctors = [], isLoading: doctorsLoading } = useQuery({
    queryKey: ['patients-doctors'],
    queryFn: getDoctors,
    enabled: isAssignModalOpen && canAssignDoctor,
  })

  const specialties = useMemo(() => {
    const set = new Set<string>()
    patients.forEach((patient) => {
      if (patient.specialty_name) {
        set.add(patient.specialty_name)
      }
    })
    return Array.from(set)
  }, [patients])

  const filteredPatients = useMemo(() => {
    return patients.filter((patient) => {
      const statusMatch = statusFilter === 'all' ? true : patient.status === statusFilter
      const specialtyMatch =
        specialtyFilter === 'all' ? true : patient.specialty_name?.toLowerCase() === specialtyFilter.toLowerCase()
      const dateMatch = dateFilter ? patient.date_joined === dateFilter : true

      return statusMatch && specialtyMatch && dateMatch
    })
  }, [patients, statusFilter, specialtyFilter, dateFilter])

  const totalPages = Math.max(1, Math.ceil(filteredPatients.length / itemsPerPage))
  const paginatedPatients = filteredPatients.slice((page - 1) * itemsPerPage, page * itemsPerPage)

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<PatientForm>({
    resolver: zodResolver(patientSchema),
    defaultValues: {
      referral_source: 'google',
      specialty_name: '',
    },
  })

  const createMutation = useMutation({
    mutationFn: createPatient,
    onSuccess: () => {
      toast.success(t('patients_create_success'))
      setIsModalOpen(false)
      reset()
      void queryClient.invalidateQueries({ queryKey: ['patients-list'] })
    },
    onError: (error) => {
      if (isAxiosError(error)) {
        const responseData = error.response?.data as Record<string, unknown> | undefined
        if (responseData) {
          const firstValue = Object.values(responseData)[0]
          if (Array.isArray(firstValue) && firstValue[0]) {
            toast.error(String(firstValue[0]))
            return
          }
          if (typeof firstValue === 'string') {
            toast.error(firstValue)
            return
          }
        }
      }
      toast.error(t('patients_create_error'))
    },
  })

  const assignDoctorMutation = useMutation({
    mutationFn: async (payload: { patientId: string; doctorId: string; notes: string }) =>
      assignDoctorToPatient(payload.patientId, payload.doctorId, payload.notes),
    onSuccess: async () => {
      toast.success(t('patients_assign_success'))
      setIsAssignModalOpen(false)
      setSelectedDoctorId('')
      setAssignmentNotes('')
      await queryClient.invalidateQueries({ queryKey: ['patients-list'] })
    },
    onError: (error) => {
      if (isAxiosError(error)) {
        const responseData = error.response?.data as Record<string, unknown> | undefined
        if (responseData) {
          const firstValue = Object.values(responseData)[0]
          if (Array.isArray(firstValue) && firstValue[0]) {
            toast.error(String(firstValue[0]))
            return
          }
          if (typeof firstValue === 'string') {
            toast.error(firstValue)
            return
          }
        }
      }
      toast.error(t('patients_assign_error'))
    },
  })

  const onSubmit = (values: PatientForm) => {
    createMutation.mutate(values)
  }

  const openAssignDoctorModal = () => {
    if (!canAssignDoctor) {
      toast.error(t('patients_assign_permission_hint'))
      return
    }
    if (!selectedPatient) {
      toast.error(t('patients_select_patient_first'))
      return
    }
    setSelectedDoctorId(selectedPatient.assigned_doctor?.id || '')
    setAssignmentNotes(selectedPatient.assigned_doctor?.notes || '')
    setIsAssignModalOpen(true)
  }

  const handleAssignDoctor = () => {
    if (!selectedPatient) {
      toast.error(t('patients_select_patient_first'))
      return
    }
    if (!selectedDoctorId) {
      toast.error(t('patients_select_doctor_first'))
      return
    }
    assignDoctorMutation.mutate({
      patientId: selectedPatient.id,
      doctorId: selectedDoctorId,
      notes: assignmentNotes,
    })
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title={t('patients_title')}
        subtitle={t('patients_subtitle')}
        actions={
          <Button onClick={() => setIsModalOpen(true)}>
            <Plus className="h-4 w-4" />
            {t('patients_new_patient')}
          </Button>
        }
      />

      <Card>
        <div className="grid gap-3 md:grid-cols-4">
          <Select value={specialtyFilter} onChange={(event) => setSpecialtyFilter(event.target.value)}>
            <option value="all">{t('patients_all_specialties')}</option>
            {specialties.map((specialty) => (
              <option key={specialty} value={specialty}>
                {specialty}
              </option>
            ))}
          </Select>

          <Select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}>
            <option value="all">{t('patients_all_status')}</option>
            <option value="active">{t('patients_status_active')}</option>
            <option value="inactive">{t('patients_status_inactive')}</option>
            <option value="lead">{t('patients_status_lead')}</option>
          </Select>

          <Input type="date" value={dateFilter} onChange={(event) => setDateFilter(event.target.value)} />

          <Button variant="secondary">
            <SlidersHorizontal className="h-4 w-4" />
            {t('patients_more_filters')}
          </Button>
        </div>
      </Card>

      <div className="grid gap-4 xl:grid-cols-[1fr_240px]">
        <Card padded={false} className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-100">
              <thead className="bg-slate-50">
                <tr>
                  <th className="px-4 py-3 text-left overline">{t('patients_col_patient')}</th>
                  <th className="px-4 py-3 text-left overline">{t('patients_col_contact')}</th>
                  <th className="px-4 py-3 text-left overline">{t('patients_col_last_visit')}</th>
                  <th className="px-4 py-3 text-left overline">{t('patients_col_specialty')}</th>
                  <th className="px-4 py-3 text-left overline">{t('patients_col_status')}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 bg-white">
                {isLoading ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-10 text-center text-sm text-slate-500">
                      {t('patients_loading')}
                    </td>
                  </tr>
                ) : paginatedPatients.length ? (
                  paginatedPatients.map((patient) => (
                    <tr
                      key={patient.id}
                      onClick={() => setSelectedId(patient.id)}
                      className="cursor-pointer transition hover:bg-tealIce"
                    >
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          <Avatar
                            name={patient.full_name}
                            src={patient.avatar_url || undefined}
                            className="h-9 w-9"
                          />
                          <div>
                            <p className="text-sm font-semibold text-night">{patient.full_name}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-sm text-slate-600">
                        <p>{patient.phone}</p>
                        <p className="caption">{patient.email}</p>
                      </td>
                      <td className="px-4 py-3 text-sm text-slate-600">
                        <p>{formatDate(patient.last_visit)}</p>
                        <p className="caption">{t('patients_recorded_visit')}</p>
                      </td>
                      <td className="px-4 py-3">
                        <Badge className="bg-primary/10 text-primary">
                          {patient.specialty_name || t('patients_not_informed')}
                        </Badge>
                      </td>
                      <td className="px-4 py-3">
                        <Badge status={patient.status} />
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={5} className="px-4 py-10 text-center text-sm text-slate-500">
                      {t('patients_empty_filters')}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          <div className="flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 px-4 py-3">
            <div className="flex items-center gap-2 text-sm text-slate-600">
              <span>{t('patients_items_per_page')}</span>
              <Select
                className="h-8 w-20"
                value={itemsPerPage}
                onChange={(event) => {
                  setItemsPerPage(Number(event.target.value))
                  setPage(1)
                }}
              >
                <option value={25}>25</option>
                <option value={50}>50</option>
              </Select>
            </div>

            <div className="flex items-center gap-2">
              <Button
                size="sm"
                variant="secondary"
                disabled={page === 1}
                onClick={() => setPage((prev) => Math.max(1, prev - 1))}
              >
                {t('patients_previous')}
              </Button>
              <span className="text-sm text-slate-600">
                {page} / {totalPages}
              </span>
              <Button
                size="sm"
                variant="secondary"
                disabled={page === totalPages}
                onClick={() => setPage((prev) => Math.min(totalPages, prev + 1))}
              >
                {t('patients_next')}
              </Button>
            </div>
          </div>
        </Card>

        <Card className="min-h-[500px]">
          {selectedPatient ? (
            <div className="space-y-4">
              <div className="text-center">
                <Avatar
                  name={selectedPatient.full_name}
                  src={selectedPatient.avatar_url || undefined}
                  className="mx-auto h-16 w-16 text-sm"
                />
                <p className="mt-2 text-sm font-semibold text-night">{selectedPatient.full_name}</p>
                <Badge status={selectedPatient.status} className="mt-2" />
              </div>

              <div>
                <p className="overline mb-2">{t('patients_contact_information')}</p>
                <div className="space-y-2 text-sm text-slate-600">
                  <p className="inline-flex items-center gap-2"><Phone className="h-4 w-4" /> {selectedPatient.phone}</p>
                  <p className="inline-flex items-center gap-2"><Mail className="h-4 w-4" /> {selectedPatient.email}</p>
                </div>
              </div>

              <div>
                <p className="overline mb-2">{t('patients_clinical_history')}</p>
                <p className="text-sm text-slate-600">
                  {t('patients_last_procedure')}: {selectedPatient.specialty_name || t('patients_not_informed')}
                </p>
              </div>

              <div>
                <p className="overline mb-2">{t('patients_responsible_doctor')}</p>
                {selectedPatient.assigned_doctor ? (
                  <div className="rounded-lg border border-slate-200 bg-slate-50 p-3">
                    <p className="text-sm font-semibold text-night">{selectedPatient.assigned_doctor.name}</p>
                    <p className="caption">{selectedPatient.assigned_doctor.specialty || t('role_surgeon')}</p>
                  </div>
                ) : (
                  <p className="text-sm text-slate-600">{t('patients_no_assigned_doctor')}</p>
                )}
                <Button className="mt-2" fullWidth variant="secondary" onClick={openAssignDoctorModal}>
                  <Stethoscope className="h-4 w-4" />
                  {t('patients_assign_to_doctor')}
                </Button>
                {!canAssignDoctor ? (
                  <p className="caption mt-2">{t('patients_assign_permission_hint')}</p>
                ) : null}
              </div>

              <div className="space-y-2 pt-2">
                <Button fullWidth onClick={() => navigate(`/patients/${selectedPatient.id}`)}>
                  {t('patients_view_full_profile')}
                </Button>
                <Button
                  fullWidth
                  variant="secondary"
                  onClick={() => navigate(`/patients/${selectedPatient.id}?edit=1`)}
                >
                  {t('patients_edit')}
                </Button>
                <Button fullWidth variant="accent" onClick={() => navigate('/reports')}>
                  {t('patients_billing')}
                </Button>
              </div>
            </div>
          ) : (
            <p className="text-sm text-slate-500">{t('patients_select_patient_summary')}</p>
          )}
        </Card>
      </div>

      <Modal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title={t('patients_modal_new_patient')}>
        <form className="grid gap-3" onSubmit={handleSubmit(onSubmit)}>
          <Input placeholder="Nome Completo" {...register('full_name')} />
          {errors.full_name ? <p className="caption text-danger">{errors.full_name.message}</p> : null}

          <Input placeholder="Número Fiscal" {...register('cpf')} />
          {errors.cpf ? <p className="caption text-danger">{errors.cpf.message}</p> : null}

          <Input placeholder="Email" {...register('email')} />
          {errors.email ? <p className="caption text-danger">{errors.email.message}</p> : null}

          <Input placeholder="Telefone" {...register('phone')} />
          {errors.phone ? <p className="caption text-danger">{errors.phone.message}</p> : null}

          <Input type="date" {...register('date_of_birth')} />
          {errors.date_of_birth ? <p className="caption text-danger">{errors.date_of_birth.message}</p> : null}

          <Input placeholder="Senha temporária" {...register('password')} />
          {errors.password ? <p className="caption text-danger">{errors.password.message}</p> : null}

          <Input placeholder="Especialidade de interesse" {...register('specialty_name')} />
          {errors.specialty_name ? <p className="caption text-danger">{errors.specialty_name.message}</p> : null}

          <Select {...register('referral_source')}>
            <option value="google">Google</option>
            <option value="instagram">Instagram</option>
            <option value="indication">Indicação</option>
            <option value="other">Outro</option>
          </Select>
          {errors.referral_source ? <p className="caption text-danger">{errors.referral_source.message}</p> : null}

          <div className="mt-2 flex justify-end gap-2">
            <Button type="button" variant="secondary" onClick={() => setIsModalOpen(false)}>
              {t('patients_cancel')}
            </Button>
            <Button type="submit" disabled={createMutation.isPending}>
              {createMutation.isPending ? t('patients_saving') : t('patients_save_patient')}
            </Button>
          </div>
        </form>
      </Modal>

      <Modal
        isOpen={isAssignModalOpen}
        onClose={() => setIsAssignModalOpen(false)}
        title={t('patients_assign_modal_title')}
      >
        <div className="space-y-3">
          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">{t('patients_modal_patient')}</p>
            <Input value={selectedPatient?.full_name || ''} readOnly />
          </div>

          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">{t('patients_select_doctor')}</p>
            <Select
              value={selectedDoctorId}
              onChange={(event) => setSelectedDoctorId(event.target.value)}
              disabled={doctorsLoading}
            >
              <option value="">{t('patients_select_doctor_placeholder')}</option>
              {doctors.map((doctor) => (
                <option key={doctor.id} value={doctor.id}>
                  {doctor.name} - {doctor.specialty}
                </option>
              ))}
            </Select>
          </div>

          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">{t('patients_notes')}</p>
            <TextArea
              rows={4}
              placeholder={t('patients_notes_placeholder')}
              value={assignmentNotes}
              onChange={(event) => setAssignmentNotes(event.target.value)}
            />
          </div>

          <div className="flex justify-end gap-2">
            <Button variant="secondary" onClick={() => setIsAssignModalOpen(false)}>
              {t('patients_cancel')}
            </Button>
            <Button onClick={handleAssignDoctor} disabled={assignDoctorMutation.isPending}>
              {assignDoctorMutation.isPending
                ? t('patients_assign_confirming')
                : t('patients_assign_confirm')}
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  )
}
