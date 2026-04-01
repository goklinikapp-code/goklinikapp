export type UserRole =
  | 'super_admin'
  | 'clinic_master'
  | 'surgeon'
  | 'secretary'
  | 'nurse'
  | 'patient'

export type StatusType =
  | 'confirmed'
  | 'pending'
  | 'cancelled'
  | 'active'
  | 'inactive'
  | 'completed'
  | 'in_progress'
  | 'rescheduled'

export interface TenantBranding {
  id?: string
  name: string
  slug?: string
  primary_color: string
  secondary_color: string
  accent_color: string
  clinic_addresses?: string[]
  logo_url?: string | null
  favicon_url?: string | null
  ai_assistant_prompt?: string
}

export interface AuthUser {
  id: string
  email: string
  full_name: string
  role: UserRole
  avatar_url?: string
  access_permissions?: string[]
  tenant?: TenantBranding | null
}

export interface AuthResponse {
  access_token: string
  refresh_token: string
  user: AuthUser
}

export interface AppointmentSummary {
  id: string
  paciente_nome: string
  horario: string
  status: string
  tipo: string
  procedimento?: string
  localizacao?: string
}

export interface DashboardAlert {
  type: string
  patient_id: string
  name: string
  message: string
}

export interface DashboardResponse {
  revenue_series?: Array<{
    name: string
    atual: number
    projetado: number
  }>
  specialty_distribution?: Array<{
    name: string
    value: number
    color: string
  }>
  faturamento_mes_atual: number
  faturamento_mes_anterior: number
  variacao_percentual_faturamento: number
  total_pacientes_ativos: number
  total_pacientes_inativos: number
  novos_pacientes_mes: number
  agendamentos_hoje: AppointmentSummary[]
  taxa_ocupacao_semana: number
  ticket_medio_mes: number
  alertas: DashboardAlert[]
}

export interface PatientRow {
  id: string
  full_name: string
  email: string
  phone: string
  avatar_url?: string | null
  status: 'active' | 'inactive' | 'lead'
  specialty_name?: string
  date_joined?: string
  last_visit?: string
  assigned_doctor?: {
    id: string
    name: string
    email?: string
    phone?: string
    specialty?: string
    notes?: string
    assigned_at?: string
  } | null
}

export interface PatientDetail extends PatientRow {
  first_name?: string
  last_name?: string
  cpf?: string
  date_of_birth?: string
  avatar_url?: string | null
  blood_type?: string
  allergies?: string
  previous_surgeries?: string
  current_medications?: string
  emergency_contact_name?: string
  emergency_contact_phone?: string
  emergency_contact_relation?: string
  health_insurance?: string
  referral_source?: 'google' | 'instagram' | 'indication' | 'other' | string
  notes?: string
  tenant?: string
}

export interface TeamMember {
  id: string
  name: string
  email: string
  role: 'SaaS Owner' | 'Clinic Master' | 'Surgeon' | 'Secretary' | 'Nursing'
  role_code?: UserRole
  access_permissions?: string[]
  status: 'active' | 'inactive'
  avatar?: string
}

export interface TeamMemberDetail extends TeamMember {
  first_name?: string
  last_name?: string
  phone?: string
  cpf?: string
  date_of_birth?: string | null
  bio?: string
  crm_number?: string
  years_experience?: number | null
  is_visible_in_app?: boolean
  avatar_url?: string
  date_joined?: string
}

export interface ActivityLog {
  id: string
  created_at: string
  user: string
  action: string
  ip: string
}

export interface WorkflowItem {
  id: string
  title: string
  trigger: string
  action: string
  is_active: boolean
}

export interface FinancialKpi {
  label: string
  value: number
  variation: number
}

export interface PatientMedicationRecord {
  id: string
  nome_medicamento: string
  dosagem: string
  frequencia: string
  via_administracao: string
  data_inicio: string
  data_fim?: string | null
  em_uso: boolean
  possui_alergia: boolean
  descricao: string
  criado_em: string
  atualizado_em: string
}

export interface PatientProcedureImageRecord {
  id: string
  image_url: string
  criado_em: string
}

export interface PatientProcedureRecord {
  id: string
  nome_procedimento: string
  descricao: string
  data_procedimento: string
  profissional_responsavel: string
  observacoes: string
  images: PatientProcedureImageRecord[]
  criado_em: string
  atualizado_em: string
}

export interface PatientDocumentRecord {
  id: string
  titulo: string
  descricao: string
  arquivo_url: string
  tipo_arquivo: 'pdf' | 'imagem'
  uploaded_by?: string | null
  criado_em: string
}

export interface PreOperatoryFileRecord {
  id: string
  file_url: string
  type: 'photo' | 'document'
  created_at: string
}

export interface PreOperatoryRecord {
  id: string
  patient: string
  tenant: string
  allergies: string
  medications: string
  previous_surgeries: string
  diseases: string
  smoking: boolean
  alcohol: boolean
  height?: number | null
  weight?: number | null
  status: 'pending' | 'in_review' | 'approved' | 'rejected'
  files: PreOperatoryFileRecord[]
  photos: PreOperatoryFileRecord[]
  documents: PreOperatoryFileRecord[]
  created_at: string
  updated_at: string
}
