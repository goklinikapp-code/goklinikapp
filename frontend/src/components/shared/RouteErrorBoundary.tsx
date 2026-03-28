import { Component, type ErrorInfo, type PropsWithChildren, type ReactNode } from 'react'

import { Button } from '@/components/ui/Button'

interface RouteErrorBoundaryProps {
  title?: string
}

interface RouteErrorBoundaryState {
  hasError: boolean
  message: string
}

export class RouteErrorBoundary extends Component<
  PropsWithChildren<RouteErrorBoundaryProps>,
  RouteErrorBoundaryState
> {
  state: RouteErrorBoundaryState = {
    hasError: false,
    message: '',
  }

  static getDerivedStateFromError(error: Error): RouteErrorBoundaryState {
    return {
      hasError: true,
      message: error?.message || 'Erro inesperado na página.',
    }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    // Keep in console for quick debugging in dev.
    // eslint-disable-next-line no-console
    console.error('RouteErrorBoundary', error, errorInfo)
  }

  private handleReload = () => {
    this.setState({ hasError: false, message: '' })
    window.location.reload()
  }

  render(): ReactNode {
    if (!this.state.hasError) {
      return this.props.children
    }

    return (
      <div className="space-y-3 rounded-lg border border-slate-200 bg-white p-4">
        <p className="text-sm font-semibold text-night">
          {this.props.title || 'Não foi possível abrir esta página.'}
        </p>
        <p className="caption">{this.state.message}</p>
        <Button onClick={this.handleReload}>Recarregar página</Button>
      </div>
    )
  }
}
