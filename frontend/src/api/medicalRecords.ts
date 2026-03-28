import { apiClient } from '@/lib/axios'
import type {
  PatientDocumentRecord,
  PatientMedicationRecord,
  PatientProcedureRecord,
} from '@/types'

export interface PatientMedicationPayload {
  nome_medicamento: string
  dosagem?: string
  frequencia?: string
  via_administracao?: string
  data_inicio: string
  data_fim?: string
  em_uso: boolean
  possui_alergia: boolean
  descricao?: string
}

export interface PatientProcedurePayload {
  nome_procedimento: string
  descricao?: string
  data_procedimento: string
  profissional_responsavel?: string
  observacoes?: string
  image_urls?: string[]
  images?: File[]
}

export interface PatientDocumentPayload {
  titulo: string
  descricao?: string
  tipo_arquivo?: 'pdf' | 'imagem'
  file?: File
  file_url?: string
}

function buildProcedureFormData(payload: Partial<PatientProcedurePayload>) {
  const formData = new FormData()
  if (typeof payload.nome_procedimento === 'string') {
    formData.append('nome_procedimento', payload.nome_procedimento)
  }
  if (typeof payload.data_procedimento === 'string') {
    formData.append('data_procedimento', payload.data_procedimento)
  }
  if (typeof payload.descricao === 'string') {
    formData.append('descricao', payload.descricao)
  }
  if (typeof payload.profissional_responsavel === 'string') {
    formData.append('profissional_responsavel', payload.profissional_responsavel)
  }
  if (typeof payload.observacoes === 'string') {
    formData.append('observacoes', payload.observacoes)
  }
  ;(payload.image_urls || []).forEach((url) => formData.append('image_urls', url))
  ;(payload.images || []).forEach((file) => formData.append('images', file))
  return formData
}

function buildDocumentFormData(payload: Partial<PatientDocumentPayload>) {
  const formData = new FormData()
  if (typeof payload.titulo === 'string') {
    formData.append('titulo', payload.titulo)
  }
  if (typeof payload.descricao === 'string') {
    formData.append('descricao', payload.descricao)
  }
  if (payload.tipo_arquivo) {
    formData.append('tipo_arquivo', payload.tipo_arquivo)
  }
  if (payload.file) {
    formData.append('file', payload.file)
  }
  if (payload.file_url) {
    formData.append('file_url', payload.file_url)
  }
  return formData
}

export async function listPatientMedications(patientId: string) {
  const { data } = await apiClient.get<PatientMedicationRecord[]>(
    `/patients/${patientId}/medications/`,
  )
  return data
}

export async function createPatientMedication(
  patientId: string,
  payload: PatientMedicationPayload,
) {
  const { data } = await apiClient.post<PatientMedicationRecord>(
    `/patients/${patientId}/medications/`,
    payload,
  )
  return data
}

export async function updatePatientMedication(
  patientId: string,
  medicationId: string,
  payload: Partial<PatientMedicationPayload>,
) {
  const { data } = await apiClient.patch<PatientMedicationRecord>(
    `/patients/${patientId}/medications/${medicationId}/`,
    payload,
  )
  return data
}

export async function deactivatePatientMedication(patientId: string, medicationId: string) {
  await apiClient.delete(`/patients/${patientId}/medications/${medicationId}/`)
}

export async function listPatientProcedures(patientId: string) {
  const { data } = await apiClient.get<PatientProcedureRecord[]>(
    `/patients/${patientId}/procedures/`,
  )
  return data
}

export async function createPatientProcedure(
  patientId: string,
  payload: PatientProcedurePayload,
) {
  const formData = buildProcedureFormData(payload)
  const { data } = await apiClient.post<PatientProcedureRecord>(
    `/patients/${patientId}/procedures/`,
    formData,
    {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    },
  )
  return data
}

export async function updatePatientProcedure(
  patientId: string,
  procedureId: string,
  payload: Partial<PatientProcedurePayload>,
) {
  const formData = buildProcedureFormData(payload)
  const { data } = await apiClient.patch<PatientProcedureRecord>(
    `/patients/${patientId}/procedures/${procedureId}/`,
    formData,
    {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    },
  )
  return data
}

export async function deletePatientProcedure(patientId: string, procedureId: string) {
  await apiClient.delete(`/patients/${patientId}/procedures/${procedureId}/`)
}

export async function deletePatientProcedureImage(
  patientId: string,
  procedureId: string,
  imageId: string,
) {
  await apiClient.delete(`/patients/${patientId}/procedures/${procedureId}/images/${imageId}/`)
}

export async function listPatientDocuments(patientId: string) {
  const { data } = await apiClient.get<PatientDocumentRecord[]>(
    `/patients/${patientId}/documents/`,
  )
  return data
}

export async function createPatientDocument(
  patientId: string,
  payload: PatientDocumentPayload,
) {
  const formData = buildDocumentFormData(payload)
  const { data } = await apiClient.post<PatientDocumentRecord>(
    `/patients/${patientId}/documents/`,
    formData,
    {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    },
  )
  return data
}

export async function updatePatientDocument(
  patientId: string,
  documentId: string,
  payload: Partial<PatientDocumentPayload>,
) {
  const formData = buildDocumentFormData(payload)
  const { data } = await apiClient.patch<PatientDocumentRecord>(
    `/patients/${patientId}/documents/${documentId}/`,
    formData,
    {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    },
  )
  return data
}

export async function deletePatientDocument(patientId: string, documentId: string) {
  await apiClient.delete(`/patients/${patientId}/documents/${documentId}/`)
}
