import { apiClient } from '@/lib/axios'

function resolveApiBasePath() {
  const baseUrl = (apiClient.defaults.baseURL || '').trim()
  if (!baseUrl) return ''

  try {
    const parsed = new URL(baseUrl, 'http://localhost')
    return parsed.pathname.replace(/\/$/, '')
  } catch {
    return ''
  }
}

const API_BASE_PATH = resolveApiBasePath()

export function normalizeNextPagePath(next: string): string {
  const value = (next || '').trim()
  if (!value) return ''

  try {
    const parsed = new URL(value, 'http://localhost')
    const pathname = parsed.pathname || ''

    if (API_BASE_PATH && pathname === API_BASE_PATH) {
      return parsed.search || '/'
    }

    if (API_BASE_PATH && pathname.startsWith(`${API_BASE_PATH}/`)) {
      return `${pathname.slice(API_BASE_PATH.length)}${parsed.search}`
    }

    return `${pathname}${parsed.search}`
  } catch {
    return value
  }
}
