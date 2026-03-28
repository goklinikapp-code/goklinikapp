import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQuery } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { ArrowLeft, CheckCircle2, Mail } from 'lucide-react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { z } from 'zod'

import { acceptSaaSInvite, getSaaSInvitePreview } from '@/api/saas'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { useAuthStore } from '@/stores/authStore'
import { formatDate } from '@/utils/format'

function extractErrorMessage(error: unknown, fallback: string): string {
  if (!isAxiosError(error)) return fallback
  const data = error.response?.data as Record<string, unknown> | undefined
  if (!data) return fallback
  if (typeof data.detail === 'string' && data.detail.trim()) return data.detail
  const firstValue = Object.values(data)[0]
  if (typeof firstValue === 'string' && firstValue.trim()) return firstValue
  if (Array.isArray(firstValue) && firstValue.length > 0) return String(firstValue[0])
  if (firstValue && typeof firstValue === 'object') {
    const nested = Object.values(firstValue as Record<string, unknown>)[0]
    if (typeof nested === 'string' && nested.trim()) return nested
    if (Array.isArray(nested) && nested.length > 0) return String(nested[0])
  }
  return fallback
}

const acceptSchema = z
  .object({
    password: z.string().min(8, 'A senha precisa ter no mínimo 8 caracteres'),
    confirm_password: z.string().min(8, 'Confirme sua senha'),
    phone: z.string().optional(),
  })
  .refine((values) => values.password === values.confirm_password, {
    message: 'As senhas não conferem',
    path: ['confirm_password'],
  })

type AcceptFormValues = z.infer<typeof acceptSchema>

export function SaaSClinicInviteAcceptPage() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const loginStore = useAuthStore((state) => state.login)
  const token = (searchParams.get('token') || '').trim()

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<AcceptFormValues>({
    resolver: zodResolver(acceptSchema),
    defaultValues: {
      password: '',
      confirm_password: '',
      phone: '',
    },
  })

  const inviteQuery = useQuery({
    queryKey: ['saas-invite-preview', token],
    queryFn: () => getSaaSInvitePreview(token),
    enabled: Boolean(token),
    retry: false,
  })

  const acceptMutation = useMutation({
    mutationFn: acceptSaaSInvite,
    onSuccess: (data) => {
      loginStore(data)
      toast.success('Conta criada com sucesso')
      navigate('/dashboard', { replace: true })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, 'Não foi possível concluir o cadastro'))
    },
  })

  const onSubmit = (values: AcceptFormValues) => {
    if (!token) {
      toast.error('Token de convite inválido')
      return
    }
    acceptMutation.mutate({
      token,
      password: values.password,
      phone: values.phone?.trim(),
    })
  }

  if (!token) {
    return (
      <div className="w-full max-w-xl rounded-card border border-slate-200 bg-white p-6 shadow-card">
        <h1 className="text-2xl font-semibold text-night">Convite inválido</h1>
        <p className="body-copy mt-2">O link recebido não possui token de convite válido.</p>
        <Link to="/login" className="mt-4 inline-flex items-center gap-1 text-sm font-medium text-primary hover:underline">
          <ArrowLeft className="h-4 w-4" />
          Voltar para login
        </Link>
      </div>
    )
  }

  if (inviteQuery.isLoading) {
    return <p className="body-copy">Validando convite...</p>
  }

  if (inviteQuery.isError || !inviteQuery.data) {
    return (
      <div className="w-full max-w-xl rounded-card border border-slate-200 bg-white p-6 shadow-card">
        <h1 className="text-2xl font-semibold text-night">Convite expirado</h1>
        <p className="body-copy mt-2">Este convite é inválido ou já foi utilizado.</p>
        <Link to="/login" className="mt-4 inline-flex items-center gap-1 text-sm font-medium text-primary hover:underline">
          <ArrowLeft className="h-4 w-4" />
          Voltar para login
        </Link>
      </div>
    )
  }

  const invite = inviteQuery.data

  return (
    <div className="w-full max-w-xl rounded-card border border-slate-200 bg-white p-6 shadow-card">
      <div className="mb-6 flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-night">Aceitar convite da clínica</h1>
          <p className="body-copy mt-1">
            Defina sua senha para entrar em <strong>{invite.clinic_name}</strong>.
          </p>
        </div>
        <CheckCircle2 className="mt-1 h-6 w-6 text-secondary" />
      </div>

      <div className="mb-5 rounded-lg border border-slate-200 bg-slate-50 p-4">
        <p className="mb-1 text-sm font-medium text-night">{invite.owner_full_name}</p>
        <p className="caption inline-flex items-center gap-1">
          <Mail className="h-3.5 w-3.5" />
          {invite.owner_email}
        </p>
        {invite.expires_at ? <p className="caption mt-1">Expira em: {formatDate(invite.expires_at)}</p> : null}
      </div>

      <form className="grid gap-4 md:grid-cols-2" onSubmit={handleSubmit(onSubmit)}>
        <div className="md:col-span-2">
          <label className="mb-1 block text-xs font-medium text-slate-600">Senha</label>
          <Input {...register('password')} type="password" placeholder="••••••••" />
          {errors.password ? <p className="caption mt-1 text-danger">{errors.password.message}</p> : null}
        </div>

        <div className="md:col-span-2">
          <label className="mb-1 block text-xs font-medium text-slate-600">Confirmar senha</label>
          <Input {...register('confirm_password')} type="password" placeholder="••••••••" />
          {errors.confirm_password ? (
            <p className="caption mt-1 text-danger">{errors.confirm_password.message}</p>
          ) : null}
        </div>

        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">Telefone (opcional)</label>
          <Input {...register('phone')} placeholder="+55 11 99999-9999" />
        </div>

        <div className="mt-2 flex items-center justify-between md:col-span-2">
          <Link to="/login" className="inline-flex items-center gap-1 text-sm font-medium text-primary hover:underline">
            <ArrowLeft className="h-4 w-4" />
            Voltar para login
          </Link>
          <Button type="submit" disabled={acceptMutation.isPending}>
            {acceptMutation.isPending ? 'Confirmando...' : 'Criar conta'}
          </Button>
        </div>
      </form>
    </div>
  )
}
