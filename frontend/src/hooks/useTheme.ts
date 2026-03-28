import { useEffect, useState } from 'react'

const THEME_KEY = 'goklinik-theme'

type ThemeMode = 'light' | 'dark'

function getInitialTheme(): ThemeMode {
  const fromStorage = localStorage.getItem(THEME_KEY)
  if (fromStorage === 'dark' || fromStorage === 'light') {
    return fromStorage
  }
  return 'light'
}

export function useTheme() {
  const [theme, setTheme] = useState<ThemeMode>(() => getInitialTheme())

  useEffect(() => {
    document.documentElement.classList.toggle('dark', theme === 'dark')
    document.body.classList.toggle('dark', theme === 'dark')
    localStorage.setItem(THEME_KEY, theme)
  }, [theme])

  return {
    theme,
    toggleTheme: () => setTheme((prev) => (prev === 'light' ? 'dark' : 'light')),
  }
}
