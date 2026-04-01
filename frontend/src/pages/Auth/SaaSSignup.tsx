import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { ArrowLeft, Building2, MailCheck } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { z } from 'zod'

import { createLead } from '@/api/leads'
import { getSaaSSellerByCode, requestSaaSSignupCode, verifySaaSSignupCode } from '@/api/saas'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { useAuthStore } from '@/stores/authStore'

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

const signupSchema = z
  .object({
    clinic_name: z.string().min(3, 'Informe o nome da clínica'),
    full_name: z.string().min(3, 'Informe seu nome completo'),
    email: z.string().email('Informe um e-mail válido'),
    phone: z.string().min(3, 'Informe seu telefone'),
    password: z.string().min(8, 'A senha precisa ter no mínimo 8 caracteres'),
    confirm_password: z.string().min(8, 'Confirme sua senha'),
    seller_code: z.string().optional(),
  })
  .refine((values) => values.password === values.confirm_password, {
    message: 'As senhas não conferem',
    path: ['confirm_password'],
  })

const codeSchema = z.object({
  code: z
    .string()
    .min(6, 'Digite o código de 6 dígitos')
    .max(6, 'Digite o código de 6 dígitos'),
})

type SignupFormValues = z.infer<typeof signupSchema>
type CodeFormValues = z.infer<typeof codeSchema>

export function SaaSSignupPage() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const language = usePreferencesStore((state) => state.language)
  const loginStore = useAuthStore((state) => state.login)
  const [step, setStep] = useState<'form' | 'code'>('form')
  const [submittedEmail, setSubmittedEmail] = useState('')
  const [sellerName, setSellerName] = useState<string | null>(null)

  const sellerCodeFromQuery = useMemo(
    () => (searchParams.get('ref_code') || searchParams.get('seller') || '').trim().toUpperCase(),
    [searchParams],
  )

  const {
    register,
    handleSubmit,
    formState: { errors: signupErrors },
    setValue,
    watch,
  } = useForm<SignupFormValues>({
    resolver: zodResolver(signupSchema),
    defaultValues: {
      clinic_name: '',
      full_name: '',
      email: '',
      phone: '',
      password: '',
      confirm_password: '',
      seller_code: sellerCodeFromQuery,
    },
  })

  const {
    register: registerCode,
    handleSubmit: handleSubmitCode,
    formState: { errors: codeErrors },
  } = useForm<CodeFormValues>({
    resolver: zodResolver(codeSchema),
    defaultValues: { code: '' },
  })

  useEffect(() => {
    if (!sellerCodeFromQuery) return
    setValue('seller_code', sellerCodeFromQuery)
    void getSaaSSellerByCode(sellerCodeFromQuery)
      .then((data) => setSellerName(data.full_name))
      .catch(() => {
        setSellerName(null)
      })
  }, [sellerCodeFromQuery, setValue])

  const requestCodeMutation = useMutation({
    mutationFn: requestSaaSSignupCode,
    onSuccess: (data) => {
      setSubmittedEmail(data.email)
      setStep('code')
      toast.success('Código enviado para seu e-mail')
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, 'Não foi possível enviar o código'))
    },
  })

  const verifyCodeMutation = useMutation({
    mutationFn: verifySaaSSignupCode,
    onSuccess: (data) => {
      loginStore(data)
      toast.success('Cadastro concluído com sucesso')
      navigate('/dashboard', { replace: true })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, 'Código inválido ou expirado'))
    },
  })

  const onSubmitSignup = async (values: SignupFormValues) => {
    const normalizedSellerCode = values.seller_code?.trim().toUpperCase() || undefined
    const leadPayload = {
      name: values.full_name.trim(),
      email: values.email.trim(),
      phone: values.phone.trim(),
      ref_code: normalizedSellerCode,
    }

    try {
      await createLead(leadPayload)
    } catch {
      // Lead capture should not block signup flow.
    }

    requestCodeMutation.mutate({
      clinic_name: values.clinic_name.trim(),
      full_name: values.full_name.trim(),
      email: values.email.trim(),
      phone: values.phone.trim(),
      password: values.password,
      seller_code: normalizedSellerCode,
      language,
    })
  }

  const onSubmitCode = (values: CodeFormValues) => {
    verifyCodeMutation.mutate({
      email: submittedEmail || watch('email'),
      code: values.code.trim(),
    })
  }

  return (
    <div className="w-full max-w-xl">
      <div className="rounded-card border border-slate-200 bg-white p-6 shadow-card">
        {step === 'form' ? (
          <>
            <div className="mb-6 flex items-start justify-between gap-4">
              <div>
                <h1 className="text-2xl font-semibold text-night">Cadastro de Clínica</h1>
                <p className="body-copy mt-1">
                  Crie sua conta para administrar sua clínica no GoKlinik.
                </p>
              </div>
              <Building2 className="mt-1 h-6 w-6 text-primary" />
            </div>

            <form className="grid gap-4 md:grid-cols-2" onSubmit={handleSubmit(onSubmitSignup)}>
              <div className="md:col-span-2">
                <label className="mb-1 block text-xs font-medium text-slate-600">Nome da clínica</label>
                <Input {...register('clinic_name')} placeholder="Clínica Exemplo" />
                {signupErrors.clinic_name ? (
                  <p className="caption mt-1 text-danger">{signupErrors.clinic_name.message}</p>
                ) : null}
              </div>

              <div className="md:col-span-2">
                <label className="mb-1 block text-xs font-medium text-slate-600">Nome completo</label>
                <Input {...register('full_name')} placeholder="Seu nome completo" />
                {signupErrors.full_name ? (
                  <p className="caption mt-1 text-danger">{signupErrors.full_name.message}</p>
                ) : null}
              </div>

              <div className="md:col-span-2">
                <label className="mb-1 block text-xs font-medium text-slate-600">E-mail</label>
                <Input {...register('email')} type="email" placeholder="nome@clinica.com" />
                {signupErrors.email ? <p className="caption mt-1 text-danger">{signupErrors.email.message}</p> : null}
              </div>

              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Telefone</label>
                <Input {...register('phone')} placeholder="+55 11 99999-9999" />
                {signupErrors.phone ? <p className="caption mt-1 text-danger">{signupErrors.phone.message}</p> : null}
              </div>

              <div className="md:col-span-2">
                <label className="mb-1 block text-xs font-medium text-slate-600">Senha</label>
                <Input {...register('password')} type="password" placeholder="••••••••" />
                {signupErrors.password ? (
                  <p className="caption mt-1 text-danger">{signupErrors.password.message}</p>
                ) : null}
              </div>

              <div className="md:col-span-2">
                <label className="mb-1 block text-xs font-medium text-slate-600">Confirmar senha</label>
                <Input {...register('confirm_password')} type="password" placeholder="••••••••" />
                {signupErrors.confirm_password ? (
                  <p className="caption mt-1 text-danger">{signupErrors.confirm_password.message}</p>
                ) : null}
              </div>

              <div className="md:col-span-2">
                <label className="mb-1 block text-xs font-medium text-slate-600">Código do vendedor (opcional)</label>
                <Input {...register('seller_code')} placeholder="ABC123XYZ9" />
                {sellerName ? (
                  <p className="caption mt-1 text-secondary">Convite de: {sellerName}</p>
                ) : sellerCodeFromQuery ? (
                  <p className="caption mt-1 text-slate-500">Código aplicado pelo link de convite.</p>
                ) : null}
              </div>

              <div className="mt-2 flex items-center justify-between md:col-span-2">
                <Link to="/login" className="inline-flex items-center gap-1 text-sm font-medium text-primary hover:underline">
                  <ArrowLeft className="h-4 w-4" />
                  Voltar para login
                </Link>
                <Button type="submit" disabled={requestCodeMutation.isPending}>
                  {requestCodeMutation.isPending ? 'Enviando código...' : 'Enviar código'}
                </Button>
              </div>
            </form>
          </>
        ) : (
          <>
            <div className="mb-6 flex items-start justify-between gap-4">
              <div>
                <h1 className="text-2xl font-semibold text-night">Confirme seu e-mail</h1>
                <p className="body-copy mt-1">
                  Enviamos um código de 6 dígitos para <strong>{submittedEmail}</strong>.
                </p>
              </div>
              <MailCheck className="mt-1 h-6 w-6 text-primary" />
            </div>

            <form className="space-y-4" onSubmit={handleSubmitCode(onSubmitCode)}>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Código de verificação</label>
                <Input {...registerCode('code')} placeholder="000000" maxLength={6} />
                {codeErrors.code ? <p className="caption mt-1 text-danger">{codeErrors.code.message}</p> : null}
              </div>

              <div className="flex items-center justify-between">
                <Button type="button" variant="secondary" onClick={() => setStep('form')}>
                  Voltar
                </Button>
                <Button type="submit" disabled={verifyCodeMutation.isPending}>
                  {verifyCodeMutation.isPending ? 'Confirmando...' : 'Confirmar e entrar'}
                </Button>
              </div>
            </form>
          </>
        )}
      </div>
    </div>
  )
}
