import { create } from 'zustand'
import { persist } from 'zustand/middleware'

import {
  detectLanguageFromBrowser,
  getLocaleForLanguage,
  normalizeCurrency,
  normalizeLanguage,
  resolveDefaultCurrency,
  type SupportedCurrency,
  type SupportedLanguage,
} from '@/i18n/system'

type PreferenceMode = 'auto' | 'manual'

interface PreferencesState {
  language: SupportedLanguage
  currency: SupportedCurrency
  languageMode: PreferenceMode
  currencyMode: PreferenceMode
  initialized: boolean
  initialize: () => void
  setLanguage: (language: SupportedLanguage) => void
  setCurrency: (currency: SupportedCurrency) => void
  useAutomaticLanguage: () => void
  useAutomaticCurrency: () => void
}

export const PREFERENCES_STORAGE_KEY = 'goklinik-preferences'

const applyDocumentLanguage = (language: SupportedLanguage) => {
  if (typeof document === 'undefined') {
    return
  }
  document.documentElement.lang = getLocaleForLanguage(language)
}

const resolveLanguage = (state: PreferencesState): SupportedLanguage => {
  if (state.languageMode === 'manual') {
    return normalizeLanguage(state.language)
  }
  return detectLanguageFromBrowser()
}

const resolveCurrency = (
  language: SupportedLanguage,
  state: PreferencesState,
): SupportedCurrency => {
  if (state.currencyMode === 'manual') {
    return normalizeCurrency(state.currency)
  }
  return resolveDefaultCurrency(language)
}

export const usePreferencesStore = create<PreferencesState>()(
  persist(
    (set) => ({
      language: 'en',
      currency: 'USD',
      languageMode: 'auto',
      currencyMode: 'auto',
      initialized: false,

      initialize: () => {
        set((state) => {
          const language = resolveLanguage(state)
          const currency = resolveCurrency(language, state)
          applyDocumentLanguage(language)
          return {
            language,
            currency,
            initialized: true,
          }
        })
      },

      setLanguage: (language) => {
        const normalizedLanguage = normalizeLanguage(language)
        set((state) => {
          const currency = state.currencyMode === 'manual'
            ? normalizeCurrency(state.currency)
            : resolveDefaultCurrency(normalizedLanguage)
          applyDocumentLanguage(normalizedLanguage)
          return {
            language: normalizedLanguage,
            languageMode: 'manual',
            currency,
          }
        })
      },

      setCurrency: (currency) => {
        set({
          currency: normalizeCurrency(currency),
          currencyMode: 'manual',
        })
      },

      useAutomaticLanguage: () => {
        set((state) => {
          const language = detectLanguageFromBrowser()
          const currency = state.currencyMode === 'manual'
            ? normalizeCurrency(state.currency)
            : resolveDefaultCurrency(language)
          applyDocumentLanguage(language)
          return {
            language,
            languageMode: 'auto',
            currency,
          }
        })
      },

      useAutomaticCurrency: () => {
        set((state) => ({
          currency: resolveDefaultCurrency(normalizeLanguage(state.language)),
          currencyMode: 'auto',
        }))
      },
    }),
    {
      name: PREFERENCES_STORAGE_KEY,
      partialize: (state) => ({
        language: state.language,
        currency: state.currency,
        languageMode: state.languageMode,
        currencyMode: state.currencyMode,
      }),
    },
  ),
)

