import type {
  PostOperatoryAdminDetail,
  PostOperatoryAdminItem,
  PostOperatoryCheckinRecord,
} from '@/types'

type JourneyStatus = PostOperatoryAdminItem['status']
type ClinicalStatus = PostOperatoryAdminItem['clinical_status']

export function postOperatoryJourneyStatusLabel(status: JourneyStatus | undefined) {
  if (status === 'completed') return 'Concluído'
  if (status === 'cancelled') return 'Cancelado'
  return 'Em andamento'
}

export function postOperatoryJourneyStatusClass(status: JourneyStatus | undefined) {
  if (status === 'completed') return 'bg-success/15 text-success'
  if (status === 'cancelled') return 'bg-danger/15 text-danger'
  return 'bg-primary/15 text-primary'
}

export function postOperatoryClinicalStatusLabel(status: ClinicalStatus | undefined) {
  if (status === 'risk') return 'Em risco'
  if (status === 'delayed') return 'Atrasado'
  return 'OK'
}

export function postOperatoryClinicalStatusClass(status: ClinicalStatus | undefined) {
  if (status === 'risk') return 'bg-danger/20 text-danger'
  if (status === 'delayed') return 'bg-amber-100 text-amber-700'
  return 'bg-success/15 text-success'
}

export function hasCheckinToday(item: PostOperatoryAdminItem): boolean {
  if (!item.last_checkin_date || item.status !== 'active') return false

  const now = new Date()
  const checkin = new Date(item.last_checkin_date)
  if (Number.isNaN(checkin.getTime())) return false

  return (
    now.getFullYear() === checkin.getFullYear() &&
    now.getMonth() === checkin.getMonth() &&
    now.getDate() === checkin.getDate()
  )
}

export function postOperatoryDetailSummary(detail: PostOperatoryAdminDetail) {
  return {
    journeyStatus: postOperatoryJourneyStatusLabel(detail.status),
    journeyClass: postOperatoryJourneyStatusClass(detail.status),
    clinicalStatus: postOperatoryClinicalStatusLabel(detail.clinical_status),
    clinicalClass: postOperatoryClinicalStatusClass(detail.clinical_status),
  }
}

export function getLatestCheckin(detail: PostOperatoryAdminDetail): PostOperatoryCheckinRecord | null {
  if (!Array.isArray(detail.checkins) || detail.checkins.length === 0) {
    return null
  }
  return detail.checkins[0]
}

export function postOperatoryClinicalReason(detail: PostOperatoryAdminDetail): string {
  const latest = getLatestCheckin(detail)

  if (detail.clinical_status === 'risk') {
    const hasPainAlert = Boolean(latest && latest.pain_level >= 8)
    const hasFeverAlert = Boolean(latest && latest.has_fever)
    if (hasPainAlert && hasFeverAlert) return 'Dor elevada e febre no último check-in'
    if (hasPainAlert) return 'Dor elevada no último check-in'
    if (hasFeverAlert) return 'Febre no último check-in'
    return 'Sinais clínicos de atenção foram identificados'
  }

  if (detail.clinical_status === 'delayed') {
    const days = Math.max(detail.days_without_checkin || 0, 1)
    if (days === 1) return 'Paciente sem check-in hoje'
    return `Paciente sem check-in há ${days} dias`
  }

  return 'Paciente com check-in em dia e sem sinais críticos no último registro'
}

export function postOperatorySuggestedAction(detail: PostOperatoryAdminDetail): string {
  if (detail.clinical_status === 'risk') {
    return 'Contato imediato recomendado para avaliação clínica'
  }
  if (detail.clinical_status === 'delayed') {
    return 'Entrar em contato com o paciente para verificar ausência de check-in'
  }
  return 'Nenhuma ação necessária no momento'
}
