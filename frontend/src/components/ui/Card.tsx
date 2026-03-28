import type { HTMLAttributes } from 'react'

import { cn } from '@/utils/cn'

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  padded?: boolean
}

export function Card({ className, padded = true, ...props }: CardProps) {
  return (
    <div
      className={cn(
        'rounded-card border border-slate-200 bg-white shadow-card dark:border-slate-700 dark:bg-slate-900',
        padded && 'p-5',
        className,
      )}
      {...props}
    />
  )
}
