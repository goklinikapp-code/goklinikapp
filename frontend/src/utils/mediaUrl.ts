const mediaFieldNames = new Set(['avatar', 'interlocutor_avatar'])

const resolveApiOrigin = () => {
  const apiBase = (import.meta.env.VITE_API_URL || '').trim()
  if (!apiBase) return ''
  try {
    return new URL(apiBase).origin
  } catch {
    return ''
  }
}

const isLoopbackHost = (host: string) =>
  host === '127.0.0.1' || host === 'localhost' || host === '::1'

export const resolveMediaUrl = (value?: string | null): string => {
  const raw = (value || '').trim()
  if (!raw) return ''
  if (raw.startsWith('/assets/')) return raw

  const apiOrigin = resolveApiOrigin()

  try {
    const parsed = new URL(raw)
    if (!apiOrigin || !isLoopbackHost(parsed.hostname)) {
      return raw
    }
    const apiBase = new URL(apiOrigin)
    return `${apiBase.origin}${parsed.pathname}${parsed.search}${parsed.hash}`
  } catch {
    if (!apiOrigin) {
      return raw
    }
    if (raw.startsWith('/')) {
      return raw.startsWith('/assets/') ? raw : `${apiOrigin}${raw}`
    }
    return `${apiOrigin}/${raw}`
  }
}

const isMediaKey = (key: string) => key.endsWith('_url') || mediaFieldNames.has(key)

export const normalizeMediaUrlsDeep = <T>(input: T): T => {
  if (Array.isArray(input)) {
    return input.map((item) => normalizeMediaUrlsDeep(item)) as T
  }

  if (input && typeof input === 'object') {
    const source = input as Record<string, unknown>
    const messageType = String(source.message_type || '').toLowerCase()
    const output: Record<string, unknown> = {}
    for (const [key, value] of Object.entries(source)) {
      if (typeof value === 'string' && isMediaKey(key)) {
        output[key] = resolveMediaUrl(value)
        continue
      }
      if (typeof value === 'string' && key === 'content' && messageType === 'image') {
        output[key] = resolveMediaUrl(value)
        continue
      }
      output[key] = normalizeMediaUrlsDeep(value)
    }
    return output as T
  }

  return input
}
