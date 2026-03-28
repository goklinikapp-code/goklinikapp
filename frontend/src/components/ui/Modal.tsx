import type { PropsWithChildren } from 'react'

import { cn } from '@/utils/cn'

interface ModalProps extends PropsWithChildren {
  isOpen: boolean
  onClose: () => void
  title: string
  className?: string
}

export function Modal({ isOpen, onClose, title, className, children }: ModalProps) {
  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <button
        type="button"
        className="absolute inset-0 bg-night/40"
        aria-label="Close modal"
        onClick={onClose}
      />
      <div
        className={cn(
          'relative z-10 w-full max-w-xl overflow-y-auto rounded-card bg-white p-6 shadow-2xl',
          'max-h-[90vh]',
          className,
        )}
      >
        <div className="mb-4 flex items-center justify-between">
          <h3 className="section-heading">{title}</h3>
          <button
            type="button"
            onClick={onClose}
            className="rounded-md px-2 py-1 text-sm text-slate-500 hover:bg-slate-100"
          >
            Fechar
          </button>
        </div>
        {children}
      </div>
    </div>
  )
}
