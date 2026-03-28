import { useEffect } from 'react'

import { startDomTranslator } from '@/i18n/domTranslator'
import { AppRoutes } from '@/routes/AppRoutes'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { useTenantStore } from '@/stores/tenantStore'

export default function App() {
  const loadTenantBranding = useTenantStore((state) => state.loadTenantBranding)
  const initializePreferences = usePreferencesStore((state) => state.initialize)
  const language = usePreferencesStore((state) => state.language)

  useEffect(() => {
    void loadTenantBranding()
  }, [loadTenantBranding])

  useEffect(() => {
    initializePreferences()
  }, [initializePreferences])

  useEffect(() => {
    return startDomTranslator(language)
  }, [language])

  return <AppRoutes />
}
