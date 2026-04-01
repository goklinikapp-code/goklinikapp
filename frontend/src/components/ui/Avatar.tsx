import { useMemo, useState } from 'react'

import { initials } from '@/utils/format'
import { cn } from '@/utils/cn'
import { resolveMediaUrl } from '@/utils/mediaUrl'

interface AvatarProps {
  name: string
  src?: string | null
  className?: string
}

export function Avatar({ name, src, className }: AvatarProps) {
  const [imageFailed, setImageFailed] = useState(false)

  const resolvedSrc = useMemo(() => {
    return resolveMediaUrl(src)
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
