import type { HTMLAttributes } from 'react'

import { cn } from '@/utils/cn'
import { statusBadgeClass, statusLabel } from '@/utils/status'

interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  status?: string
}

export function Badge({ className, children, status, ...props }: BadgeProps) {
  const content = children || (status ? statusLabel(status) : '')

  return (
    <span
      className={cn(
        'inline-flex min-h-6 items-center rounded-full px-2.5 text-[11px] font-semibold uppercase tracking-wide',
        status ? statusBadgeClass(status) : 'bg-slate-100 text-slate-700',
        className,
      )}
      {...props}
    >
      {content}
    </span>
  )
}
