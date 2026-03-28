import { useMemo, useState } from 'react'

import { initials } from '@/utils/format'
import { cn } from '@/utils/cn'

interface AvatarProps {
  name: string
  src?: string | null
  className?: string
}

export function Avatar({ name, src, className }: AvatarProps) {
  const [imageFailed, setImageFailed] = useState(false)

  const resolvedSrc = useMemo(() => {
    const raw = (src || '').trim()
    if (!raw) return ''

    try {
      const parsed = new URL(raw)
      const isLoopback = parsed.hostname === '127.0.0.1' || parsed.hostname === 'localhost' || parsed.hostname === '::1'

      if (!isLoopback) {
        return raw
      }

      const apiBase = (import.meta.env.VITE_API_URL || '').trim()
      if (!apiBase) {
        return raw
      }

      const apiUrl = new URL(apiBase)
      return `${apiUrl.origin}${parsed.pathname}${parsed.search}${parsed.hash}`
    } catch {
      return raw
    }
  }, [src])

  if (resolvedSrc && !imageFailed) {
    return (
      <img
        src={resolvedSrc}
        alt={name}
        className={cn('h-10 w-10 rounded-full object-cover', className)}
        loading="lazy"
        onError={() => setImageFailed(true)}
      />
    )
  }

  return (
    <div
      className={cn(
        'flex h-10 w-10 items-center justify-center rounded-full bg-primary/10 text-xs font-semibold text-primary',
        className,
      )}
    >
      {initials(name)}
    </div>
  )
}
