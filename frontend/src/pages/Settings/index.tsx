import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import {
  Bell,
  Building2,
  CalendarDays,
  Camera,
  FolderOpen,
  Home,
  MapPin,
  MessageSquareText,
  Plus,
  PlusCircle,
  Shield,
  Share2,
  Trash2,
  UploadCloud,
  User,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import toast from 'react-hot-toast'

import {
  createTenantProcedure,
  deleteTenantProcedure,
  listTenantProcedures,
  type TenantProcedure,
  updateBranding,
  updateTenantProcedure,
  uploadBrandingLogo,
} from '@/api/settings'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { TextArea } from '@/components/ui/TextArea'
import { Avatar } from '@/components/ui/Avatar'
import { Modal } from '@/components/ui/Modal'
import {
  SUPPORTED_CURRENCIES,
  SUPPORTED_LANGUAGES,
  currencyLabels,
  languageLabels,
  type SupportedLanguage,
} from '@/i18n/system'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { useTenantStore } from '@/stores/tenantStore'
import type { TenantBranding } from '@/types'
import { resolveMediaUrl } from '@/utils/mediaUrl'

const tabs = ['Identidade Visual', 'Procedimentos', 'Profissionais', 'Conteúdo'] as const

type TabType = (typeof tabs)[number]

const doctors = [
  { id: '1', name: 'Dr. Selim Aksoy', crm: 'CRM 121312', visible: true },
  { id: '2', name: 'Dra. Asli Tunc', crm: 'CRM 883123', visible: true },
  { id: '3', name: 'Dr. Deniz Kara', crm: 'CRM 448219', visible: false },
]

const previewQuickActions = [
  { key: 'schedule', icon: PlusCircle },
  { key: 'appointments', icon: CalendarDays },
  { key: 'post_op', icon: Shield },
  { key: 'contact', icon: MessageSquareText },
  { key: 'referrals', icon: Share2 },
  { key: 'records', icon: FolderOpen },
] as const
type PreviewActionKey = (typeof previewQuickActions)[number]['key']

type PreviewCopy = {
  welcomeBack: string
  greeting: string
  nextTag: string
  nextTitle: string
  quickActions: string
  sampleDate: string
  doctorName: string
  clinicName: string
  city: string
  actions: Record<PreviewActionKey, string>
  nav: {
    home: string
    schedule: string
    postOp: string
    chat: string
    profile: string
  }
}

const previewCopyByLanguage: Record<SupportedLanguage, PreviewCopy> = {
  pt: {
    welcomeBack: 'Bem-vinda de volta,',
    greeting: 'Olá, Aylin!',
    nextTag: 'Próxima consulta',
    nextTitle: 'Próxima Consulta',
    quickActions: 'Ações rápidas',
    sampleDate: '30/03/2026',
    doctorName: 'Dr. Emre Demir',
    clinicName: 'Clínica Bosphorus',
    city: 'Istambul',
    actions: {
      schedule: 'Agendar consulta',
      appointments: 'Meus agendamentos',
      post_op: 'Pós-operatório',
      contact: 'Comunicar clínica',
      referrals: 'Indicar amigos',
      records: 'Meu prontuário',
    },
    nav: {
      home: 'HOME',
      schedule: 'AGENDA',
      postOp: 'PÓS-OP',
      chat: 'CHAT',
      profile: 'PERFIL',
    },
  },
  en: {
    welcomeBack: 'Welcome back,',
    greeting: 'Hello, Aylin!',
    nextTag: 'Next appointment',
    nextTitle: 'Next Appointment',
    quickActions: 'Quick actions',
    sampleDate: '03/30/2026',
    doctorName: 'Dr. Emre Demir',
    clinicName: 'Bosphorus Clinic',
    city: 'Istanbul',
    actions: {
      schedule: 'Schedule appointment',
      appointments: 'My appointments',
      post_op: 'Post-op',
      contact: 'Contact clinic',
      referrals: 'Refer friends',
      records: 'My medical record',
    },
    nav: {
      home: 'HOME',
      schedule: 'SCHEDULE',
      postOp: 'POST-OP',
      chat: 'CHAT',
      profile: 'PROFILE',
    },
  },
  es: {
    welcomeBack: 'Bienvenida de nuevo,',
    greeting: 'Hola, Aylin!',
    nextTag: 'Próxima consulta',
    nextTitle: 'Próxima Consulta',
    quickActions: 'Acciones rápidas',
    sampleDate: '30/03/2026',
    doctorName: 'Dr. Emre Demir',
    clinicName: 'Clínica Bosphorus',
    city: 'Estambul',
    actions: {
      schedule: 'Agendar cita',
      appointments: 'Mis citas',
      post_op: 'Postoperatorio',
      contact: 'Contactar clínica',
      referrals: 'Referir amigos',
      records: 'Mi historial',
    },
    nav: {
      home: 'INICIO',
      schedule: 'AGENDA',
      postOp: 'POST-OP',
      chat: 'CHAT',
      profile: 'PERFIL',
    },
  },
  de: {
    welcomeBack: 'Willkommen zurück,',
    greeting: 'Hallo, Aylin!',
    nextTag: 'Nächster Termin',
    nextTitle: 'Nächster Termin',
    quickActions: 'Schnellaktionen',
    sampleDate: '30.03.2026',
    doctorName: 'Dr. Emre Demir',
    clinicName: 'Bosphorus Klinik',
    city: 'Istanbul',
    actions: {
      schedule: 'Termin buchen',
      appointments: 'Meine Termine',
      post_op: 'Post-OP',
      contact: 'Klinik kontaktieren',
      referrals: 'Freunde werben',
      records: 'Meine Akte',
    },
    nav: {
      home: 'HOME',
      schedule: 'TERMINE',
      postOp: 'POST-OP',
      chat: 'CHAT',
      profile: 'PROFIL',
    },
  },
  tr: {
    welcomeBack: 'Tekrar hoş geldin,',
    greeting: 'Merhaba, Aylin!',
    nextTag: 'Sıradaki randevu',
    nextTitle: 'Sıradaki Randevu',
    quickActions: 'Hızlı işlemler',
    sampleDate: '30.03.2026',
    doctorName: 'Dr. Emre Demir',
    clinicName: 'Bosphorus Klinik',
    city: 'Istanbul',
    actions: {
      schedule: 'Randevu al',
      appointments: 'Randevularım',
      post_op: 'Ameliyat sonrası',
      contact: 'Klinikle iletişim',
      referrals: 'Arkadaş davet et',
      records: 'Sağlık dosyam',
    },
    nav: {
      home: 'ANA',
      schedule: 'AJANDA',
      postOp: 'POST-OP',
      chat: 'SOHBET',
      profile: 'PROFIL',
    },
  },
  ru: {
    welcomeBack: 'С возвращением,',
    greeting: 'Привет, Aylin!',
    nextTag: 'Следующий прием',
    nextTitle: 'Следующий Прием',
    quickActions: 'Быстрые действия',
    sampleDate: '30.03.2026',
    doctorName: 'Dr. Emre Demir',
    clinicName: 'Bosphorus Clinic',
    city: 'Istanbul',
    actions: {
      schedule: 'Записаться',
      appointments: 'Мои приемы',
      post_op: 'После операции',
      contact: 'Связаться с клиникой',
      referrals: 'Пригласить друзей',
      records: 'Моя карта',
    },
    nav: {
      home: 'ГЛАВНАЯ',
      schedule: 'ГРАФИК',
      postOp: 'ПОСЛЕ ОП',
      chat: 'ЧАТ',
      profile: 'ПРОФИЛЬ',
    },
  },
}

const saasDefaultPalette = {
  primary_color: '#0D5C73',
  secondary_color: '#4A7C59',
  accent_color: '#C8992E',
}

export default function SettingsPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<TabType>('Identidade Visual')
  const { tenantConfig, setTenantConfig } = useTenantStore()
  const language = usePreferencesStore((state) => state.language)
  const currency = usePreferencesStore((state) => state.currency)
  const setLanguage = usePreferencesStore((state) => state.setLanguage)
  const setCurrency = usePreferencesStore((state) => state.setCurrency)
  const useAutomaticCurrency = usePreferencesStore((state) => state.useAutomaticCurrency)

  const [brandingDraft, setBrandingDraft] = useState<Partial<TenantBranding> | null>(null)
  const brandingForm: TenantBranding = useMemo(
    () => ({
      ...tenantConfig,
      ...(brandingDraft || {}),
    }),
    [tenantConfig, brandingDraft],
  )

  const [procedureName, setProcedureName] = useState('')
  const [procedureDescription, setProcedureDescription] = useState('')
  const [editingProcedure, setEditingProcedure] = useState<TenantProcedure | null>(null)
  const [editingProcedureName, setEditingProcedureName] = useState('')
  const [editingProcedureDescription, setEditingProcedureDescription] = useState('')
  const [logoPreview, setLogoPreview] = useState<string | null>(null)
  const [selectedLogoFile, setSelectedLogoFile] = useState<File | null>(null)
  const [isRemoveLogoModalOpen, setIsRemoveLogoModalOpen] = useState(false)
  const clinicAddresses = brandingForm.clinic_addresses || []
  const previewLogo = resolveMediaUrl(logoPreview || brandingForm.logo_url || '')
  const hasLogoConfigured = Boolean(String(previewLogo || '').trim())
  const previewCopy = previewCopyByLanguage[language]

  const saveBrandingMutation = useMutation({
    mutationFn: async (payload: TenantBranding) => {
      let mergedPayload: TenantBranding = { ...payload }
      if (selectedLogoFile) {
        const uploaded = await uploadBrandingLogo(selectedLogoFile, payload.id)
        mergedPayload = {
          ...mergedPayload,
          logo_url: uploaded.logo_url || mergedPayload.logo_url,
        }
      }
      return updateBranding(mergedPayload)
    },
    onSuccess: (data) => {
      const nextConfig = { ...brandingForm, ...data }
      setTenantConfig(nextConfig)
      setBrandingDraft(null)
      setLogoPreview(null)
      setSelectedLogoFile(null)
      toast.success('Configurações salvas com sucesso')
    },
    onError: (error) => {
      if (isAxiosError(error)) {
        const detail = (error.response?.data as { detail?: string } | undefined)?.detail
        if (detail) {
          toast.error(detail)
          return
        }
      }
      toast.error('Não foi possível salvar as configurações no backend')
    },
  })

  const proceduresQuery = useQuery({
    queryKey: ['tenant-procedures', tenantConfig.id],
    queryFn: () => listTenantProcedures(tenantConfig.id),
    enabled: Boolean(tenantConfig.id),
  })

  const createProcedureMutation = useMutation({
    mutationFn: () =>
      createTenantProcedure({
        tenant_id: tenantConfig.id,
        specialty_name: procedureName.trim(),
        description: procedureDescription.trim(),
        is_active: true,
      }),
    onSuccess: async () => {
      toast.success('Procedimento cadastrado com sucesso')
      setProcedureName('')
      setProcedureDescription('')
      await queryClient.invalidateQueries({ queryKey: ['tenant-procedures', tenantConfig.id] })
    },
    onError: () => toast.error('Não foi possível cadastrar o procedimento'),
  })

  const updateProcedureMutation = useMutation({
    mutationFn: (payload: { id: string; specialty_name?: string; description?: string; is_active?: boolean }) =>
      updateTenantProcedure(payload.id, {
        tenant_id: tenantConfig.id,
        specialty_name: payload.specialty_name,
        description: payload.description,
        is_active: payload.is_active,
      }),
    onSuccess: async () => {
      toast.success('Procedimento atualizado')
      await queryClient.invalidateQueries({ queryKey: ['tenant-procedures', tenantConfig.id] })
    },
    onError: () => toast.error('Não foi possível atualizar o procedimento'),
  })

  const deleteProcedureMutation = useMutation({
    mutationFn: (id: string) => deleteTenantProcedure(id, tenantConfig.id),
    onSuccess: async (_, deletedProcedureId) => {
      toast.success('Procedimento removido')
      if (editingProcedure?.id === deletedProcedureId) {
        setEditingProcedure(null)
        setEditingProcedureName('')
        setEditingProcedureDescription('')
      }
      await queryClient.invalidateQueries({ queryKey: ['tenant-procedures', tenantConfig.id] })
    },
    onError: () => toast.error('Não foi possível remover o procedimento'),
  })

  const mockPhoneStyle = useMemo(
    () => ({
      background: `linear-gradient(180deg, ${brandingForm.primary_color}, ${brandingForm.secondary_color})`,
    }),
    [brandingForm.primary_color, brandingForm.secondary_color],
  )

  const handleSave = () => {
    saveBrandingMutation.mutate(brandingForm)
  }

  const handleConfirmRemoveLogo = () => {
    setSelectedLogoFile(null)
    setLogoPreview(null)
    setBrandingDraft((prev) => ({
      ...prev,
      logo_url: null,
    }))
    setIsRemoveLogoModalOpen(false)
  }

  const updateClinicAddress = (index: number, value: string) => {
    setBrandingDraft((prev) => {
      const next = [...(brandingForm.clinic_addresses || [])]
      next[index] = value
      return { ...prev, clinic_addresses: next }
    })
  }

  const addClinicAddress = () => {
    setBrandingDraft((prev) => ({
      ...prev,
      clinic_addresses: [...(brandingForm.clinic_addresses || []), ''],
    }))
  }

  const removeClinicAddress = (index: number) => {
    setBrandingDraft((prev) => ({
      ...prev,
      clinic_addresses: (brandingForm.clinic_addresses || []).filter((_, itemIndex) => itemIndex !== index),
    }))
  }

  const handleSaveProcedure = () => {
    const trimmedName = procedureName.trim()
    if (!trimmedName) {
      toast.error('Informe o nome do procedimento')
      return
    }

    createProcedureMutation.mutate()
  }

  const openProcedureEditModal = (procedure: TenantProcedure) => {
    setEditingProcedure(procedure)
    setEditingProcedureName(procedure.specialty_name)
    setEditingProcedureDescription(procedure.description || '')
  }

  const closeProcedureEditModal = () => {
    setEditingProcedure(null)
    setEditingProcedureName('')
    setEditingProcedureDescription('')
  }

  const handleSaveProcedureEdit = () => {
    if (!editingProcedure) return
    const trimmedName = editingProcedureName.trim()
    if (!trimmedName) {
      toast.error('Informe o nome do procedimento')
      return
    }

    updateProcedureMutation.mutate(
      {
        id: editingProcedure.id,
        specialty_name: trimmedName,
        description: editingProcedureDescription.trim(),
      },
      {
        onSuccess: () => {
          closeProcedureEditModal()
        },
      },
    )
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title="Configurações do Aplicativo"
        subtitle="Personalize a experiência do paciente no ambiente white-label da clínica."
      />

      <Card>
        <div className="flex flex-wrap gap-2">
          {tabs.map((tab) => (
            <button
              key={tab}
              type="button"
              onClick={() => setActiveTab(tab)}
              className={`rounded-lg px-4 py-2 text-sm font-medium ${
                activeTab === tab ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              {tab}
            </button>
          ))}
        </div>
      </Card>

      {activeTab === 'Identidade Visual' ? (
        <div className="grid gap-4 lg:grid-cols-12">
          <div className="space-y-4 lg:col-span-8">
            <Card>
              <h2 className="section-heading mb-4">Paleta de Cores</h2>
              <div className="mb-4 rounded-lg border border-slate-100 bg-slate-50 p-3">
                <p className="text-sm font-semibold text-night">Paleta padrão do SaaS</p>
                <p className="caption mb-3">As três cores padrão já vêm com a identidade principal da plataforma.</p>
                <div className="flex items-center gap-2">
                  {[saasDefaultPalette.primary_color, saasDefaultPalette.secondary_color, saasDefaultPalette.accent_color].map(
                    (color) => (
                      <span
                        key={color}
                        className="h-7 w-7 rounded-md border border-slate-200"
                        style={{ backgroundColor: color }}
                      />
                    ),
                  )}
                </div>
                <Button
                  className="mt-3"
                  variant="secondary"
                  onClick={() =>
                    setBrandingDraft((prev) => ({
                      ...prev,
                      ...saasDefaultPalette,
                    }))
                  }
                >
                  Usar paleta SaaS
                </Button>
              </div>

              {[
                {
                  key: 'primary_color' as const,
                  label: 'Cor Primária',
                  description: 'Usada em cabeçalhos e botões principais',
                },
                {
                  key: 'secondary_color' as const,
                  label: 'Cor Secundária',
                  description: 'Elementos de apoio e badges',
                },
                {
                  key: 'accent_color' as const,
                  label: 'Cor de Destaque',
                  description: 'Call-to-actions e alertas',
                },
              ].map((item) => (
                <div key={item.key} className="mb-4 grid items-center gap-3 md:grid-cols-[1fr_auto_auto]">
                  <div>
                    <p className="text-sm font-semibold text-night">{item.label}</p>
                    <p className="caption">{item.description}</p>
                  </div>
                  <input
                    type="text"
                    value={brandingForm[item.key]}
                    onChange={(event) =>
                      setBrandingDraft((prev) => ({
                        ...prev,
                        [item.key]: event.target.value,
                      }))
                    }
                    className="h-10 w-28 rounded-lg border border-slate-200 px-3 text-sm"
                  />
                  <label
                    className="h-10 w-10 cursor-pointer rounded-lg border border-slate-200"
                    style={{ backgroundColor: brandingForm[item.key] }}
                  >
                    <input
                      type="color"
                      value={brandingForm[item.key]}
                      onChange={(event) =>
                        setBrandingDraft((prev) => ({
                          ...prev,
                          [item.key]: event.target.value,
                        }))
                      }
                      className="sr-only"
                    />
                  </label>
                </div>
              ))}
            </Card>

            <Card>
              <h2 className="section-heading mb-3">Idioma e Moeda do Painel</h2>
              <p className="caption mb-3">
                Por padrão o sistema detecta o idioma do navegador. Você pode sobrescrever manualmente abaixo.
              </p>
              <div className="grid gap-3 md:grid-cols-2">
                <div>
                  <p className="mb-1 text-xs font-semibold text-slate-600">Idioma</p>
                  <select
                    value={language}
                    onChange={(event) => setLanguage(event.target.value as typeof language)}
                    className="h-10 w-full rounded-lg border border-slate-200 px-3 text-sm"
                  >
                    {SUPPORTED_LANGUAGES.map((value) => (
                      <option key={value} value={value}>
                        {languageLabels[value]}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <p className="mb-1 text-xs font-semibold text-slate-600">Moeda</p>
                  <select
                    value={currency}
                    onChange={(event) => setCurrency(event.target.value as typeof currency)}
                    className="h-10 w-full rounded-lg border border-slate-200 px-3 text-sm"
                  >
                    {SUPPORTED_CURRENCIES.map((value) => (
                      <option key={value} value={value}>
                        {currencyLabels[value]}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
              <Button className="mt-3" variant="secondary" onClick={useAutomaticCurrency}>
                Reaplicar moeda automática por idioma
              </Button>
            </Card>

            <Card>
              <h2 className="section-heading mb-3">Dados da Clínica</h2>
              <div className="space-y-4">
                <div>
                  <p className="mb-1 text-xs font-semibold text-slate-600">Nome da clínica</p>
                  <Input
                    value={brandingForm.name}
                    onChange={(event) =>
                      setBrandingDraft((prev) => ({
                        ...prev,
                        name: event.target.value,
                      }))
                    }
                    placeholder="Ex: Clínica Estética Aurora"
                  />
                </div>

                <div>
                  <div className="mb-2 flex items-center justify-between">
                    <p className="text-xs font-semibold text-slate-600">Endereços / filiais</p>
                    <Button type="button" variant="secondary" onClick={addClinicAddress}>
                      <Plus className="h-4 w-4" />
                      Adicionar endereço
                    </Button>
                  </div>

                  <div className="space-y-2">
                    {clinicAddresses.map((address, index) => (
                      <div
                        key={`${index}-${address}`}
                        className="grid items-center gap-2 md:grid-cols-[auto_1fr_auto]"
                      >
                        <span className="inline-flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 text-slate-600">
                          <MapPin className="h-4 w-4" />
                        </span>
                        <Input
                          value={address}
                          placeholder={`Endereço ${index + 1}`}
                          onChange={(event) => updateClinicAddress(index, event.target.value)}
                        />
                        <Button type="button" variant="secondary" onClick={() => removeClinicAddress(index)}>
                          <Trash2 className="h-4 w-4" />
                          Remover
                        </Button>
                      </div>
                    ))}

                    {!clinicAddresses.length ? (
                      <div className="rounded-lg border border-dashed border-slate-200 bg-slate-50 p-3 text-sm text-slate-500">
                        Cadastre ao menos um endereço para permitir seleção de filial no agendamento do app.
                      </div>
                    ) : null}
                  </div>
                </div>
              </div>
            </Card>

            <Card>
              <h2 className="section-heading mb-3">Prompt do Chat com IA</h2>
              <p className="caption mb-3">
                Esse prompt orienta o assistente virtual do app do paciente. O contexto usado sempre será apenas do
                próprio paciente autenticado.
              </p>
              <TextArea
                rows={8}
                value={brandingForm.ai_assistant_prompt || ''}
                onChange={(event) =>
                  setBrandingDraft((prev) => ({
                    ...prev,
                    ai_assistant_prompt: event.target.value,
                  }))
                }
                placeholder="Ex: Você é a assistente virtual da clínica..."
              />
            </Card>

            <Card>
              <div className="mb-3 flex items-center justify-between gap-2">
                <h2 className="section-heading">Logo da Clínica</h2>
                {hasLogoConfigured ? (
                  <Button type="button" variant="danger" onClick={() => setIsRemoveLogoModalOpen(true)}>
                    <Trash2 className="h-4 w-4" />
                    Remover logo atual
                  </Button>
                ) : null}
              </div>
              <label className="flex cursor-pointer flex-col items-center justify-center rounded-xl border-2 border-dashed border-slate-300 bg-slate-50 p-6 text-center">
                <UploadCloud className="h-6 w-6 text-slate-500" />
                <p className="mt-2 text-sm font-medium text-slate-600">Arraste PNG/SVG ou clique para upload</p>
                <p className="caption">Recomendado: 512x512px</p>
                <input
                  type="file"
                  accept="image/png,image/svg+xml,image/jpeg"
                className="sr-only"
                onChange={(event) => {
                  const file = event.target.files?.[0]
                  if (!file) return
                  const url = URL.createObjectURL(file)
                  setSelectedLogoFile(file)
                  setLogoPreview(url)
                  setBrandingDraft((prev) => ({ ...prev, logo_url: url }))
                }}
              />
              </label>

              {hasLogoConfigured ? (
                <div className="mt-4 flex items-center gap-3 rounded-lg bg-tealIce p-3">
                  <img src={previewLogo} alt="Logo da clínica" className="h-12 w-auto" />
                  <p className="text-sm text-slate-600">
                    {selectedLogoFile ? 'Preview do novo logo' : 'Logo atual da clínica'}
                  </p>
                </div>
              ) : null}
            </Card>

            <Modal
              isOpen={isRemoveLogoModalOpen}
              onClose={() => setIsRemoveLogoModalOpen(false)}
              title="Remover logo da clínica?"
            >
              <p className="body-copy">
                Isso vai remover a logo atual. Você poderá salvar sem logo ou enviar uma nova imagem depois.
              </p>
              <div className="mt-4 flex justify-end gap-2">
                <Button type="button" variant="secondary" onClick={() => setIsRemoveLogoModalOpen(false)}>
                  Manter logo
                </Button>
                <Button type="button" variant="danger" onClick={handleConfirmRemoveLogo}>
                  Remover logo
                </Button>
              </div>
            </Modal>

            <div className="flex justify-end gap-2">
              <Button
                variant="secondary"
                onClick={() => {
                  setBrandingDraft(null)
                  setLogoPreview(null)
                  setSelectedLogoFile(null)
                }}
              >
                Descartar
              </Button>
              <Button onClick={handleSave} disabled={saveBrandingMutation.isPending}>
                {saveBrandingMutation.isPending ? 'Salvando...' : 'Salvar Alterações'}
              </Button>
            </div>
          </div>

          <Card className="lg:col-span-4">
            <p className="overline mb-3">Preview app do paciente</p>
            <div className="mx-auto w-full max-w-[256px] rounded-[34px] border-[8px] border-[#0f172a] bg-[#0f172a] p-[6px] shadow-[0_20px_35px_-20px_rgba(15,23,42,0.9)]">
              <div className="relative overflow-hidden rounded-[26px] bg-[#edf2f6]">
                <div className="absolute left-1/2 top-0 h-5 w-28 -translate-x-1/2 rounded-b-2xl bg-[#0f172a]" />
                <div className="space-y-3 px-3 pb-3 pt-7">
                  <div className="flex items-center justify-between text-[10px] font-semibold text-slate-700">
                    <span>21:46</span>
                    <span className="tracking-[0.2em] text-slate-500">•••</span>
                  </div>

                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2.5">
                      <span
                        className="inline-flex h-8 w-8 items-center justify-center rounded-full text-xs font-bold"
                        style={{
                          backgroundColor: `${brandingForm.primary_color}20`,
                          color: brandingForm.primary_color,
                        }}
                      >
                        P
                      </span>
                      <div>
                        <p className="text-[10px] text-slate-600">{previewCopy.welcomeBack}</p>
                        <p className="text-xl font-bold leading-none text-slate-900">{previewCopy.greeting}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <span className="inline-flex h-7 w-7 items-center justify-center rounded-lg bg-white ring-1 ring-slate-200">
                        {previewLogo ? (
                          <img src={previewLogo} alt="Logo da clínica" className="h-4 w-4 object-contain" />
                        ) : (
                          <Building2 className="h-3.5 w-3.5 text-slate-500" />
                        )}
                      </span>
                      <Bell className="h-4 w-4 text-slate-600" />
                    </div>
                  </div>

                  <div className="relative overflow-hidden rounded-2xl px-3 pb-3 pt-2.5 text-white" style={mockPhoneStyle}>
                    <div
                      className="absolute -right-5 top-0 h-full w-14 rounded-l-xl opacity-70"
                      style={{ backgroundColor: `${brandingForm.secondary_color}B3` }}
                    />
                    <p className="inline-flex rounded-full bg-white/20 px-2 py-0.5 text-[8px] font-semibold uppercase tracking-wide">
                      {previewCopy.nextTag}
                    </p>
                    <p className="mt-1.5 text-[26px] font-semibold leading-none">{previewCopy.nextTitle}</p>
                    <p className="mt-1 text-xs text-white/85">
                      {previewCopy.sampleDate} • 11:00 • {previewCopy.doctorName}
                    </p>
                    <p className="mt-1 truncate text-[11px] font-medium text-white/90">{previewCopy.clinicName}</p>
                    <div className="mt-2 flex items-center gap-1.5 text-xs text-white/90">
                      <Building2 className="h-3.5 w-3.5" />
                      <span className="font-medium">{previewCopy.city}</span>
                    </div>
                  </div>

                  <div>
                    <p className="mb-2 text-[9px] font-semibold uppercase tracking-[0.16em] text-slate-500">
                      {previewCopy.quickActions}
                    </p>
                    <div className="grid grid-cols-3 gap-2">
                      {previewQuickActions.map((action) => (
                        <div
                          key={action.key}
                          className="flex h-[84px] flex-col rounded-2xl bg-white p-2 ring-1 ring-slate-200"
                        >
                          <span
                            className="inline-flex h-7 w-7 items-center justify-center rounded-lg"
                            style={{
                              backgroundColor: `${brandingForm.primary_color}18`,
                              color: brandingForm.primary_color,
                            }}
                          >
                            <action.icon className="h-3.5 w-3.5" />
                          </span>
                          <p className="mt-1.5 text-[9px] font-medium leading-[1.15] text-slate-700 break-words">
                            {previewCopy.actions[action.key]}
                          </p>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                <div className="border-t border-slate-200 bg-white px-2 py-2">
                  <div className="grid grid-cols-5 text-center text-[9px] font-semibold text-slate-500">
                    {[
                      { label: previewCopy.nav.home, icon: Home, active: true },
                      { label: previewCopy.nav.schedule, icon: CalendarDays },
                      { label: previewCopy.nav.postOp, icon: Shield },
                      { label: previewCopy.nav.chat, icon: MessageSquareText },
                      { label: previewCopy.nav.profile, icon: User },
                    ].map((item) => (
                      <div key={item.label} className="flex flex-col items-center gap-0.5">
                        <span
                          className="inline-flex h-6 w-8 items-center justify-center rounded-full"
                          style={item.active ? { backgroundColor: `${brandingForm.primary_color}20` } : undefined}
                        >
                          <item.icon
                            className="h-3.5 w-3.5"
                            style={item.active ? { color: brandingForm.primary_color } : undefined}
                          />
                        </span>
                        <span className="leading-none" style={item.active ? { color: brandingForm.primary_color } : undefined}>
                          {item.label}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </Card>
        </div>
      ) : null}

      {activeTab === 'Procedimentos' ? (
        <Card>
          <h2 className="section-heading mb-4">Procedimentos</h2>
          <p className="caption mb-4">
            Cadastre os procedimentos da clínica. Eles serão usados no agendamento e no histórico do prontuário.
          </p>
          <div className="mb-4 grid gap-3 rounded-lg border border-slate-100 bg-slate-50 p-3 md:grid-cols-2">
            <Input
              placeholder="Nome do procedimento"
              value={procedureName}
              onChange={(event) => setProcedureName(event.target.value)}
            />
            <Input
              placeholder="Descrição breve (opcional)"
              value={procedureDescription}
              onChange={(event) => setProcedureDescription(event.target.value)}
            />
            <div className="md:col-span-2 flex flex-wrap justify-end gap-2">
              <Button
                type="button"
                onClick={handleSaveProcedure}
                disabled={createProcedureMutation.isPending || updateProcedureMutation.isPending}
              >
                {createProcedureMutation.isPending ? 'Cadastrando...' : 'Cadastrar procedimento'}
              </Button>
            </div>
          </div>
          <div className="space-y-3">
            {proceduresQuery.isLoading ? <p className="text-sm text-slate-500">Carregando procedimentos...</p> : null}
            {proceduresQuery.isError ? (
              <p className="text-sm text-danger">Não foi possível carregar os procedimentos.</p>
            ) : null}
            {(proceduresQuery.data || []).map((procedure) => (
              <div key={procedure.id} className="rounded-lg border border-slate-100 p-3">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p className="text-sm font-semibold text-night">{procedure.specialty_name}</p>
                    <p className="caption">
                      {procedure.description || 'Sem descrição'}
                    </p>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <button
                      type="button"
                      onClick={() =>
                        updateProcedureMutation.mutate({
                          id: procedure.id,
                          is_active: !procedure.is_active,
                        })
                      }
                      className={`relative inline-flex h-6 w-11 items-center rounded-full transition ${
                        procedure.is_active ? 'bg-secondary' : 'bg-slate-300'
                      }`}
                    >
                      <span
                        className={`inline-block h-4 w-4 transform rounded-full bg-white transition ${
                          procedure.is_active ? 'translate-x-6' : 'translate-x-1'
                        }`}
                      />
                    </button>
                    <Button
                      type="button"
                      variant="secondary"
                      onClick={() => openProcedureEditModal(procedure)}
                    >
                      Editar
                    </Button>
                    <Button
                      type="button"
                      variant="danger"
                      onClick={() => deleteProcedureMutation.mutate(procedure.id)}
                      disabled={deleteProcedureMutation.isPending}
                    >
                      Excluir
                    </Button>
                  </div>
                </div>
              </div>
            ))}
            {!proceduresQuery.isLoading && (proceduresQuery.data || []).length === 0 ? (
              <p className="rounded-lg border border-dashed border-slate-200 bg-slate-50 p-3 text-sm text-slate-500">
                Nenhum procedimento cadastrado ainda.
              </p>
            ) : null}
          </div>

          <Modal
            isOpen={Boolean(editingProcedure)}
            onClose={closeProcedureEditModal}
            title="Editar procedimento"
            className="max-w-2xl"
          >
            <div className="space-y-4">
              <div className="rounded-xl border border-slate-200 bg-slate-50 p-4">
                <p className="text-sm font-semibold text-night">{editingProcedure?.specialty_name || 'Procedimento'}</p>
                <p className="caption mt-1">Atualize os dados desse procedimento para refletir no app e no painel.</p>
              </div>

              <div className="space-y-3">
                <div>
                  <p className="mb-1 text-xs font-semibold text-slate-600">Nome do procedimento</p>
                  <Input
                    placeholder="Ex: Rinoplastia estruturada"
                    value={editingProcedureName}
                    onChange={(event) => setEditingProcedureName(event.target.value)}
                  />
                </div>
                <div>
                  <p className="mb-1 text-xs font-semibold text-slate-600">Descrição (opcional)</p>
                  <TextArea
                    rows={4}
                    placeholder="Descreva brevemente o procedimento para orientar o paciente."
                    value={editingProcedureDescription}
                    onChange={(event) => setEditingProcedureDescription(event.target.value)}
                  />
                </div>
              </div>

              <div className="flex justify-end gap-2">
                <Button type="button" variant="secondary" onClick={closeProcedureEditModal}>
                  Cancelar
                </Button>
                <Button type="button" onClick={handleSaveProcedureEdit} disabled={updateProcedureMutation.isPending}>
                  {updateProcedureMutation.isPending ? 'Salvando...' : 'Salvar alterações'}
                </Button>
              </div>
            </div>
          </Modal>
        </Card>
      ) : null}

      {activeTab === 'Profissionais' ? (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {doctors.map((doctor) => (
            <Card key={doctor.id}>
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-center gap-2">
                  <Avatar name={doctor.name} className="h-11 w-11" />
                  <div>
                    <p className="text-sm font-semibold text-night">{doctor.name}</p>
                    <p className="caption">{doctor.crm}</p>
                  </div>
                </div>
                <Badge status={doctor.visible ? 'active' : 'inactive'}>
                  {doctor.visible ? 'VISÍVEL' : 'OCULTO'}
                </Badge>
              </div>
            </Card>
          ))}
        </div>
      ) : null}

      {activeTab === 'Conteúdo' ? (
        <Card>
          <h2 className="section-heading">Conteúdo do App</h2>
          <p className="body-copy mt-2">
            Módulo preparado para configurar protocolos, textos de onboarding e campanhas no app do paciente.
          </p>
          <div className="mt-4 rounded-lg border border-slate-100 bg-slate-50 p-4">
            <p className="text-sm text-slate-600">
              Aqui você poderá definir banners, mensagens de boas-vindas e conteúdo educativo por especialidade.
            </p>
            <Button
              className="mt-3"
              variant="secondary"
              onClick={() => toast('Editor de conteúdo avançado será disponibilizado em breve.')}
            >
              <Camera className="h-4 w-4" />
              Editar Conteúdo
            </Button>
          </div>
        </Card>
      ) : null}
    </div>
  )
}
