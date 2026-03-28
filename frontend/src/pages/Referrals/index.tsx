import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  CheckCircle2,
  Clock3,
  DollarSign,
  Download,
  History,
  Users,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import toast from 'react-hot-toast'

import {
  type ReferralListItem,
  type ReferralStatus,
  getReferralsList,
  getReferralsSummary,
  markConverted,
  markPaid,
} from '@/api/referrals'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Modal } from '@/components/ui/Modal'
import { t as translate, type TranslationKey } from '@/i18n/system'
import { formatCurrency, formatDate } from '@/utils/format'
import { usePreferencesStore } from '@/stores/preferencesStore'

type StatusFilter = 'all' | ReferralStatus
type CommissionRuleMode = 'fixed' | 'percentage'

interface CommissionRule {
  mode: CommissionRuleMode
  value: number
}

const COMMISSION_RULE_STORAGE_KEY = 'goklinik-referrals-commission-rule'

function loadCommissionRule(): CommissionRule {
  if (typeof window === 'undefined') {
    return { mode: 'fixed', value: 100 }
  }

  try {
    const raw = window.localStorage.getItem(COMMISSION_RULE_STORAGE_KEY)
    if (!raw) {
      return { mode: 'fixed', value: 100 }
    }
    const parsed = JSON.parse(raw) as Partial<CommissionRule>
    return {
      mode: parsed.mode === 'percentage' ? 'percentage' : 'fixed',
      value: Number(parsed.value || 0),
    }
  } catch {
    return { mode: 'fixed', value: 100 }
  }
}

function getStatusBadge(
  status: ReferralStatus,
  t: (key: TranslationKey) => string,
): { label: string; className: string } {
  if (status === 'paid') {
    return {
      label: t('referrals_status_paid'),
      className: 'bg-primary/10 text-primary',
    }
  }
  if (status === 'converted') {
    return {
      label: t('referrals_status_converted'),
      className: 'bg-secondary/15 text-secondary',
    }
  }
  return {
    label: t('referrals_status_pending'),
    className: 'bg-accent/15 text-accent',
  }
}

export default function ReferralsPage() {
  const language = usePreferencesStore((state) => state.language)
  const currency = usePreferencesStore((state) => state.currency)
  const t = (key: TranslationKey) => translate(language, key)
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all')
  const [isPayModalOpen, setIsPayModalOpen] = useState(false)
  const [selectedReferral, setSelectedReferral] = useState<ReferralListItem | null>(null)
  const [commissionInput, setCommissionInput] = useState('')
  const [commissionRule, setCommissionRule] = useState<CommissionRule>(loadCommissionRule)
  const queryClient = useQueryClient()

  const { data: summary, isLoading: summaryLoading } = useQuery({
    queryKey: ['referrals-summary'],
    queryFn: getReferralsSummary,
  })

  const { data: referrals = [], isLoading: referralsLoading } = useQuery({
    queryKey: ['referrals-list', statusFilter],
    queryFn: () => getReferralsList(statusFilter === 'all' ? undefined : statusFilter),
  })

  const markConvertedMutation = useMutation({
    mutationFn: (id: string) => markConverted(id),
    onSuccess: () => {
      toast.success(t('referrals_toast_mark_converted_success'))
      void queryClient.invalidateQueries({ queryKey: ['referrals-summary'] })
      void queryClient.invalidateQueries({ queryKey: ['referrals-list'] })
    },
    onError: () => {
      toast.error(t('referrals_toast_mark_converted_error'))
    },
  })

  const markPaidMutation = useMutation({
    mutationFn: ({ id, commissionValue }: { id: string; commissionValue: number }) =>
      markPaid(id, commissionValue),
    onSuccess: () => {
      toast.success(t('referrals_toast_mark_paid_success'))
      setIsPayModalOpen(false)
      setSelectedReferral(null)
      setCommissionInput('')
      void queryClient.invalidateQueries({ queryKey: ['referrals-summary'] })
      void queryClient.invalidateQueries({ queryKey: ['referrals-list'] })
    },
    onError: () => {
      toast.error(t('referrals_toast_mark_paid_error'))
    },
  })

  const totalConvertedPendingPayment = useMemo(
    () => summary?.total_commission_pending || 0,
    [summary],
  )
  const statusFilterOptions: Array<{ label: string; value: StatusFilter }> = useMemo(
    () => [
      { label: t('referrals_filter_all'), value: 'all' },
      { label: t('referrals_filter_pending'), value: 'pending' },
      { label: t('referrals_filter_converted'), value: 'converted' },
      { label: t('referrals_filter_paid'), value: 'paid' },
    ],
    [t],
  )

  const handleExportCsv = () => {
    const header = [
      t('referrals_table_referrer'),
      t('referrals_table_referrer_phone'),
      t('referrals_table_referred'),
      t('referrals_table_referred_phone'),
      t('referrals_table_date'),
      t('referrals_table_status'),
      t('referrals_table_commission'),
    ]
    const rows = referrals.map((item) => [
      item.referrer.name,
      item.referrer.phone,
      item.referred.name,
      item.referred.phone,
      formatDate(item.created_at),
      item.status,
      item.commission_value,
    ])

    const csv = [header, ...rows]
      .map((line) => line.map((column) => `"${String(column).replace(/"/g, '""')}"`).join(','))
      .join('\n')

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `referrals-${new Date().toISOString().slice(0, 10)}.csv`
    link.click()
    URL.revokeObjectURL(url)
    toast.success(t('referrals_toast_csv_success'))
  }

  const openPayModal = (referral: ReferralListItem) => {
    setSelectedReferral(referral)
    const configuredDefault =
      referral.commission_value > 0
        ? referral.commission_value
        : commissionRule.mode === 'fixed'
          ? commissionRule.value
          : 0
    setCommissionInput(String(configuredDefault))
    setIsPayModalOpen(true)
  }

  const handleConfirmPayment = () => {
    if (!selectedReferral) return

    const parsed = Number(commissionInput.replace(',', '.'))
    if (!Number.isFinite(parsed) || parsed < 0) {
      toast.error(t('referrals_toast_invalid_value'))
      return
    }

    markPaidMutation.mutate({
      id: selectedReferral.id,
      commissionValue: parsed,
    })
  }

  const handleSaveCommissionRule = () => {
    const normalized = {
      ...commissionRule,
      value: Number(commissionRule.value || 0),
    }
    window.localStorage.setItem(COMMISSION_RULE_STORAGE_KEY, JSON.stringify(normalized))
    toast.success(t('referrals_toast_save_rule_success'))
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title={t('referrals_title')}
        subtitle={t('referrals_subtitle')}
        actions={
          <Button variant="secondary" onClick={handleExportCsv}>
            <Download className="h-4 w-4" />
            {t('referrals_export_csv')}
          </Button>
        }
      />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <Card>
          <div className="flex items-center justify-between">
            <p className="overline">{t('referrals_total')}</p>
            <Users className="h-4 w-4 text-primary" />
          </div>
          <p className="mt-3 text-3xl font-bold text-night">
            {summaryLoading ? '...' : (summary?.total_referrals || 0)}
          </p>
        </Card>

        <Card>
          <div className="flex items-center justify-between">
            <p className="overline">{t('referrals_converted')}</p>
            <CheckCircle2 className="h-4 w-4 text-secondary" />
          </div>
          <p className="mt-3 text-3xl font-bold text-night">
            {summaryLoading ? '...' : (summary?.total_converted || 0)}
          </p>
        </Card>

        <Card>
          <div className="flex items-center justify-between">
            <p className="overline">{t('referrals_commission_pending')}</p>
            <Clock3 className="h-4 w-4 text-accent" />
          </div>
          <p className="mt-3 text-3xl font-bold text-night">{formatCurrency(totalConvertedPendingPayment)}</p>
        </Card>

        <Card>
          <div className="flex items-center justify-between">
            <p className="overline">{t('referrals_commission_paid')}</p>
            <DollarSign className="h-4 w-4 text-primary" />
          </div>
          <p className="mt-3 text-3xl font-bold text-night">
            {formatCurrency(summary?.total_commission_paid || 0)}
          </p>
        </Card>
      </div>

      <Card>
        <div className="flex flex-wrap gap-2">
          {statusFilterOptions.map((item) => (
            <button
              key={item.value}
              type="button"
              onClick={() => setStatusFilter(item.value)}
              className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
                statusFilter === item.value
                  ? 'bg-primary text-white'
                  : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>
      </Card>

      <Card padded={false}>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-4 py-3 text-left overline">{t('referrals_table_referrer')}</th>
                <th className="px-4 py-3 text-left overline">{t('referrals_table_referred')}</th>
                <th className="px-4 py-3 text-left overline">{t('referrals_table_date')}</th>
                <th className="px-4 py-3 text-left overline">{t('referrals_table_status')}</th>
                <th className="px-4 py-3 text-left overline">{t('referrals_table_commission')}</th>
                <th className="px-4 py-3 text-left overline">{t('referrals_table_actions')}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {referralsLoading ? (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-sm text-slate-500">
                    {t('referrals_loading')}
                  </td>
                </tr>
              ) : referrals.length ? (
                referrals.map((item) => {
                  const statusBadge = getStatusBadge(item.status, t)
                  return (
                    <tr key={item.id}>
                      <td className="px-4 py-3 text-sm text-slate-700">
                        <p className="font-semibold text-night">{item.referrer.name}</p>
                        <p className="caption">{item.referrer.phone || '-'}</p>
                      </td>
                      <td className="px-4 py-3 text-sm text-slate-700">
                        <p className="font-semibold text-night">{item.referred.name}</p>
                        <p className="caption">{item.referred.phone || '-'}</p>
                      </td>
                      <td className="px-4 py-3 text-sm text-slate-700">{formatDate(item.created_at)}</td>
                      <td className="px-4 py-3">
                        <Badge className={statusBadge.className}>{statusBadge.label}</Badge>
                      </td>
                      <td className="px-4 py-3 text-sm font-semibold text-night">
                        {formatCurrency(item.commission_value)}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex flex-wrap gap-2">
                          {item.status === 'pending' ? (
                            <Button
                              size="sm"
                              variant="secondary"
                              disabled={markConvertedMutation.isPending}
                              onClick={() => markConvertedMutation.mutate(item.id)}
                            >
                              {t('referrals_mark_converted')}
                            </Button>
                          ) : null}
                          {item.status === 'converted' ? (
                            <Button size="sm" onClick={() => openPayModal(item)}>
                              {t('referrals_pay_commission')}
                            </Button>
                          ) : null}
                          <Button
                            size="sm"
                            variant="secondary"
                            onClick={() =>
                              toast(
                                t('referrals_history_toast')
                                  .replace('{date}', formatDate(item.created_at))
                                  .replace('{status}', statusBadge.label),
                              )
                            }
                          >
                            <History className="h-4 w-4" />
                            {t('referrals_history')}
                          </Button>
                        </div>
                      </td>
                    </tr>
                  )
                })
              ) : (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-sm text-slate-500">
                    {t('referrals_empty')}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </Card>

      <Card>
        <h2 className="section-heading mb-3">{t('referrals_rules_title')}</h2>
        <div className="space-y-3">
          <label className="flex items-center gap-2 text-sm text-slate-700">
            <input
              type="radio"
              checked={commissionRule.mode === 'fixed'}
              onChange={() => setCommissionRule((prev) => ({ ...prev, mode: 'fixed' }))}
            />
            <span>{t('referrals_rule_fixed')}</span>
          </label>
          {commissionRule.mode === 'fixed' ? (
            <Input
              type="number"
              min={0}
              step="0.01"
              value={commissionRule.value}
              onChange={(event) =>
                setCommissionRule((prev) => ({
                  ...prev,
                  value: Number(event.target.value || 0),
                }))
              }
              placeholder={t('referrals_rule_value_placeholder').replace('{currency}', currency)}
            />
          ) : null}

          <label className="flex items-center gap-2 text-sm text-slate-700">
            <input
              type="radio"
              checked={commissionRule.mode === 'percentage'}
              onChange={() => setCommissionRule((prev) => ({ ...prev, mode: 'percentage' }))}
            />
            <span>{t('referrals_rule_percentage')}</span>
          </label>
          {commissionRule.mode === 'percentage' ? (
            <Input
              type="number"
              min={0}
              max={100}
              step="0.1"
              value={commissionRule.value}
              onChange={(event) =>
                setCommissionRule((prev) => ({
                  ...prev,
                  value: Number(event.target.value || 0),
                }))
              }
              placeholder={t('referrals_rule_percentage_placeholder')}
            />
          ) : null}
        </div>
        <Button className="mt-4" onClick={handleSaveCommissionRule}>
          {t('referrals_save_rule')}
        </Button>
      </Card>

      <Modal
        isOpen={isPayModalOpen}
        onClose={() => setIsPayModalOpen(false)}
        title={t('referrals_pay_modal_title')}
      >
        <div className="space-y-3">
          <p className="text-sm text-slate-600">
            {t('referrals_pay_modal_subtitle').replace('{patient}', selectedReferral?.referred.name || '-')}
          </p>
          <Input
            type="number"
            min={0}
            step="0.01"
            value={commissionInput}
            onChange={(event) => setCommissionInput(event.target.value)}
            placeholder={t('referrals_pay_modal_value_placeholder').replace('{currency}', currency)}
          />
          <div className="flex justify-end gap-2">
            <Button variant="secondary" onClick={() => setIsPayModalOpen(false)}>
              {t('referrals_cancel')}
            </Button>
            <Button onClick={handleConfirmPayment} disabled={markPaidMutation.isPending}>
              {markPaidMutation.isPending
                ? t('referrals_confirming')
                : t('referrals_confirm_payment')}
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  )
}
