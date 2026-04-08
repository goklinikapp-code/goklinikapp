import type { PreOperatoryRecord } from '@/types'
import type { TranslationKey } from '@/i18n/system'

type Translator = (key: TranslationKey) => string

export function preOperatoryStatusLabel(
  status?: PreOperatoryRecord['status'],
  t?: Translator,
) {
  switch (status) {
    case 'approved':
      return t ? t('preop_status_approved') : 'Aprovado'
    case 'in_review':
      return t ? t('preop_status_in_review') : 'Em análise'
    case 'rejected':
      return t ? t('preop_status_rejected') : 'Rejeitado'
    case 'pending':
    default:
      return t ? t('preop_status_pending') : 'Pendente'
  }
}
