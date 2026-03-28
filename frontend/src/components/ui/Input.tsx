import { forwardRef } from 'react'
import type { InputHTMLAttributes } from 'react'

import { cn } from '@/utils/cn'

type InputProps = InputHTMLAttributes<HTMLInputElement>

export const Input = forwardRef<HTMLInputElement, InputProps>(({ className, ...props }, ref) => {
  return (
    <input
      ref={ref}
      className={cn(
        'h-10 w-full rounded-lg border border-slate-200 bg-white px-3 text-sm text-night outline-none transition placeholder:text-slate-400 focus:border-primary focus:ring-2 focus:ring-primary/20',
        className,
      )}
      {...props}
    />
  )
})

Input.displayName = 'Input'
