type BaseUrlResolverOptions = {
  publicAppUrl?: string | null
  hostname?: string | null
  origin?: string | null
}

const normalizeBaseUrl = (value: string): string => value.replace(/\/+$/, '')

export function resolveBaseUrl(options: BaseUrlResolverOptions = {}): string {
  const publicAppUrl = (options.publicAppUrl || '').trim()
  if (publicAppUrl) {
    return normalizeBaseUrl(publicAppUrl)
  }

  const hostname = (options.hostname || '').trim().toLowerCase()
  if (hostname === 'localhost') {
    return 'http://localhost:5173'
  }

  const origin = (options.origin || '').trim()
  if (origin) {
    return normalizeBaseUrl(origin)
  }

  return 'http://localhost:5173'
}

export function getBaseUrl(): string {
  if (typeof window === 'undefined') {
    return resolveBaseUrl({
      publicAppUrl: import.meta.env.VITE_PUBLIC_APP_URL,
      hostname: 'localhost',
    })
  }

  return resolveBaseUrl({
    publicAppUrl: import.meta.env.VITE_PUBLIC_APP_URL,
    hostname: window.location.hostname,
    origin: window.location.origin,
  })
}

export function getSellerSignupLink(refCode?: string | null): string {
  const baseUrl = getBaseUrl()
  const normalizedCode = (refCode || '').trim()
  if (!normalizedCode) {
    return `${baseUrl}/signup`
  }
  return `${baseUrl}/signup?ref_code=${encodeURIComponent(normalizedCode)}`
}
