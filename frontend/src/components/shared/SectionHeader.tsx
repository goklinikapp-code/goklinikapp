import type { ReactNode } from 'react'

interface SectionHeaderProps {
  title: string
  subtitle?: string
  actions?: ReactNode
}

export function SectionHeader({ title, subtitle, actions }: SectionHeaderProps) {
  return (
    <div className="mb-5 flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 className="display-title">{title}</h1>
        {subtitle ? <p className="body-copy mt-1">{subtitle}</p> : null}
      </div>
      {actions ? <div className="flex items-center gap-2">{actions}</div> : null}
    </div>
  )
}
