import type { DashboardResponse, PatientRow } from '@/types'

export const dashboardMock: DashboardResponse = {
  faturamento_mes_atual: 184230,
  faturamento_mes_anterior: 162300,
  variacao_percentual_faturamento: 13.52,
  total_pacientes_ativos: 986,
  total_pacientes_inativos: 142,
  novos_pacientes_mes: 78,
  taxa_ocupacao_semana: 84.6,
  ticket_medio_mes: 4120,
  agendamentos_hoje: [
    {
      id: '1',
      paciente_nome: 'Aylin Demir',
      horario: '09:00',
      status: 'confirmed',
      tipo: 'first_visit',
      procedimento: 'Rinoplastia',
      localizacao: 'Sala 2',
    },
    {
      id: '2',
      paciente_nome: 'Kerem Yildiz',
      horario: '10:30',
      status: 'pending',
      tipo: 'return',
      procedimento: 'Harmonizacao Facial',
      localizacao: 'Sala 1',
    },
    {
      id: '3',
      paciente_nome: 'Elif Kaya',
      horario: '14:00',
      status: 'completed',
      tipo: 'surgery',
      procedimento: 'Mamoplastia',
      localizacao: 'Centro Cirurgico',
    },
  ],
  alertas: [
    {
      type: 'inactive_patient',
      patient_id: '101',
      name: 'Nisa Arslan',
      message: 'Paciente sem retorno ha mais de 6 meses.',
    },
    {
      type: 'postop_pending',
      patient_id: '102',
      name: 'Mert Celik',
      message: 'Pos-op com retorno pendente em D+30.',
    },
  ],
}

export const revenueSeries = [
  { name: 'Jan', atual: 120000, projetado: 132000 },
  { name: 'Fev', atual: 145000, projetado: 150000 },
  { name: 'Mar', atual: 160000, projetado: 170000 },
  { name: 'Abr', atual: 168000, projetado: 174000 },
  { name: 'Mai', atual: 179000, projetado: 181000 },
  { name: 'Jun', atual: 184230, projetado: 195000 },
]

export const specialtyDistribution = [
  { name: 'Rinoplastia', value: 34, color: '#0D5C73' },
  { name: 'Mamoplastia', value: 26, color: '#4A7C59' },
  { name: 'Lipoaspiracao', value: 21, color: '#C8992E' },
  { name: 'Blefaroplastia', value: 19, color: '#1A1F2E' },
]

export const patientsMock: PatientRow[] = [
  {
    id: 'PT-1201',
    full_name: 'Aylin Demir',
    email: 'aylin@gmail.com',
    phone: '+90 555 121 3434',
    status: 'active',
    specialty_name: 'Rinoplastia',
    date_joined: '2025-11-14',
    last_visit: '2026-03-18',
    app_installed_at: null,
    last_app_login_at: null,
  },
  {
    id: 'PT-1202',
    full_name: 'Kerem Yildiz',
    email: 'kerem@gmail.com',
    phone: '+90 555 221 9988',
    status: 'inactive',
    specialty_name: 'Harmonizacao Facial',
    date_joined: '2025-08-02',
    last_visit: '2025-09-22',
    app_installed_at: null,
    last_app_login_at: null,
  },
  {
    id: 'PT-1203',
    full_name: 'Elif Kaya',
    email: 'elif@gmail.com',
    phone: '+90 555 556 3232',
    status: 'active',
    specialty_name: 'Mamoplastia',
    date_joined: '2026-01-03',
    last_visit: '2026-03-20',
    app_installed_at: null,
    last_app_login_at: null,
  },
]
