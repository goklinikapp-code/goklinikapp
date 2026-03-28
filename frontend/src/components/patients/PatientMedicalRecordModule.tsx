import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { FileText, History, Pill, Plus, Save, Trash2 } from 'lucide-react'
import { useMemo, useState, type FormEvent } from 'react'
import toast from 'react-hot-toast'

import {
  createPatientDocument,
  createPatientMedication,
  createPatientProcedure,
  deactivatePatientMedication,
  deletePatientDocument,
  deletePatientProcedure,
  deletePatientProcedureImage,
  listPatientDocuments,
  listPatientMedications,
  listPatientProcedures,
  updatePatientDocument,
  updatePatientMedication,
  updatePatientProcedure,
  type PatientDocumentPayload,
  type PatientMedicationPayload,
  type PatientProcedurePayload,
} from '@/api/medicalRecords'
import { listTenantProcedures } from '@/api/settings'
import { getTeamMembers } from '@/api/team'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Modal } from '@/components/ui/Modal'
import { Select } from '@/components/ui/Select'
import { TextArea } from '@/components/ui/TextArea'
import type {
  PatientDocumentRecord,
  PatientMedicationRecord,
  PatientProcedureRecord,
  TeamMember,
} from '@/types'
import { formatDate } from '@/utils/format'

interface PatientMedicalRecordModuleProps {
  patientId: string
}

type OpenSection = 'medications' | 'procedures' | 'documents' | null

interface MedicationFormState {
  id?: string
  nome_medicamento: string
  dosagem: string
  frequencia: string
  via_administracao: string
  data_inicio: string
  data_fim: string
  em_uso: boolean
  possui_alergia: boolean
  descricao: string
}

interface ProcedureFormState {
  id?: string
  nome_procedimento: string
  descricao: string
  data_procedimento: string
  profissional_responsavel: string
  observacoes: string
}

interface DocumentFormState {
  id?: string
  titulo: string
  descricao: string
  tipo_arquivo: 'pdf' | 'imagem'
}

const today = new Date().toISOString().slice(0, 10)

const emptyMedication: MedicationFormState = {
  nome_medicamento: '',
  dosagem: '',
  frequencia: '',
  via_administracao: '',
  data_inicio: today,
  data_fim: '',
  em_uso: true,
  possui_alergia: false,
  descricao: '',
}

const emptyProcedure: ProcedureFormState = {
  nome_procedimento: '',
  descricao: '',
  data_procedimento: today,
  profissional_responsavel: '',
  observacoes: '',
}

const emptyDocument: DocumentFormState = {
  titulo: '',
  descricao: '',
  tipo_arquivo: 'pdf',
}

function extractApiErrorMessage(error: unknown, fallback: string) {
  if (isAxiosError(error)) {
    const responseData = error.response?.data as
      | {
          detail?: string
          non_field_errors?: string[]
          images?: string[]
        }
      | undefined
    if (Array.isArray(responseData?.non_field_errors) && responseData.non_field_errors[0]) {
      return responseData.non_field_errors[0]
    }
    if (Array.isArray(responseData?.images) && responseData.images[0]) {
      return responseData.images[0]
    }
    if (responseData?.detail) {
      return responseData.detail
    }
  }
  return fallback
}

function normalizeMedicationPayload(form: MedicationFormState): PatientMedicationPayload {
  return {
    nome_medicamento: form.nome_medicamento.trim(),
    dosagem: form.dosagem.trim(),
    frequencia: form.frequencia.trim(),
    via_administracao: form.via_administracao.trim(),
    data_inicio: form.data_inicio,
    data_fim: form.data_fim || undefined,
    em_uso: form.em_uso,
    possui_alergia: form.possui_alergia,
    descricao: form.descricao.trim(),
  }
}

function normalizeProcedurePayload(form: ProcedureFormState, images: File[]): PatientProcedurePayload {
  return {
    nome_procedimento: form.nome_procedimento.trim(),
    descricao: form.descricao.trim(),
    data_procedimento: form.data_procedimento,
    profissional_responsavel: form.profissional_responsavel.trim(),
    observacoes: form.observacoes.trim(),
    images,
  }
}

function normalizeDocumentPayload(form: DocumentFormState, file: File | null): PatientDocumentPayload {
  return {
    titulo: form.titulo.trim(),
    descricao: form.descricao.trim(),
    tipo_arquivo: form.tipo_arquivo,
    file: file || undefined,
  }
}

export function PatientMedicalRecordModule({ patientId }: PatientMedicalRecordModuleProps) {
  const queryClient = useQueryClient()
  const [openSection, setOpenSection] = useState<OpenSection>(null)

  const [medicationForm, setMedicationForm] = useState<MedicationFormState>(emptyMedication)
  const [procedureForm, setProcedureForm] = useState<ProcedureFormState>(emptyProcedure)
  const [documentForm, setDocumentForm] = useState<DocumentFormState>(emptyDocument)
  const [procedureFiles, setProcedureFiles] = useState<File[]>([])
  const [documentFile, setDocumentFile] = useState<File | null>(null)
  const [removingProcedureImageId, setRemovingProcedureImageId] = useState<string | null>(null)

  const medicationsQuery = useQuery({
    queryKey: ['patient-prontuario-medications', patientId],
    queryFn: () => listPatientMedications(patientId),
    enabled: Boolean(patientId),
    refetchInterval: 10000,
  })

  const proceduresQuery = useQuery({
    queryKey: ['patient-prontuario-procedures', patientId],
    queryFn: () => listPatientProcedures(patientId),
    enabled: Boolean(patientId),
    refetchInterval: 10000,
  })

  const documentsQuery = useQuery({
    queryKey: ['patient-prontuario-documents', patientId],
    queryFn: () => listPatientDocuments(patientId),
    enabled: Boolean(patientId),
    refetchInterval: 10000,
  })

  const proceduresCatalogQuery = useQuery({
    queryKey: ['tenant-procedures-catalog'],
    queryFn: () => listTenantProcedures(),
    refetchInterval: 30000,
  })

  const professionalsQuery = useQuery({
    queryKey: ['team-professionals-prontuario'],
    queryFn: () => getTeamMembers(),
    refetchInterval: 30000,
  })

  const invalidateAll = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ['patient-prontuario-medications', patientId] }),
      queryClient.invalidateQueries({ queryKey: ['patient-prontuario-procedures', patientId] }),
      queryClient.invalidateQueries({ queryKey: ['patient-prontuario-documents', patientId] }),
    ])
  }

  const createMedicationMutation = useMutation({
    mutationFn: (payload: PatientMedicationPayload) => createPatientMedication(patientId, payload),
    onSuccess: async () => {
      toast.success('Medicamento adicionado.')
      setMedicationForm(emptyMedication)
      await invalidateAll()
    },
    onError: () => toast.error('Não foi possível salvar o medicamento.'),
  })

  const updateMedicationMutation = useMutation({
    mutationFn: (params: { id: string; payload: Partial<PatientMedicationPayload> }) =>
      updatePatientMedication(patientId, params.id, params.payload),
    onSuccess: async () => {
      toast.success('Medicamento atualizado.')
      setMedicationForm(emptyMedication)
      await invalidateAll()
    },
    onError: () => toast.error('Não foi possível atualizar o medicamento.'),
  })

  const deactivateMedicationMutation = useMutation({
    mutationFn: (id: string) => deactivatePatientMedication(patientId, id),
    onSuccess: async () => {
      toast.success('Medicamento desativado.')
      await invalidateAll()
    },
    onError: () => toast.error('Não foi possível desativar o medicamento.'),
  })

  const createProcedureMutation = useMutation({
    mutationFn: (payload: PatientProcedurePayload) => createPatientProcedure(patientId, payload),
    onSuccess: async () => {
      toast.success('Procedimento adicionado.')
      setProcedureForm(emptyProcedure)
      setProcedureFiles([])
      await invalidateAll()
    },
    onError: (error) => toast.error(extractApiErrorMessage(error, 'Não foi possível salvar o procedimento.')),
  })

  const updateProcedureMutation = useMutation({
    mutationFn: (params: { id: string; payload: Partial<PatientProcedurePayload> }) =>
      updatePatientProcedure(patientId, params.id, params.payload),
    onSuccess: async () => {
      toast.success('Procedimento atualizado.')
      setProcedureForm(emptyProcedure)
      setProcedureFiles([])
      await invalidateAll()
    },
    onError: (error) => toast.error(extractApiErrorMessage(error, 'Não foi possível atualizar o procedimento.')),
  })

  const deleteProcedureMutation = useMutation({
    mutationFn: (id: string) => deletePatientProcedure(patientId, id),
    onSuccess: async () => {
      toast.success('Procedimento removido.')
      await invalidateAll()
    },
    onError: () => toast.error('Não foi possível remover o procedimento.'),
  })

  const deleteProcedureImageMutation = useMutation({
    mutationFn: (params: { procedureId: string; imageId: string }) =>
      deletePatientProcedureImage(patientId, params.procedureId, params.imageId),
    onMutate: ({ imageId }) => {
      setRemovingProcedureImageId(imageId)
    },
    onSuccess: async () => {
      toast.success('Imagem removida.')
      await invalidateAll()
    },
    onError: () => toast.error('Não foi possível remover a imagem.'),
    onSettled: () => {
      setRemovingProcedureImageId(null)
    },
  })

  const createDocumentMutation = useMutation({
    mutationFn: (payload: PatientDocumentPayload) => createPatientDocument(patientId, payload),
    onSuccess: async () => {
      toast.success('Documento adicionado.')
      setDocumentForm(emptyDocument)
      setDocumentFile(null)
      await invalidateAll()
    },
    onError: () => toast.error('Não foi possível salvar o documento.'),
  })

  const updateDocumentMutation = useMutation({
    mutationFn: (params: { id: string; payload: Partial<PatientDocumentPayload> }) =>
      updatePatientDocument(patientId, params.id, params.payload),
    onSuccess: async () => {
      toast.success('Documento atualizado.')
      setDocumentForm(emptyDocument)
      setDocumentFile(null)
      await invalidateAll()
    },
    onError: () => toast.error('Não foi possível atualizar o documento.'),
  })

  const deleteDocumentMutation = useMutation({
    mutationFn: (id: string) => deletePatientDocument(patientId, id),
    onSuccess: async () => {
      toast.success('Documento removido.')
      await invalidateAll()
    },
    onError: () => toast.error('Não foi possível remover o documento.'),
  })

  const activeMedicationsCount = useMemo(
    () => (medicationsQuery.data || []).filter((item) => item.em_uso).length,
    [medicationsQuery.data],
  )

  const procedureOptions = useMemo(() => {
    const catalog = proceduresCatalogQuery.data || []
    const activeCatalog = catalog.filter((item) => item.is_active)
    const currentName = procedureForm.nome_procedimento.trim()
    if (!currentName) {
      return activeCatalog
    }
    const hasCurrent = activeCatalog.some((item) => item.specialty_name === currentName)
    if (hasCurrent) {
      return activeCatalog
    }
    return [
      {
        id: 'current',
        specialty_name: currentName,
        description: '',
        specialty_icon: '',
        default_duration_minutes: 60,
        is_active: true,
        display_order: 0,
      },
      ...activeCatalog,
    ]
  }, [proceduresCatalogQuery.data, procedureForm.nome_procedimento])

  const professionalOptions = useMemo(() => {
    const team = (professionalsQuery.data || []) as TeamMember[]
    const professionals = team.filter((member) =>
      member.role_code === 'surgeon' || member.role_code === 'clinic_master',
    )
    const currentProfessional = procedureForm.profissional_responsavel.trim()
    const names = new Set(professionals.map((member) => member.name))
    if (currentProfessional && !names.has(currentProfessional)) {
      return [currentProfessional, ...Array.from(names)]
    }
    return Array.from(names)
  }, [professionalsQuery.data, procedureForm.profissional_responsavel])

  const editingProcedureImages = useMemo(() => {
    if (!procedureForm.id) {
      return []
    }
    const row = (proceduresQuery.data || []).find((item) => item.id === procedureForm.id)
    return row?.images || []
  }, [procedureForm.id, proceduresQuery.data])

  const onEditMedication = (item: PatientMedicationRecord) => {
    setMedicationForm({
      id: item.id,
      nome_medicamento: item.nome_medicamento,
      dosagem: item.dosagem || '',
      frequencia: item.frequencia || '',
      via_administracao: item.via_administracao || '',
      data_inicio: item.data_inicio || today,
      data_fim: item.data_fim || '',
      em_uso: item.em_uso,
      possui_alergia: item.possui_alergia,
      descricao: item.descricao || '',
    })
  }

  const onEditProcedure = (item: PatientProcedureRecord) => {
    setProcedureForm({
      id: item.id,
      nome_procedimento: item.nome_procedimento,
      descricao: item.descricao || '',
      data_procedimento: item.data_procedimento || today,
      profissional_responsavel: item.profissional_responsavel || '',
      observacoes: item.observacoes || '',
    })
    setProcedureFiles([])
  }

  const onEditDocument = (item: PatientDocumentRecord) => {
    setDocumentForm({
      id: item.id,
      titulo: item.titulo,
      descricao: item.descricao || '',
      tipo_arquivo: item.tipo_arquivo,
    })
    setDocumentFile(null)
  }

  const handleMedicationSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!medicationForm.nome_medicamento.trim()) {
      toast.error('Informe o nome do medicamento.')
      return
    }

    const payload = normalizeMedicationPayload(medicationForm)
    if (medicationForm.id) {
      updateMedicationMutation.mutate({
        id: medicationForm.id,
        payload,
      })
      return
    }
    createMedicationMutation.mutate(payload)
  }

  const handleProcedureSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!procedureForm.nome_procedimento.trim()) {
      toast.error('Informe o nome do procedimento.')
      return
    }
    const payload = normalizeProcedurePayload(procedureForm, procedureFiles)
    if (procedureForm.id) {
      updateProcedureMutation.mutate({ id: procedureForm.id, payload })
      return
    }
    createProcedureMutation.mutate(payload)
  }

  const handleDocumentSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!documentForm.titulo.trim()) {
      toast.error('Informe o título do documento.')
      return
    }
    if (!documentForm.id && !documentFile) {
      toast.error('Selecione um arquivo PDF ou imagem.')
      return
    }
    const payload = normalizeDocumentPayload(documentForm, documentFile)
    if (documentForm.id) {
      updateDocumentMutation.mutate({ id: documentForm.id, payload })
      return
    }
    createDocumentMutation.mutate(payload)
  }

  const handleDeleteProcedureImage = (procedureId: string, imageId: string) => {
    const shouldDelete = window.confirm('Deseja remover esta imagem do procedimento?')
    if (!shouldDelete) {
      return
    }
    deleteProcedureImageMutation.mutate({ procedureId, imageId })
  }

  return (
    <>
      <Card>
        <h2 className="section-heading mb-2">Prontuário</h2>
        <p className="caption mb-4">
          Gerencie medicações, histórico de procedimentos e documentos digitais do paciente.
        </p>
        <div className="grid gap-3 md:grid-cols-3">
          <button
            type="button"
            className="rounded-card border border-slate-200 bg-slate-50 p-4 text-left transition hover:border-primary/30 hover:bg-tealIce"
            onClick={() => setOpenSection('medications')}
          >
            <div className="mb-2 inline-flex rounded-lg bg-primary/10 p-2 text-primary">
              <Pill className="h-4 w-4" />
            </div>
            <p className="text-sm font-semibold text-night">Medicamentos em uso</p>
            <p className="caption">{activeMedicationsCount} ativos</p>
          </button>

          <button
            type="button"
            className="rounded-card border border-slate-200 bg-slate-50 p-4 text-left transition hover:border-primary/30 hover:bg-tealIce"
            onClick={() => setOpenSection('procedures')}
          >
            <div className="mb-2 inline-flex rounded-lg bg-primary/10 p-2 text-primary">
              <History className="h-4 w-4" />
            </div>
            <p className="text-sm font-semibold text-night">Histórico de procedimentos</p>
            <p className="caption">{proceduresQuery.data?.length || 0} itens</p>
          </button>

          <button
            type="button"
            className="rounded-card border border-slate-200 bg-slate-50 p-4 text-left transition hover:border-primary/30 hover:bg-tealIce"
            onClick={() => setOpenSection('documents')}
          >
            <div className="mb-2 inline-flex rounded-lg bg-primary/10 p-2 text-primary">
              <FileText className="h-4 w-4" />
            </div>
            <p className="text-sm font-semibold text-night">Documentos digitais</p>
            <p className="caption">{documentsQuery.data?.length || 0} arquivos</p>
          </button>
        </div>
      </Card>

      <Modal
        isOpen={openSection === 'medications'}
        onClose={() => {
          setOpenSection(null)
          setMedicationForm(emptyMedication)
        }}
        title="Medicamentos em uso"
        className="max-w-4xl"
      >
        <form className="grid gap-3 border-b border-slate-100 pb-4" onSubmit={handleMedicationSubmit}>
          <div className="flex items-center justify-between">
            <h4 className="text-sm font-semibold text-night">
              {medicationForm.id ? 'Editar medicamento' : 'Adicionar medicamento'}
            </h4>
            {medicationForm.id ? (
              <Button
                type="button"
                variant="secondary"
                size="sm"
                onClick={() => setMedicationForm(emptyMedication)}
              >
                Limpar edição
              </Button>
            ) : null}
          </div>
          <div className="grid gap-3 md:grid-cols-2">
            <Input
              placeholder="Nome do medicamento"
              value={medicationForm.nome_medicamento}
              onChange={(event) =>
                setMedicationForm((prev) => ({ ...prev, nome_medicamento: event.target.value }))
              }
            />
            <Input
              placeholder="Dosagem"
              value={medicationForm.dosagem}
              onChange={(event) => setMedicationForm((prev) => ({ ...prev, dosagem: event.target.value }))}
            />
            <Input
              placeholder="Frequência (ex.: 8/8h)"
              value={medicationForm.frequencia}
              onChange={(event) =>
                setMedicationForm((prev) => ({ ...prev, frequencia: event.target.value }))
              }
            />
            <Input
              placeholder="Via de administração"
              value={medicationForm.via_administracao}
              onChange={(event) =>
                setMedicationForm((prev) => ({ ...prev, via_administracao: event.target.value }))
              }
            />
            <Input
              type="date"
              value={medicationForm.data_inicio}
              onChange={(event) =>
                setMedicationForm((prev) => ({ ...prev, data_inicio: event.target.value }))
              }
            />
            <Input
              type="date"
              value={medicationForm.data_fim}
              onChange={(event) => setMedicationForm((prev) => ({ ...prev, data_fim: event.target.value }))}
            />
          </div>
          <div className="grid gap-3 md:grid-cols-2">
            <label className="flex items-center gap-2 text-sm text-slate-700">
              <input
                type="checkbox"
                checked={medicationForm.em_uso}
                onChange={(event) =>
                  setMedicationForm((prev) => ({ ...prev, em_uso: event.target.checked }))
                }
              />
              Em uso
            </label>
            <label className="flex items-center gap-2 text-sm text-slate-700">
              <input
                type="checkbox"
                checked={medicationForm.possui_alergia}
                onChange={(event) =>
                  setMedicationForm((prev) => ({ ...prev, possui_alergia: event.target.checked }))
                }
              />
              Possui alergia
            </label>
          </div>
          <TextArea
            placeholder="Descrição"
            value={medicationForm.descricao}
            onChange={(event) =>
              setMedicationForm((prev) => ({ ...prev, descricao: event.target.value }))
            }
          />
          <div className="flex justify-end">
            <Button
              type="submit"
              disabled={createMedicationMutation.isPending || updateMedicationMutation.isPending}
            >
              <Save className="h-4 w-4" />
              Salvar medicamento
            </Button>
          </div>
        </form>

        <div className="mt-4 space-y-3">
          {(medicationsQuery.data || []).length === 0 ? (
            <p className="text-sm text-slate-500">Nenhum medicamento cadastrado.</p>
          ) : (
            (medicationsQuery.data || []).map((item) => (
              <div
                key={item.id}
                className="rounded-card border border-slate-200 bg-slate-50 p-3"
              >
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div>
                    <p className="text-sm font-semibold text-night">{item.nome_medicamento}</p>
                    <p className="caption">
                      {item.dosagem || 'Dosagem não informada'} • {item.frequencia || 'Frequência não informada'}
                    </p>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <Badge className={item.em_uso ? 'bg-success/15 text-success' : 'bg-slate-200 text-slate-600'}>
                      {item.em_uso ? 'Em uso' : 'Inativo'}
                    </Badge>
                    <Button type="button" variant="secondary" size="sm" onClick={() => onEditMedication(item)}>
                      Editar
                    </Button>
                    <Button
                      type="button"
                      variant="danger"
                      size="sm"
                      onClick={() => deactivateMedicationMutation.mutate(item.id)}
                    >
                      <Trash2 className="h-4 w-4" />
                      Desativar
                    </Button>
                  </div>
                </div>
                {item.descricao ? <p className="mt-2 text-sm text-slate-600">{item.descricao}</p> : null}
              </div>
            ))
          )}
        </div>
      </Modal>

      <Modal
        isOpen={openSection === 'procedures'}
        onClose={() => {
          setOpenSection(null)
          setProcedureForm(emptyProcedure)
          setProcedureFiles([])
        }}
        title="Histórico de procedimentos"
        className="max-w-5xl"
      >
        <form className="grid gap-3 border-b border-slate-100 pb-4" onSubmit={handleProcedureSubmit}>
          <div className="flex items-center justify-between">
            <h4 className="text-sm font-semibold text-night">
              {procedureForm.id ? 'Editar procedimento' : 'Adicionar procedimento'}
            </h4>
            {procedureForm.id ? (
              <Button
                type="button"
                variant="secondary"
                size="sm"
                onClick={() => {
                  setProcedureForm(emptyProcedure)
                  setProcedureFiles([])
                }}
              >
                Limpar edição
              </Button>
            ) : null}
          </div>
          <div className="grid gap-3 md:grid-cols-2">
            <Select
              value={procedureForm.nome_procedimento}
              onChange={(event) =>
                setProcedureForm((prev) => ({ ...prev, nome_procedimento: event.target.value }))
              }
            >
              <option value="">Selecione o procedimento</option>
              {procedureOptions.map((item) => (
                <option key={item.id} value={item.specialty_name}>
                  {item.specialty_name}
                </option>
              ))}
            </Select>
            <Input
              type="date"
              value={procedureForm.data_procedimento}
              onChange={(event) =>
                setProcedureForm((prev) => ({ ...prev, data_procedimento: event.target.value }))
              }
            />
          </div>
          <Select
            value={procedureForm.profissional_responsavel}
            onChange={(event) =>
              setProcedureForm((prev) => ({ ...prev, profissional_responsavel: event.target.value }))
            }
          >
            <option value="">Selecione o profissional responsável</option>
            {professionalOptions.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </Select>
          {proceduresCatalogQuery.isLoading || professionalsQuery.isLoading ? (
            <p className="caption">Carregando procedimentos e profissionais...</p>
          ) : null}
          <TextArea
            placeholder="Descrição"
            value={procedureForm.descricao}
            onChange={(event) => setProcedureForm((prev) => ({ ...prev, descricao: event.target.value }))}
          />
          <TextArea
            placeholder="Observações"
            value={procedureForm.observacoes}
            onChange={(event) => setProcedureForm((prev) => ({ ...prev, observacoes: event.target.value }))}
          />
          <div className="grid gap-2">
            <label className="text-sm font-medium text-slate-700">Imagens do procedimento</label>
            <Input
              type="file"
              multiple
              accept="image/*"
              onChange={(event) => setProcedureFiles(Array.from(event.target.files || []))}
            />
            {procedureFiles.length > 0 ? (
              <p className="caption">{procedureFiles.length} arquivo(s) selecionado(s) para envio.</p>
            ) : null}
            {editingProcedureImages.length > 0 ? (
              <div className="flex flex-wrap gap-2">
                {editingProcedureImages.map((image) => (
                  <div key={image.id} className="relative h-16 w-16 overflow-hidden rounded-md border border-slate-200">
                    <a href={image.image_url} target="_blank" rel="noreferrer" title="Imagem já salva">
                      <img src={image.image_url} alt="Imagem do procedimento" className="h-full w-full object-cover" />
                    </a>
                    {procedureForm.id ? (
                      <button
                        type="button"
                        className="absolute right-1 top-1 rounded-full bg-red-600 px-1.5 py-0.5 text-[10px] font-semibold text-white hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-60"
                        onClick={() => handleDeleteProcedureImage(procedureForm.id as string, image.id)}
                        disabled={deleteProcedureImageMutation.isPending && removingProcedureImageId === image.id}
                        title="Remover imagem"
                      >
                        {deleteProcedureImageMutation.isPending && removingProcedureImageId === image.id ? '...' : 'X'}
                      </button>
                    ) : null}
                  </div>
                ))}
              </div>
            ) : null}
          </div>
          <div className="flex justify-end">
            <Button
              type="submit"
              disabled={createProcedureMutation.isPending || updateProcedureMutation.isPending}
            >
              <Plus className="h-4 w-4" />
              Salvar procedimento
            </Button>
          </div>
        </form>

        <div className="mt-4 space-y-3">
          {(proceduresQuery.data || []).length === 0 ? (
            <p className="text-sm text-slate-500">Nenhum procedimento cadastrado.</p>
          ) : (
            (proceduresQuery.data || []).map((item) => (
              <div key={item.id} className="rounded-card border border-slate-200 bg-slate-50 p-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div>
                    <p className="text-sm font-semibold text-night">{item.nome_procedimento}</p>
                    <p className="caption">
                      {formatDate(item.data_procedimento)} • {item.profissional_responsavel || 'Profissional não informado'}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <Button type="button" size="sm" variant="secondary" onClick={() => onEditProcedure(item)}>
                      Editar
                    </Button>
                    <Button
                      type="button"
                      size="sm"
                      variant="danger"
                      onClick={() => deleteProcedureMutation.mutate(item.id)}
                    >
                      <Trash2 className="h-4 w-4" />
                      Excluir
                    </Button>
                  </div>
                </div>
                {item.descricao ? <p className="mt-2 text-sm text-slate-600">{item.descricao}</p> : null}
                {item.observacoes ? <p className="mt-1 text-sm text-slate-500">{item.observacoes}</p> : null}
                {item.images.length ? (
                  <div className="mt-3 flex flex-wrap gap-2">
                    {item.images.map((image) => (
                      <div key={image.id} className="relative h-16 w-16 overflow-hidden rounded-md border border-slate-200">
                        <a href={image.image_url} target="_blank" rel="noreferrer">
                          <img src={image.image_url} alt="Procedimento" className="h-full w-full object-cover" />
                        </a>
                        <button
                          type="button"
                          className="absolute right-1 top-1 rounded-full bg-red-600 px-1.5 py-0.5 text-[10px] font-semibold text-white hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-60"
                          onClick={() => handleDeleteProcedureImage(item.id, image.id)}
                          disabled={deleteProcedureImageMutation.isPending && removingProcedureImageId === image.id}
                          title="Remover imagem"
                        >
                          {deleteProcedureImageMutation.isPending && removingProcedureImageId === image.id ? '...' : 'X'}
                        </button>
                      </div>
                    ))}
                  </div>
                ) : null}
              </div>
            ))
          )}
        </div>
      </Modal>

      <Modal
        isOpen={openSection === 'documents'}
        onClose={() => {
          setOpenSection(null)
          setDocumentForm(emptyDocument)
          setDocumentFile(null)
        }}
        title="Documentos digitais"
        className="max-w-4xl"
      >
        <form className="grid gap-3 border-b border-slate-100 pb-4" onSubmit={handleDocumentSubmit}>
          <div className="flex items-center justify-between">
            <h4 className="text-sm font-semibold text-night">
              {documentForm.id ? 'Editar documento' : 'Adicionar documento'}
            </h4>
            {documentForm.id ? (
              <Button
                type="button"
                variant="secondary"
                size="sm"
                onClick={() => {
                  setDocumentForm(emptyDocument)
                  setDocumentFile(null)
                }}
              >
                Limpar edição
              </Button>
            ) : null}
          </div>

          <Input
            placeholder="Título"
            value={documentForm.titulo}
            onChange={(event) => setDocumentForm((prev) => ({ ...prev, titulo: event.target.value }))}
          />
          <TextArea
            placeholder="Descrição"
            value={documentForm.descricao}
            onChange={(event) => setDocumentForm((prev) => ({ ...prev, descricao: event.target.value }))}
          />
          <div className="grid gap-3 md:grid-cols-2">
            <Select
              value={documentForm.tipo_arquivo}
              onChange={(event) =>
                setDocumentForm((prev) => ({
                  ...prev,
                  tipo_arquivo: event.target.value as 'pdf' | 'imagem',
                }))
              }
            >
              <option value="pdf">PDF</option>
              <option value="imagem">Imagem</option>
            </Select>
            <Input
              type="file"
              accept=".pdf,image/*"
              onChange={(event) => {
                const file = event.target.files?.[0] || null
                setDocumentFile(file)
                if (file && file.type.startsWith('image/')) {
                  setDocumentForm((prev) => ({ ...prev, tipo_arquivo: 'imagem' }))
                }
                if (file && file.type === 'application/pdf') {
                  setDocumentForm((prev) => ({ ...prev, tipo_arquivo: 'pdf' }))
                }
              }}
            />
          </div>
          <div className="flex justify-end">
            <Button
              type="submit"
              disabled={createDocumentMutation.isPending || updateDocumentMutation.isPending}
            >
              <Plus className="h-4 w-4" />
              Salvar documento
            </Button>
          </div>
        </form>

        <div className="mt-4 space-y-3">
          {(documentsQuery.data || []).length === 0 ? (
            <p className="text-sm text-slate-500">Nenhum documento cadastrado.</p>
          ) : (
            (documentsQuery.data || []).map((item) => (
              <div key={item.id} className="rounded-card border border-slate-200 bg-slate-50 p-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div>
                    <p className="text-sm font-semibold text-night">{item.titulo}</p>
                    <p className="caption">
                      {item.tipo_arquivo.toUpperCase()} • {formatDate(item.criado_em)}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <Button type="button" size="sm" variant="secondary" onClick={() => onEditDocument(item)}>
                      Editar
                    </Button>
                    <Button
                      type="button"
                      size="sm"
                      variant="danger"
                      onClick={() => deleteDocumentMutation.mutate(item.id)}
                    >
                      <Trash2 className="h-4 w-4" />
                      Excluir
                    </Button>
                  </div>
                </div>
                {item.descricao ? <p className="mt-2 text-sm text-slate-600">{item.descricao}</p> : null}
                <a
                  href={item.arquivo_url}
                  target="_blank"
                  rel="noreferrer"
                  className="mt-2 inline-block text-sm font-semibold text-primary underline-offset-4 hover:underline"
                >
                  Abrir / baixar arquivo
                </a>
              </div>
            ))
          )}
        </div>
      </Modal>
    </>
  )
}
