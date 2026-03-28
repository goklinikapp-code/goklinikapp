import { t, type SupportedLanguage } from '@/i18n/system'

export function useGreeting(language: SupportedLanguage): string {
  const hour = new Date().getHours()

  if (hour < 12) {
    return t(language, 'greeting_morning')
  }

  if (hour < 18) {
    return t(language, 'greeting_afternoon')
  }

  return t(language, 'greeting_evening')
}
