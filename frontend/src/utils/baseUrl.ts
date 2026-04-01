type BaseUrlResolverOptions = {
  publicAppUrl?: string | null
  hostname?: string | null
  origin?: string | null
}

type SellerInviteUrlResolverOptions = {
  baseUrl: string
  invitePath?: string | null
  refParam?: string | null
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

function resolveSellerInviteUrlConfig({
  baseUrl,
  invitePath,
  refParam,
}: SellerInviteUrlResolverOptions): { path: string; queryParam: string } {
  const normalizedInvitePath = (invitePath || '').trim()
  const normalizedRefParam = (refParam || '').trim()
  if (normalizedInvitePath && normalizedRefParam) {
    return {
      path: normalizedInvitePath.startsWith('/') ? normalizedInvitePath : `/${normalizedInvitePath}`,
      queryParam: normalizedRefParam,
    }
  }

  try {
    const host = new URL(baseUrl).hostname.toLowerCase()
    if (host === 'launch.goklinik.com' || host === 'www.launch.goklinik.com') {
      return { path: '/', queryParam: 'r' }
    }
  } catch {
    // Fall back to default when base URL is not parseable.
  }

  return { path: '/signup', queryParam: 'ref_code' }
}

export function getSellerSignupLink(refCode?: string | null): string {
  const baseUrl = getBaseUrl()
  const { path, queryParam } = resolveSellerInviteUrlConfig({
    baseUrl,
    invitePath: import.meta.env.VITE_SELLER_INVITE_PATH,
    refParam: import.meta.env.VITE_SELLER_REF_PARAM,
  })

  let url: URL
  try {
    url = new URL(baseUrl)
  } catch {
    return baseUrl
  }

  url.pathname = path
  url.search = ''

  const normalizedCode = (refCode || '').trim()
  if (!normalizedCode) {
    return url.toString()
  }
  url.searchParams.set(queryParam, normalizedCode)
  return url.toString()
}
