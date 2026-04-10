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
  app_installed_at: string | null
  last_app_login_at: string | null
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

export type WorkflowTriggerType = 'appointment_created' | 'reminder_before' | 'post_op_followup'

export interface WorkflowItem {
  id: string
  name: string
  is_active: boolean
  trigger_type: WorkflowTriggerType
  trigger_offset: string
  template?: string | null
  template_code?: string
  created_at: string
  updated_at: string
}

export interface NotificationTemplateOption {
  id: string
  code: string
  title_template: string
  body_template: string
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface NotificationRecipientOption {
  id: string
  full_name: string
  email: string
  phone: string
  has_active_push_token: boolean
  active_push_tokens: number
}

export interface AppNotificationItem {
  id: string
  title: string
  body: string
  notification_type: string
  is_read: boolean
  sent_at?: string | null
  related_object_id?: string | null
  created_at: string
}

export interface BroadcastPushResponse {
  detail: string
  campaign_status: 'success' | 'partial' | 'error' | 'no_recipients'
  segment: string
  total_recipients: number
  sent: number
  error: number
  skipped: number
  rate_limited: number
}

export interface NotificationCampaignLog {
  id: string
  user: string
  user_name?: string
  user_email?: string
  title: string
  body: string
  channel: 'push' | string
  status: 'sent' | 'error' | 'skipped' | 'rate_limited' | string
  event_code?: string
  segment?: string
  data_extra?: Record<string, string>
  error_message?: string
  created_at: string
}

export interface ScheduledNotificationItem {
  id: string
  run_at: string
  segment: 'all_patients' | 'future_appointments' | 'inactive_patients'
  title: string
  body: string
  template?: string | null
  template_code?: string
  template_context?: Record<string, string>
  data_extra?: Record<string, string>
  status: 'pending' | 'running' | 'completed' | 'error' | 'canceled'
  summary?: Record<string, number>
  error_message?: string
  processed_at?: string | null
  created_at: string
  updated_at: string
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
  patient_name?: string
  patient_avatar_url?: string | null
  tenant: string
  allergies: string
  medications: string
  previous_surgeries: string
  diseases: string
  smoking: boolean
  alcohol: boolean
  height?: number | null
  weight?: number | null
  notes?: string
  assigned_doctor?: string | null
  assigned_doctor_name?: string | null
  status: 'pending' | 'in_review' | 'approved' | 'rejected'
  files: PreOperatoryFileRecord[]
  photos: PreOperatoryFileRecord[]
  documents: PreOperatoryFileRecord[]
  created_at: string
  updated_at: string
}

export interface PostOperatoryAdminItem {
  patient_name: string
  patient_id: string
  patient_avatar_url?: string | null
  status: 'active' | 'completed' | 'cancelled'
  current_day: number
  total_days: number
  last_checkin_date?: string | null
  last_pain_level?: number | null
  has_alert: boolean
  clinical_status: 'ok' | 'delayed' | 'risk'
  has_open_urgent_ticket?: boolean
  open_urgent_ticket_count?: number
}

export interface PostOperatoryCheckinRecord {
  id: string
  journey: string
  day: number
  pain_level: number
  has_fever: boolean
  notes: string
  created_at: string
}

export interface PostOperatoryChecklistItemRecord {
  id: string
  day_number: number
  item_text: string
  is_completed: boolean
  completed_at?: string | null
}

export interface PostOperatoryChecklistDayRecord {
  day: number
  items: PostOperatoryChecklistItemRecord[]
}

export interface PostOperatoryPhotoRecord {
  id: string
  journey: string
  day_number: number
  photo_url: string
  uploaded_at: string
  is_visible_to_clinic: boolean
  is_anonymous: boolean
  day: number
  image: string
  created_at: string
}

export interface PostOperatoryObservationRecord {
  day: number
  notes: string
  created_at: string
}

export interface UrgentTicketRecord {
  id: string
  patient: string
  patient_name: string
  doctor?: string | null
  doctor_name?: string | null
  clinic: string
  post_op_journey: string
  message: string
  images: string[]
  severity: 'low' | 'medium' | 'high'
  status: 'open' | 'viewed' | 'resolved'
  created_at: string
  updated_at: string
}

export interface UrgentMedicalRequestRecord {
  id: string
  status: 'open' | 'answered' | 'closed'
  question: string
  answer: string
  patient_name: string
  patient_email: string
  patient_avatar_url?: string | null
  assigned_professional?: string | null
  assigned_professional_name?: string | null
  answered_by?: string | null
  answered_by_name?: string | null
  answered_at?: string | null
  created_at: string
  updated_at: string
}

export interface PostOperatoryAdminDetail {
  journey_id: string
  patient_id: string
  patient_name: string
  patient_avatar_url?: string | null
  status: 'active' | 'completed' | 'cancelled'
  current_day: number
  total_days: number
  surgery_date: string
  start_date?: string | null
  end_date?: string | null
  has_alert: boolean
  clinical_status: 'ok' | 'delayed' | 'risk'
  days_without_checkin: number
  last_checkin_date?: string | null
  last_pain_level?: number | null
  checkins: PostOperatoryCheckinRecord[]
  checklist_by_day: PostOperatoryChecklistDayRecord[]
  photos: PostOperatoryPhotoRecord[]
  observations: PostOperatoryObservationRecord[]
  has_open_urgent_ticket?: boolean
  urgent_tickets?: UrgentTicketRecord[]
}
