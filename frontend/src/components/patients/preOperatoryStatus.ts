import type { PreOperatoryRecord } from '@/types'

export function preOperatoryStatusLabel(status?: PreOperatoryRecord['status']) {
  switch (status) {
    case 'approved':
      return 'Aprovado'
    case 'in_review':
      return 'Em análise'
    case 'rejected':
      return 'Rejeitado'
    case 'pending':
    default:
      return 'Pendente'
  }
}
