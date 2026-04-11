import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { Copy, Eye, EyeOff } from 'lucide-react'
import { useEffect, useState } from 'react'
import toast from 'react-hot-toast'
import { useNavigate, useParams, useSearchParams } from 'react-router-dom'

import {
  getPatientById,
  updatePatient,
  type UpdatePatientPayload,
} from '@/api/patients'
import { getPatientPreOperatory } from '@/api/medicalRecords'
import { listTenantProcedures } from '@/api/settings'
import { PatientMedicalRecordModule } from '@/components/patients/PatientMedicalRecordModule'
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

type PatientStatus = 'active' | 'inactive' | 'lead'
type ReferralSource = 'google' | 'instagram' | 'indication' | 'other'

interface EditPatientForm {
  full_name: string
  cpf: string
  email: string
  phone: string
  date_of_birth: string
  specialty: string
  status: PatientStatus
  referral_source: ReferralSource
  notes: string
}

const emptyEditForm: EditPatientForm = {
  full_name: '',
  cpf: '',
  email: '',
  phone: '',
  date_of_birth: '',
  specialty: '',
  status: 'lead',
  referral_source: 'other',
  notes: '',
}

function normalizeStatus(value?: string | null): PatientStatus {
  if (value === 'active' || value === 'inactive' || value === 'lead') {
    return value
  }
  return 'lead'
}

function normalizeReferralSource(value?: string | null): ReferralSource {
  if (value === 'google' || value === 'instagram' || value === 'indication' || value === 'other') {
    return value
  }
  return 'other'
}

function getReferralLabel(
  source: string | undefined,
  t: (key: TranslationKey) => string,
): string {
  const normalized = normalizeReferralSource(source)
  if (normalized === 'google') return t('patient_detail_referral_google')
  if (normalized === 'instagram') return t('patient_detail_referral_instagram')
  if (normalized === 'indication') return t('patient_detail_referral_indication')
  return t('patient_detail_referral_other')
}

function formatApprovalDate(value?: string | null): string {
  if (!value) return 'Não informado'
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) return 'Não informado'
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(parsed)
}

export default function PatientDetailPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { id } = useParams()
  const [searchParams, setSearchParams] = useSearchParams()
  const language = usePreferencesStore((state) => state.language)
  const userRole = useAuthStore((state) => state.user?.role)
  const t = (key: TranslationKey) => translate(language, key)
  const canEditPatient = userRole === 'clinic_master'
  const isEditModalOpen = canEditPatient && searchParams.get('edit') === '1'
  const [editForm, setEditForm] = useState<EditPatientForm>(emptyEditForm)
  const [showTempPassword, setShowTempPassword] = useState(false)

  const patientId = id || ''

  const closeEditModal = () => {
    setShowTempPassword(false)
    if (searchParams.get('edit') === '1') {
      const next = new URLSearchParams(searchParams)
      next.delete('edit')
      setSearchParams(next, { replace: true })
    }
  }

  const openEditModal = () => {
    if (!canEditPatient) return
    const next = new URLSearchParams(searchParams)
    next.set('edit', '1')
    setSearchParams(next, { replace: true })
  }

  const handleCopyTempPassword = async (value: string) => {
    try {
      await navigator.clipboard.writeText(value)
      toast.success('Senha copiada')
    } catch {
      toast.error('Nao foi possivel copiar a senha')
    }
  }

  const {
    data: patient,
    isLoading,
    isError,
    refetch,
  } = useQuery({
    queryKey: ['patient-detail', patientId],
    queryFn: () => getPatientById(patientId),
    enabled: Boolean(patientId),
  })
  const { data: procedures = [] } = useQuery({
    queryKey: ['tenant-procedures-catalog'],
    queryFn: () => listTenantProcedures(),
  })
  const { data: preOperatoryRecord } = useQuery({
    queryKey: ['patient-detail-pre-operatory', patientId],
    queryFn: () => getPatientPreOperatory(patientId),
    enabled: Boolean(patientId),
  })

  useEffect(() => {
    if (!patient) return
    setEditForm({
      full_name: patient.full_name || '',
      cpf: patient.cpf || '',
      email: patient.email || '',
      phone: patient.phone || '',
      date_of_birth: patient.date_of_birth?.slice(0, 10) || '',
      specialty: patient.specialty || '',
      status: normalizeStatus(patient.status),
      referral_source: normalizeReferralSource(patient.referral_source),
      notes: patient.notes || '',
    })
  }, [patient])

  const updateMutation = useMutation({
    mutationFn: (payload: UpdatePatientPayload) => updatePatient(patientId, payload),
    onSuccess: (updatedPatient) => {
      toast.success(t('patient_detail_update_success'))
      queryClient.setQueryData(['patient-detail', patientId], updatedPatient)
      void queryClient.invalidateQueries({ queryKey: ['patients-list'] })
      closeEditModal()
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
      toast.error(t('patient_detail_update_error'))
    },
  })

  const handleSaveChanges = () => {
    if (!canEditPatient) return
    if (!patientId) return

    const payload: UpdatePatientPayload = {
      full_name: editForm.full_name,
      cpf: editForm.cpf,
      email: editForm.email,
      phone: editForm.phone,
      specialty: editForm.specialty || null,
      status: editForm.status,
      referral_source: editForm.referral_source,
      notes: editForm.notes,
    }

    if (editForm.date_of_birth) {
      payload.date_of_birth = editForm.date_of_birth
    }

    updateMutation.mutate(payload)
  }

  const fieldValue = (value?: string | null): string =>
    value && value.trim() ? value : t('patients_not_informed')

  if (!patientId) {
    return <p className="body-copy">{t('patient_detail_load_error')}</p>
  }

  if (isLoading) {
    return <p className="body-copy">{t('patient_detail_loading')}</p>
  }

  if (isError || !patient) {
    return (
      <div className="space-y-3">
        <p className="body-copy">{t('patient_detail_load_error')}</p>
        <div className="flex gap-2">
          <Button variant="secondary" onClick={() => navigate('/patients')}>
            {t('patients_previous')}
          </Button>
          <Button onClick={() => void refetch()}>{t('patient_detail_retry')}</Button>
        </div>
      </div>
    )
  }

  const tempPassword = patient.temp_password ?? null
  const displayedProcedureName =
    patient.pre_operatory_procedure_name?.trim() || patient.specialty_name?.trim() || ''
  const activeProcedures = procedures
    .filter((procedure) => procedure.is_active)
    .sort((left, right) => left.specialty_name.localeCompare(right.specialty_name))
  const selectedProcedureMissingFromCatalog =
    Boolean(editForm.specialty) &&
    !activeProcedures.some((procedure) => procedure.id === editForm.specialty)
  const approvedByDisplayName =
    preOperatoryRecord?.approved_by_name?.trim()
    || preOperatoryRecord?.current_doctor_name?.trim()
    || patient.assigned_doctor?.name?.trim()
    || ''
  const currentDoctorDisplayName =
    preOperatoryRecord?.current_doctor_name?.trim()
    || patient.assigned_doctor?.name?.trim()
    || ''

  return (
    <div className="space-y-5">
      <SectionHeader
        title={patient.full_name || t('patient_detail_title')}
        subtitle={t('patient_detail_subtitle')}
        actions={canEditPatient ? (
          <Button onClick={openEditModal}>
            {t('patient_detail_edit_record')}
          </Button>
        ) : null}
      />

      <div className="grid gap-4 xl:grid-cols-[280px_1fr]">
        <Card>
          <div className="text-center">
            <Avatar name={patient.full_name} src={patient.avatar_url || undefined} className="mx-auto h-20 w-20 text-base" />
            <p className="mt-3 text-base font-semibold text-night">{patient.full_name}</p>
            <Badge status={patient.status} className="mt-2" />
          </div>

          <div className="mt-6 space-y-3 text-sm">
            <p>
              <span className="overline block">{t('patient_detail_procedures')}</span>
              <span className="text-slate-700">{fieldValue(displayedProcedureName)}</span>
            </p>
            <p>
              <span className="overline block">{t('patient_detail_referral_source')}</span>
              <span className="text-slate-700">{getReferralLabel(patient.referral_source, t)}</span>
            </p>
            <p>
              <span className="overline block">{t('patient_detail_date_joined')}</span>
              <span className="text-slate-700">{formatDate(patient.date_joined)}</span>
            </p>
          </div>
        </Card>

        <div className="space-y-4">
          <Card>
            <h2 className="section-heading mb-3">{t('patient_detail_basic_info')}</h2>
            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <p className="overline">{t('patient_detail_full_name')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.full_name)}</p>
              </div>
              <div>
                <p className="overline">{t('patient_detail_tax_number')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.cpf)}</p>
              </div>
              <div>
                <p className="overline">{t('patient_detail_date_of_birth')}</p>
                <p className="text-sm text-slate-700">{formatDate(patient.date_of_birth)}</p>
              </div>
              <div>
                <p className="overline">{t('patient_detail_status')}</p>
                <Badge status={patient.status} />
              </div>
            </div>
          </Card>

          <Card>
            <h2 className="section-heading mb-3">{t('patient_detail_contact_info')}</h2>
            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <p className="overline">{t('patient_detail_email')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.email)}</p>
              </div>
              <div>
                <p className="overline">{t('patient_detail_phone')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.phone)}</p>
              </div>
              <div>
                <p className="overline">{t('patient_detail_health_insurance')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.health_insurance)}</p>
              </div>
            </div>
          </Card>

          <Card>
            <h2 className="section-heading mb-3">{t('patient_detail_clinical_info')}</h2>
            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <p className="overline">{t('patient_detail_blood_type')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.blood_type)}</p>
              </div>
              <div>
                <p className="overline">{t('patient_detail_allergies')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.allergies)}</p>
              </div>
              <div>
                <p className="overline">{t('patient_detail_previous_surgeries')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.previous_surgeries)}</p>
              </div>
              <div>
                <p className="overline">{t('patient_detail_current_medications')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.current_medications)}</p>
              </div>
              <div className="md:col-span-2">
                <p className="overline">{t('patient_detail_notes')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.notes)}</p>
              </div>
            </div>
          </Card>

          {preOperatoryRecord?.status === 'approved' ? (
            <Card>
              <h2 className="section-heading mb-3">Pré-operatório</h2>
              <div className="space-y-2 rounded-lg border border-emerald-200 bg-emerald-50 p-3 text-sm text-slate-700">
                <p>
                  <span className="font-semibold">Médico que aprovou:</span>{' '}
                  {approvedByDisplayName ? `Dr. ${approvedByDisplayName}` : 'Não informado'}
                </p>
                <p>
                  <span className="font-semibold">Data da aprovação:</span>{' '}
                  {formatApprovalDate(preOperatoryRecord.approved_at)}
                </p>
                {preOperatoryRecord.approved_by_different_doctor ? (
                  <p className="rounded-md border border-sky-200 bg-sky-50 px-3 py-2 text-xs text-sky-700">
                    Pré-operatório aprovado pelo Dr. {approvedByDisplayName || 'Não informado'}.
                    {' '}Médico atual: Dr. {currentDoctorDisplayName || 'Não informado'}.
                  </p>
                ) : null}
              </div>
            </Card>
          ) : null}

          <PatientMedicalRecordModule patientId={patientId} />

          <Card>
            <h2 className="section-heading mb-3">{t('patient_detail_emergency_contact')}</h2>
            <div className="grid gap-3 md:grid-cols-2">
              <div>
                <p className="overline">{t('patient_detail_emergency_name')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.emergency_contact_name)}</p>
              </div>
              <div>
                <p className="overline">{t('patient_detail_emergency_phone')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.emergency_contact_phone)}</p>
              </div>
              <div>
                <p className="overline">{t('patient_detail_emergency_relation')}</p>
                <p className="text-sm text-slate-700">{fieldValue(patient.emergency_contact_relation)}</p>
              </div>
              <div>
                <p className="overline">{t('patient_detail_responsible_doctor')}</p>
                <p className="text-sm text-slate-700">
                  {patient.assigned_doctor?.name || t('patient_detail_no_doctor')}
                </p>
              </div>
            </div>
          </Card>
        </div>
      </div>

      <Modal
        isOpen={isEditModalOpen}
        onClose={closeEditModal}
        title={t('patient_detail_edit_record')}
      >
        <div className="grid gap-3">
          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">{t('patient_detail_full_name')}</p>
            <Input
              value={editForm.full_name}
              onChange={(event) => setEditForm((prev) => ({ ...prev, full_name: event.target.value }))}
            />
          </div>

          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">{t('patient_detail_tax_number')}</p>
            <Input
              value={editForm.cpf}
              onChange={(event) => setEditForm((prev) => ({ ...prev, cpf: event.target.value }))}
            />
          </div>

          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">{t('patient_detail_email')}</p>
            <Input
              value={editForm.email}
              onChange={(event) => setEditForm((prev) => ({ ...prev, email: event.target.value }))}
            />
          </div>

          {tempPassword ? (
            <div>
              <p className="mb-1 text-xs font-semibold text-slate-600">
                Senha provisoria gerada automaticamente
              </p>
              <div className="flex items-center gap-2">
                <Input
                  type={showTempPassword ? 'text' : 'password'}
                  value={tempPassword}
                  readOnly
                />
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => setShowTempPassword((current) => !current)}
                  aria-label={showTempPassword ? 'Ocultar senha provisoria' : 'Mostrar senha provisoria'}
                >
                  {showTempPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => void handleCopyTempPassword(tempPassword)}
                >
                  <Copy className="h-4 w-4" />
                  Copiar
                </Button>
              </div>
              <p className="caption mt-2 text-slate-500">
                Este campo ficara visivel apenas ate o paciente alterar a propria senha no aplicativo.
              </p>
            </div>
          ) : null}

          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">{t('patient_detail_phone')}</p>
            <Input
              value={editForm.phone}
              onChange={(event) => setEditForm((prev) => ({ ...prev, phone: event.target.value }))}
            />
          </div>

          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">{t('patient_detail_date_of_birth')}</p>
            <Input
              type="date"
              value={editForm.date_of_birth}
              onChange={(event) =>
                setEditForm((prev) => ({ ...prev, date_of_birth: event.target.value }))
              }
            />
          </div>

          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">{t('patient_detail_procedures')}</p>
            <Select
              value={editForm.specialty}
              onChange={(event) =>
                setEditForm((prev) => ({ ...prev, specialty: event.target.value }))
              }
            >
              <option value="">{t('patient_detail_select_procedure')}</option>
              {selectedProcedureMissingFromCatalog ? (
                <option value={editForm.specialty}>
                  {patient.specialty_name || t('patients_not_informed')}
                </option>
              ) : null}
              {activeProcedures.map((procedure) => (
                <option key={procedure.id} value={procedure.id}>
                  {procedure.specialty_name}
                </option>
              ))}
            </Select>
          </div>

          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">{t('patient_detail_status')}</p>
            <Select
              value={editForm.status}
              onChange={(event) =>
                setEditForm((prev) => ({
                  ...prev,
                  status: normalizeStatus(event.target.value),
                }))
              }
            >
              <option value="active">{t('patients_status_active')}</option>
              <option value="inactive">{t('patients_status_inactive')}</option>
              <option value="lead">{t('patients_status_lead')}</option>
            </Select>
          </div>

          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">{t('patient_detail_referral_source')}</p>
            <Select
              value={editForm.referral_source}
              onChange={(event) =>
                setEditForm((prev) => ({
                  ...prev,
                  referral_source: normalizeReferralSource(event.target.value),
                }))
              }
            >
              <option value="google">{t('patient_detail_referral_google')}</option>
              <option value="instagram">{t('patient_detail_referral_instagram')}</option>
              <option value="indication">{t('patient_detail_referral_indication')}</option>
              <option value="other">{t('patient_detail_referral_other')}</option>
            </Select>
          </div>

          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">{t('patient_detail_notes')}</p>
            <TextArea
              rows={4}
              value={editForm.notes}
              onChange={(event) => setEditForm((prev) => ({ ...prev, notes: event.target.value }))}
            />
          </div>

          <div className="mt-2 flex justify-end gap-2">
            <Button variant="secondary" onClick={closeEditModal}>
              {t('patients_cancel')}
            </Button>
            <Button onClick={handleSaveChanges} disabled={updateMutation.isPending}>
              {updateMutation.isPending
                ? t('patient_detail_updating')
                : t('patient_detail_save_changes')}
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  )
}
