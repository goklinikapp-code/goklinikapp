import type { LucideIcon } from 'lucide-react'

import { Card } from '@/components/ui/Card'
import { getLocaleForLanguage } from '@/i18n/system'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { formatCurrency, formatPercent } from '@/utils/format'
import { cn } from '@/utils/cn'

interface KpiCardProps {
  title: string
  value: number
  icon: LucideIcon
  isCurrency?: boolean
  variation?: number
  caption?: string
}

export function KpiCard({ title, value, icon: Icon, isCurrency, variation, caption }: KpiCardProps) {
  const hasPositive = (variation || 0) >= 0
  const language = usePreferencesStore((state) => state.language)
  const locale = getLocaleForLanguage(language)

  return (
    <Card className="space-y-4">
      <div className="flex items-center justify-between">
        <p className="overline">{title}</p>
        <span className="rounded-lg bg-primary/10 p-2 text-primary">
          <Icon className="h-4 w-4" />
        </span>
      </div>
      <div>
        <p className="text-[28px] font-bold text-night">{isCurrency ? formatCurrency(value) : value.toLocaleString(locale)}</p>
        {typeof variation === 'number' ? (
          <span
            className={cn(
              'mt-2 inline-flex rounded-full px-2 py-1 text-[11px] font-semibold',
              hasPositive ? 'bg-secondary/15 text-secondary' : 'bg-danger/15 text-danger',
            )}
          >
            {formatPercent(variation)}
          </span>
        ) : null}
        {caption ? <p className="caption mt-2">{caption}</p> : null}
      </div>
    </Card>
  )
}
