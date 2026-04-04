import { useMutation } from '@tanstack/react-query'
import { Eye, EyeOff, HelpCircle, LockKeyhole, ShieldCheck } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useNavigate } from 'react-router-dom'
import { z } from 'zod'
import { zodResolver } from '@hookform/resolvers/zod'
import toast from 'react-hot-toast'

import { login } from '@/api/auth'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { useAuthStore } from '@/stores/authStore'

const loginSchema = z.object({
  identifier: z.string().min(3, 'Informe e-mail ou número fiscal'),
  password: z.string().min(6, 'Senha mínima de 6 caracteres'),
})

type LoginForm = z.infer<typeof loginSchema>

export function LoginPage() {
  const [showPassword, setShowPassword] = useState(false)
  const navigate = useNavigate()
  const { login: loginStore } = useAuthStore()

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginForm>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      identifier: '',
      password: '',
    },
  })

  const loginMutation = useMutation({
    mutationFn: login,
    onSuccess: (data) => {
      loginStore(data)
      toast.success('Login realizado com sucesso')
      navigate('/dashboard', { replace: true })
    },
    onError: () => {
      toast.error('Não foi possível fazer login')
    },
  })

  const onSubmit = (values: LoginForm) => {
    loginMutation.mutate(values)
  }

  return (
    <div className="w-full max-w-md">
      <div className="mb-6 text-center">
        <img
          src="/assets/logo_go_klink.png"
          alt="GoKlinik"
          className="mx-auto h-14 w-auto"
          onError={(event) => {
            event.currentTarget.src = '/assets/logo_go_klink.png'
          }}
        />
      </div>

      <div className="rounded-card border border-slate-200 bg-white p-6 shadow-card">
        <h1 className="text-center text-2xl font-semibold text-night">Acessar Painel</h1>
        <p className="body-copy mt-1 text-center">Entre com suas credenciais de administrador.</p>

        <form className="mt-6 space-y-4" onSubmit={handleSubmit(onSubmit)}>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Email ou Número Fiscal</label>
            <Input {...register('identifier')} placeholder="admin@goklinik.com" />
            {errors.identifier ? <p className="caption mt-1 text-danger">{errors.identifier.message}</p> : null}
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Senha</label>
            <div className="relative">
              <Input
                {...register('password')}
                type={showPassword ? 'text' : 'password'}
                placeholder="Digite sua senha"
                className="pr-10"
              />
              <button
                type="button"
                className="absolute right-2 top-2 rounded-md p-1 text-slate-500 hover:bg-slate-100"
                onClick={() => setShowPassword((prev) => !prev)}
              >
                {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>
            {errors.password ? <p className="caption mt-1 text-danger">{errors.password.message}</p> : null}
          </div>

          <div className="text-right">
            <button type="button" className="text-xs font-medium text-primary hover:underline">
              Esqueci minha senha
            </button>
          </div>

          <Button type="submit" fullWidth disabled={loginMutation.isPending}>
            {loginMutation.isPending ? 'Entrando...' : 'Entrar'}
          </Button>
        </form>

        <p className="mt-4 text-center text-xs text-slate-500">
          Ainda não tem conta?{' '}
          <button
            type="button"
            className="font-semibold text-primary hover:underline"
            onClick={() => navigate('/signup')}
          >
            Cadastre-se
          </button>
        </p>

        <div className="mt-6 flex items-center justify-center gap-4 border-t border-slate-100 pt-4 text-xs text-slate-500">
          <span className="inline-flex items-center gap-1"><HelpCircle className="h-3.5 w-3.5" /> Suporte</span>
          <span className="inline-flex items-center gap-1"><LockKeyhole className="h-3.5 w-3.5" /> Seguro</span>
          <span className="inline-flex items-center gap-1"><ShieldCheck className="h-3.5 w-3.5" /> Protegido</span>
        </div>
      </div>
    </div>
  )
}
