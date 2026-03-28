import type { PropsWithChildren } from 'react'

export function AuthLayout({ children }: PropsWithChildren) {
  return (
    <div className="min-h-screen bg-gradient-to-br from-mist via-white to-tealIce p-4">
      <div className="mx-auto flex min-h-screen w-full max-w-6xl items-center justify-center">
        {children}
      </div>
    </div>
  )
}
