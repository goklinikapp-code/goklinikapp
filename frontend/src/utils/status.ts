import { normalizeLanguage, type SupportedLanguage } from '@/i18n/system'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { cn } from '@/utils/cn'

export function statusBadgeClass(status: string): string {
  const normalized = normalizeStatus(status)

  if (normalized === 'pending') {
    return cn('bg-slate-200 text-slate-700')
  }

  if (normalized === 'confirmed') {
    return cn('bg-blue-100 text-blue-700')
  }

  if (normalized === 'in_progress') {
    return cn('bg-amber-100 text-amber-700')
  }

  if (normalized === 'completed') {
    return cn('bg-emerald-100 text-emerald-700')
  }

  if (normalized === 'cancelled' || normalized === 'error') {
    return cn('bg-rose-100 text-rose-700')
  }

  if (normalized === 'rescheduled') {
    return cn('bg-violet-100 text-violet-700')
  }

  if (normalized === 'active' || normalized === 'paid') {
    return cn('bg-secondary text-white')
  }

  if (normalized === 'inactive') {
    return cn('bg-slate-300 text-slate-700')
  }

  return cn('bg-slate-200 text-slate-700')
}

export function statusLabel(status: string): string {
  const language = normalizeLanguage(usePreferencesStore.getState().language)
  const normalized = normalizeStatus(status)
  const map = labelsByLanguage[language]
  if (normalized in map) {
    return map[normalized as StatusKey]
  }
  return status
}

type StatusKey =
  | 'confirmed'
  | 'pending'
  | 'cancelled'
  | 'active'
  | 'inactive'
  | 'completed'
  | 'in_progress'
  | 'rescheduled'
  | 'paid'
  | 'error'

const labelsByLanguage: Record<SupportedLanguage, Record<StatusKey, string>> = {
  pt: {
    confirmed: 'Confirmado',
    pending: 'Aguardando',
    cancelled: 'Cancelado',
    active: 'Ativo',
    inactive: 'Inativo',
    completed: 'Concluido',
    in_progress: 'Em andamento',
    rescheduled: 'Reagendado',
    paid: 'Pago',
    error: 'Erro',
  },
  en: {
    confirmed: 'Confirmed',
    pending: 'Pending',
    cancelled: 'Cancelled',
    active: 'Active',
    inactive: 'Inactive',
    completed: 'Completed',
    in_progress: 'In progress',
    rescheduled: 'Rescheduled',
    paid: 'Paid',
    error: 'Error',
  },
  es: {
    confirmed: 'Confirmado',
    pending: 'Pendiente',
    cancelled: 'Cancelado',
    active: 'Activo',
    inactive: 'Inactivo',
    completed: 'Completado',
    in_progress: 'En progreso',
    rescheduled: 'Reprogramado',
    paid: 'Pagado',
    error: 'Error',
  },
  de: {
    confirmed: 'Bestaetigt',
    pending: 'Ausstehend',
    cancelled: 'Storniert',
    active: 'Aktiv',
    inactive: 'Inaktiv',
    completed: 'Abgeschlossen',
    in_progress: 'In Bearbeitung',
    rescheduled: 'Neu geplant',
    paid: 'Bezahlt',
    error: 'Fehler',
  },
  ru: {
    confirmed: 'Podtverzhdeno',
    pending: 'V ozhidanii',
    cancelled: 'Otmeneno',
    active: 'Aktiven',
    inactive: 'Ne aktivno',
    completed: 'Zaversheno',
    in_progress: 'V processe',
    rescheduled: 'Pereneseno',
    paid: 'Oplacheno',
    error: 'Oshibka',
  },
  tr: {
    confirmed: 'Onaylandi',
    pending: 'Beklemede',
    cancelled: 'Iptal edildi',
    active: 'Aktif',
    inactive: 'Pasif',
    completed: 'Tamamlandi',
    in_progress: 'Devam ediyor',
    rescheduled: 'Yeniden planlandi',
    paid: 'Odendi',
    error: 'Hata',
  },
}

const statusAliasMap: Record<string, StatusKey> = {
  confirmed: 'confirmed',
  confirmado: 'confirmed',
  pending: 'pending',
  aguardando: 'pending',
  cancelled: 'cancelled',
  canceled: 'cancelled',
  cancelado: 'cancelled',
  active: 'active',
  ativo: 'active',
  inactive: 'inactive',
  inativo: 'inactive',
  completed: 'completed',
  concluido: 'completed',
  'concluído': 'completed',
  in_progress: 'in_progress',
  'em andamento': 'in_progress',
  rescheduled: 'rescheduled',
  reagendado: 'rescheduled',
  paid: 'paid',
  pago: 'paid',
  error: 'error',
  erro: 'error',
}

function normalizeStatus(status: string): StatusKey | string {
  const raw = (status || '').trim().toLowerCase()
  return statusAliasMap[raw] || raw
}
