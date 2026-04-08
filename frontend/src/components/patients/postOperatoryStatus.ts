import type {
  PostOperatoryAdminDetail,
  PostOperatoryAdminItem,
  PostOperatoryCheckinRecord,
} from '@/types'
import type { TranslationKey } from '@/i18n/system'

type JourneyStatus = PostOperatoryAdminItem['status']
type ClinicalStatus = PostOperatoryAdminItem['clinical_status']
type Translator = (key: TranslationKey) => string

export function postOperatoryJourneyStatusLabel(
  status: JourneyStatus | undefined,
  t?: Translator,
) {
  if (status === 'completed') return t ? t('postop_status_completed') : 'Concluído'
  if (status === 'cancelled') return t ? t('postop_status_cancelled') : 'Cancelado'
  return t ? t('postop_status_active') : 'Em andamento'
}

export function postOperatoryJourneyStatusClass(status: JourneyStatus | undefined) {
  if (status === 'completed') return 'bg-success/15 text-success'
  if (status === 'cancelled') return 'bg-danger/15 text-danger'
  return 'bg-primary/15 text-primary'
}

export function postOperatoryClinicalStatusLabel(
  status: ClinicalStatus | undefined,
  t?: Translator,
) {
  if (status === 'risk') return t ? t('postop_clinical_status_risk') : 'Em risco'
  if (status === 'delayed') return t ? t('postop_clinical_status_delayed') : 'Atrasado'
  return t ? t('postop_clinical_status_ok') : 'OK'
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

export function postOperatoryDetailSummary(detail: PostOperatoryAdminDetail, t?: Translator) {
  return {
    journeyStatus: postOperatoryJourneyStatusLabel(detail.status, t),
    journeyClass: postOperatoryJourneyStatusClass(detail.status),
    clinicalStatus: postOperatoryClinicalStatusLabel(detail.clinical_status, t),
    clinicalClass: postOperatoryClinicalStatusClass(detail.clinical_status),
  }
}

export function getLatestCheckin(detail: PostOperatoryAdminDetail): PostOperatoryCheckinRecord | null {
  if (!Array.isArray(detail.checkins) || detail.checkins.length === 0) {
    return null
  }
  return detail.checkins[0]
}

export function postOperatoryClinicalReason(detail: PostOperatoryAdminDetail, t?: Translator): string {
  const latest = getLatestCheckin(detail)

  if (detail.clinical_status === 'risk') {
    const hasPainAlert = Boolean(latest && latest.pain_level >= 8)
    const hasFeverAlert = Boolean(latest && latest.has_fever)
    if (hasPainAlert && hasFeverAlert) {
      return t
        ? t('postop_reason_risk_pain_fever')
        : 'Dor elevada e febre no último check-in'
    }
    if (hasPainAlert) {
      return t ? t('postop_reason_risk_pain') : 'Dor elevada no último check-in'
    }
    if (hasFeverAlert) {
      return t ? t('postop_reason_risk_fever') : 'Febre no último check-in'
    }
    return t
      ? t('postop_reason_risk_generic')
      : 'Sinais clínicos de atenção foram identificados'
  }

  if (detail.clinical_status === 'delayed') {
    const days = Math.max(detail.days_without_checkin || 0, 1)
    if (days === 1) return t ? t('postop_reason_delayed_today') : 'Paciente sem check-in hoje'
    if (!t) return `Paciente sem check-in há ${days} dias`
    return t('postop_reason_delayed_days').replace('{days}', String(days))
  }

  return t
    ? t('postop_reason_ok')
    : 'Paciente com check-in em dia e sem sinais críticos no último registro'
}

export function postOperatorySuggestedAction(detail: PostOperatoryAdminDetail, t?: Translator): string {
  if (detail.clinical_status === 'risk') {
    return t
      ? t('postop_suggested_action_risk')
      : 'Contato imediato recomendado para avaliação clínica'
  }
  if (detail.clinical_status === 'delayed') {
    return t
      ? t('postop_suggested_action_delayed')
      : 'Entrar em contato com o paciente para verificar ausência de check-in'
  }
  return t ? t('postop_suggested_action_ok') : 'Nenhuma ação necessária no momento'
}
