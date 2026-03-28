import { getLocaleForLanguage } from '@/i18n/system'
import { usePreferencesStore } from '@/stores/preferencesStore'

const DATE_ONLY_PATTERN = /^\d{4}-\d{2}-\d{2}$/

function parseDateValue(value: string | Date): { date: Date; isDateOnly: boolean } | null {
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) {
      return null
    }
    return { date: value, isDateOnly: false }
  }

  if (DATE_ONLY_PATTERN.test(value)) {
    // Date-only values from API (YYYY-MM-DD) should not shift by timezone.
    const date = new Date(`${value}T00:00:00Z`)
    if (Number.isNaN(date.getTime())) {
      return null
    }
    return { date, isDateOnly: true }
  }

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) {
    return null
  }
  return { date, isDateOnly: false }
}

export function formatCurrency(value: number): string {
  const { language, currency } = usePreferencesStore.getState()
  const locale = getLocaleForLanguage(language)

  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    maximumFractionDigits: 2,
  }).format(value || 0)
}

export function formatPercent(value: number): string {
  const prefix = value > 0 ? '+' : ''
  return `${prefix}${value.toFixed(1)}%`
}

export function formatDate(value?: string | Date): string {
  if (!value) {
    return '-'
  }

  const parsed = parseDateValue(value)
  if (!parsed) {
    return '-'
  }

  const { language } = usePreferencesStore.getState()
  const locale = getLocaleForLanguage(language)
  return new Intl.DateTimeFormat(locale, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    ...(parsed.isDateOnly ? { timeZone: 'UTC' } : {}),
  }).format(parsed.date)
}

export function formatLongDate(value?: string | Date): string {
  if (!value) {
    return '-'
  }

  const parsed = parseDateValue(value)
  if (!parsed) {
    return '-'
  }

  const { language } = usePreferencesStore.getState()
  const locale = getLocaleForLanguage(language)
  return new Intl.DateTimeFormat(locale, {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
    year: 'numeric',
    ...(parsed.isDateOnly ? { timeZone: 'UTC' } : {}),
  }).format(parsed.date)
}

export function initials(name?: string | null): string {
  const safeName = typeof name === 'string' ? name : ''
  const parts = safeName.trim().split(' ').filter(Boolean)
  if (!parts.length) {
    return 'NA'
  }

  return parts
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || '')
    .join('')
}
