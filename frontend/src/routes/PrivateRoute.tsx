import type { PropsWithChildren } from 'react'
import { Navigate, useLocation } from 'react-router-dom'

import { useAuthStore } from '@/stores/authStore'

export function PrivateRoute({ children }: PropsWithChildren) {
  const location = useLocation()
  const { token, isAuthenticated } = useAuthStore()

  if (!token && !isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location }} />
  }

  return <>{children}</>
}
