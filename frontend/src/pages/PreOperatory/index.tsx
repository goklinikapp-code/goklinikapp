import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { Eye, RefreshCw } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import toast from 'react-hot-toast'

import {
  listTenantPreOperatory,
  type PreOperatoryAdminUpdatePayload,
  type PreOperatoryStatus,
  updatePreOperatoryById,
} from '@/api/preOperatory'
import { getDoctors } from '@/api/patients'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { PreOperatoryModal } from '@/components/patients/PreOperatoryModal'
import { preOperatoryStatusLabel } from '@/components/patients/preOperatoryStatus'
import { Avatar } from '@/components/ui/Avatar'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Select } from '@/components/ui/Select'
import { TextArea } from '@/components/ui/TextArea'
import { formatDate } from '@/utils/format'

type StatusFilter = 'active' | PreOperatoryStatus

type ActionKind =
  | 'in_review'
  | 'approve'
  | 'reject'
  | 'assign'
  | 'approve_assign'

function statusBadgeClass(status: PreOperatoryStatus) {
  if (status === 'approved') return 'bg-success/15 text-success'
  if (status === 'rejected') return 'bg-danger/15 text-danger'
  if (status === 'in_review') return 'bg-amber-100 text-amber-700'
  return 'bg-slate-200 text-slate-600'
}

function extractApiErrorMessage(error: unknown, fallback: string) {
  if (!isAxiosError(error)) return fallback
  const responseData = error.response?.data as
    | {
        detail?: string
        non_field_errors?: string[]
        status?: string[]
        assigned_doctor?: string[]
      }
    | undefined

  if (responseData?.detail) return responseData.detail
  if (Array.isArray(responseData?.non_field_errors) && responseData.non_field_errors[0]) {
    return responseData.non_field_errors[0]
  }
  if (Array.isArray(responseData?.status) && responseData.status[0]) {
    return responseData.status[0]
  }
  if (Array.isArray(responseData?.assigned_doctor) && responseData.assigned_doctor[0]) {
    return responseData.assigned_doctor[0]
  }
  return fallback
}

export default function PreOperatoryPage() {
  const queryClient = useQueryClient()
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('active')
  const [selectedRecordId, setSelectedRecordId] = useState<string | null>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [notes, setNotes] = useState('')
  const [selectedDoctorId, setSelectedDoctorId] = useState('')
  const [pendingAction, setPendingAction] = useState<ActionKind | null>(null)

  const listQuery = useQuery({
    queryKey: ['pre-operatory-admin-list', statusFilter],
    queryFn: () =>
      listTenantPreOperatory(
        statusFilter === 'active' ? undefined : statusFilter,
      ),
    refetchInterval: 10000,
    refetchOnMount: 'always',
  })

  const doctorsQuery = useQuery({
    queryKey: ['pre-operatory-admin-doctors'],
    queryFn: getDoctors,
    enabled: isModalOpen,
  })

  const selectedRecord = useMemo(
    () =>
      (listQuery.data || []).find((item) => item.id === selectedRecordId) ||
      null,
    [listQuery.data, selectedRecordId],
  )

  useEffect(() => {
    if (!isModalOpen || !selectedRecord) return
    setNotes(selectedRecord.notes || '')
    setSelectedDoctorId(selectedRecord.assigned_doctor || '')
  }, [isModalOpen, selectedRecord?.id])

  const updateMutation = useMutation({
    mutationFn: ({
      preOperatoryId,
      payload,
    }: {
      preOperatoryId: string
      payload: PreOperatoryAdminUpdatePayload
    }) => updatePreOperatoryById(preOperatoryId, payload),
  })

  const closeModal = () => {
    setIsModalOpen(false)
    setSelectedRecordId(null)
    setNotes('')
    setSelectedDoctorId('')
    setPendingAction(null)
  }

  const executeAction = async (
    action: ActionKind,
    payload: PreOperatoryAdminUpdatePayload,
  ) => {
    if (!selectedRecord) return

    setPendingAction(action)
    try {
      await updateMutation.mutateAsync({
        preOperatoryId: selectedRecord.id,
        payload,
      })
      await queryClient.invalidateQueries({
        queryKey: ['pre-operatory-admin-list'],
      })
      toast.success('Pré-operatório atualizado com sucesso.')
      closeModal()
    } catch (error) {
      toast.error(
        extractApiErrorMessage(
          error,
          'Não foi possível atualizar o pré-operatório.',
        ),
      )
    } finally {
      setPendingAction(null)
    }
  }

  const requireDoctor = () => {
    if (selectedDoctorId) return true
    toast.error('Selecione um médico para esta ação.')
    return false
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title="Pré-operatório"
        subtitle="Analise os formulários enviados pelos pacientes e decida o próximo passo clínico."
        actions={
          <Button
            type="button"
            variant="secondary"
            onClick={() => void listQuery.refetch()}
            disabled={listQuery.isLoading || listQuery.isFetching}
          >
            <RefreshCw
              className={`h-4 w-4 ${
                listQuery.isLoading || listQuery.isFetching ? 'animate-spin' : ''
              }`}
            />
            Atualizar
          </Button>
        }
      />

      <Card>
        <div className="grid gap-3 md:grid-cols-[220px_1fr]">
          <Select
            value={statusFilter}
            onChange={(event) => setStatusFilter(event.target.value as StatusFilter)}
          >
            <option value="active">Pendentes e em análise</option>
            <option value="pending">Pendente</option>
            <option value="in_review">Em análise</option>
            <option value="approved">Aprovado</option>
            <option value="rejected">Reprovado</option>
          </Select>
          <div className="flex items-center text-sm text-slate-500">
            {(listQuery.data || []).length} pré-operatório(s) encontrado(s)
          </div>
        </div>
      </Card>

      <Card padded={false} className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">PACIENTE</th>
                <th className="px-4 py-3 text-left overline">STATUS</th>
                <th className="px-4 py-3 text-left overline">DATA DE ENVIO</th>
                <th className="px-4 py-3 text-right overline">AÇÃO</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {listQuery.isLoading ? (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-sm text-slate-500">
                    Carregando pré-operatórios...
                  </td>
                </tr>
              ) : listQuery.isError ? (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-sm text-slate-500">
                    Não foi possível carregar os pré-operatórios.
                  </td>
                </tr>
              ) : (listQuery.data || []).length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-sm text-slate-500">
                    Nenhum pré-operatório encontrado com os filtros atuais.
                  </td>
                </tr>
              ) : (
                (listQuery.data || []).map((item) => (
                  <tr key={item.id} className="hover:bg-tealIce/50">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <Avatar
                          name={item.patient_name || 'Paciente'}
                          src={item.patient_avatar_url || undefined}
                          className="h-8 w-8"
                        />
                        <span className="text-sm font-semibold text-night">
                          {item.patient_name || 'Paciente'}
                        </span>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <Badge className={statusBadgeClass(item.status)}>
                        {preOperatoryStatusLabel(item.status)}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-600">
                      {formatDate(item.created_at)}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Button
                        type="button"
                        size="sm"
                        variant="secondary"
                        onClick={() => {
                          setSelectedRecordId(item.id)
                          setIsModalOpen(true)
                        }}
                      >
                        <Eye className="h-4 w-4" />
                        Ver
                      </Button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </Card>

      <PreOperatoryModal
        isOpen={isModalOpen}
        onClose={closeModal}
        record={selectedRecord}
        isLoading={Boolean(isModalOpen && listQuery.isLoading && !selectedRecord)}
        isError={Boolean(isModalOpen && listQuery.isError)}
        title={
          selectedRecord?.patient_name
            ? `Pré-operatório • ${selectedRecord.patient_name}`
            : 'Pré-operatório'
        }
        actionArea={
          <div className="space-y-4">
            <div>
              <p className="mb-2 text-sm font-semibold text-night">Observações da clínica</p>
              <TextArea
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
                placeholder="Adicione observações para o prontuário clínico"
                rows={4}
              />
            </div>

            <div>
              <p className="mb-2 text-sm font-semibold text-night">Atribuir médico</p>
              <Select
                value={selectedDoctorId}
                onChange={(event) => setSelectedDoctorId(event.target.value)}
                disabled={doctorsQuery.isLoading}
              >
                <option value="">Selecione um médico</option>
                {(doctorsQuery.data || []).map((doctor) => (
                  <option key={doctor.id} value={doctor.id}>
                    {doctor.name}
                  </option>
                ))}
              </Select>
            </div>

            <div className="grid gap-2 md:grid-cols-2">
              <Button
                type="button"
                variant="secondary"
                disabled={Boolean(pendingAction)}
                onClick={() =>
                  void executeAction('in_review', {
                    status: 'in_review',
                    notes,
                  })
                }
              >
                {pendingAction === 'in_review' ? 'Salvando...' : 'Marcar como em análise'}
              </Button>

              <Button
                type="button"
                disabled={Boolean(pendingAction)}
                onClick={() =>
                  void executeAction('approve', {
                    status: 'approved',
                    notes,
                  })
                }
              >
                {pendingAction === 'approve' ? 'Salvando...' : 'Aprovar'}
              </Button>

              <Button
                type="button"
                variant="danger"
                disabled={Boolean(pendingAction)}
                onClick={() =>
                  void executeAction('reject', {
                    status: 'rejected',
                    notes,
                  })
                }
              >
                {pendingAction === 'reject' ? 'Salvando...' : 'Reprovar'}
              </Button>

              <Button
                type="button"
                variant="secondary"
                disabled={Boolean(pendingAction)}
                onClick={() => {
                  if (!requireDoctor()) return
                  void executeAction('assign', {
                    notes,
                    assigned_doctor: selectedDoctorId,
                  })
                }}
              >
                {pendingAction === 'assign' ? 'Salvando...' : 'Atribuir médico'}
              </Button>

              <Button
                type="button"
                className="md:col-span-2"
                disabled={Boolean(pendingAction)}
                onClick={() => {
                  if (!requireDoctor()) return
                  void executeAction('approve_assign', {
                    status: 'approved',
                    notes,
                    assigned_doctor: selectedDoctorId,
                  })
                }}
              >
                {pendingAction === 'approve_assign'
                  ? 'Salvando...'
                  : 'Aprovar e atribuir'}
              </Button>
            </div>
          </div>
        }
      />
    </div>
  )
}
