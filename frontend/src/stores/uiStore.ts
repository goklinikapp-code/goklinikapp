import { create } from 'zustand'

export type PeriodFilter = 'today' | 'week' | 'month' | 'last_30_days'

interface UIState {
  period: PeriodFilter
  setPeriod: (period: PeriodFilter) => void
}

export const useUIStore = create<UIState>((set) => ({
  period: 'today',
  setPeriod: (period) => set({ period }),
}))
