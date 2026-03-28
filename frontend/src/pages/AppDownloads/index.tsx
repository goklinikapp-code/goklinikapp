import { useQuery } from '@tanstack/react-query'
import { Copy, ExternalLink, QrCode, Smartphone } from 'lucide-react'
import QRCode from 'qrcode'
import toast from 'react-hot-toast'

import { getClinicReferralLink } from '@/api/referrals'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import appStoreIosIcon from '@/assets/app-store-ios.png'
import googlePlayIcon from '@/assets/google-play-store.png'

type LinkCard = {
  id: string
  audience: 'patient' | 'doctor'
  platform: 'ios' | 'android'
  title: string
  subtitle: string
  placeholder: string
}

const links: LinkCard[] = [
  {
    id: 'patient-ios',
    audience: 'patient',
    platform: 'ios',
    title: 'App do Paciente',
    subtitle: 'iOS / App Store',
    placeholder: 'Link App Store (em breve)',
  },
  {
    id: 'patient-android',
    audience: 'patient',
    platform: 'android',
    title: 'App do Paciente',
    subtitle: 'Android / Google Play',
    placeholder: 'Link Google Play (em breve)',
  },
  {
    id: 'doctor-ios',
    audience: 'doctor',
    platform: 'ios',
    title: 'App do Médico',
    subtitle: 'iOS / App Store',
    placeholder: 'Link App Store (em breve)',
  },
  {
    id: 'doctor-android',
    audience: 'doctor',
    platform: 'android',
    title: 'App do Médico',
    subtitle: 'Android / Google Play',
    placeholder: 'Link Google Play (em breve)',
  },
]

export default function AppDownloadsPage() {
  const { data: clinicReferral, isLoading: clinicReferralLoading } = useQuery({
    queryKey: ['app-downloads-referral-link'],
    queryFn: getClinicReferralLink,
  })

  const clinicReferralLink = clinicReferral?.referral_link || ''
  const clinicReferralCode = clinicReferral?.referral_code || ''

  const handleCopy = () => {
    toast('Os links ainda não foram configurados.')
  }

  const handleOpen = () => {
    toast('Os links ainda não foram configurados.')
  }

  const handleCopyReferralLink = async () => {
    if (!clinicReferralLink) {
      toast('O link de indicação ainda não está disponível.')
      return
    }
    try {
      await navigator.clipboard.writeText(clinicReferralLink)
      toast.success('Link de indicação copiado.')
    } catch {
      toast.error('Não foi possível copiar o link de indicação.')
    }
  }

  const handleCopyReferralCode = async () => {
    if (!clinicReferralCode) {
      toast('Código de indicação ainda não disponível.')
      return
    }
    try {
      await navigator.clipboard.writeText(clinicReferralCode)
      toast.success('Código de indicação copiado.')
    } catch {
      toast.error('Não foi possível copiar o código de indicação.')
    }
  }

  const handleDownloadReferralQr = async () => {
    if (!clinicReferralLink) {
      toast('O link de indicação ainda não está disponível.')
      return
    }

    try {
      const dataUrl = await QRCode.toDataURL(clinicReferralLink, {
        width: 1024,
        margin: 2,
      })
      const anchor = document.createElement('a')
      anchor.href = dataUrl
      anchor.download = `qrcode-indicacao-${(clinicReferralCode || 'goklinik').toLowerCase()}.png`
      anchor.click()
      toast.success('QR Code gerado com sucesso.')
    } catch {
      toast.error('Não foi possível gerar o QR Code.')
    }
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title="Aplicativo"
        subtitle="Área pré-pronta para publicar os links de download dos apps do paciente e do médico."
      />

      <div className="grid gap-4 md:grid-cols-2">
        {links.map((linkCard) => {
          const isIos = linkCard.platform === 'ios'
          const isPatientApp = linkCard.audience === 'patient'
          const storeIcon = isIos ? appStoreIosIcon : googlePlayIcon
          return (
            <Card key={linkCard.id}>
              <div className="mb-4 flex items-start justify-between gap-3">
                <div className="flex items-center gap-2">
                  <div className="h-8 w-8 overflow-hidden rounded-lg bg-primary/10 text-primary">
                    <img
                      src={storeIcon}
                      alt={isIos ? 'Apple App Store' : 'Google Play Store'}
                      className="h-full w-full object-cover"
                    />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-night">{linkCard.title}</p>
                    <p className="caption">{linkCard.subtitle}</p>
                  </div>
                </div>
                <Badge className="bg-slate-100 text-slate-700">Não publicado</Badge>
              </div>

              {!isPatientApp ? (
                <>
                  <div className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-500">
                    {linkCard.placeholder}
                  </div>

                  <div className="mt-4 flex flex-wrap gap-2">
                    <Button type="button" size="sm" variant="secondary" onClick={handleCopy}>
                      <Copy className="h-3.5 w-3.5" />
                      Copiar
                    </Button>
                    <Button type="button" size="sm" variant="secondary" onClick={handleOpen}>
                      <ExternalLink className="h-3.5 w-3.5" />
                      Abrir
                    </Button>
                  </div>

                  <div className="mt-4 flex items-center gap-2 rounded-lg bg-mist px-3 py-2">
                    <div className="rounded-md bg-white p-1.5 text-primary">
                      <Smartphone className="h-3.5 w-3.5" />
                    </div>
                    <p className="caption">
                      Este bloco está pronto para receber o link oficial de{' '}
                      {isIos ? 'App Store' : 'Google Play'}.
                    </p>
                  </div>
                </>
              ) : null}

              {isPatientApp ? (
                <div className="rounded-lg border border-primary/20 bg-primary/5 p-3">
                  <p className="text-sm font-semibold text-night">Link de indicação do app do paciente</p>
                  <p className="caption mt-1">
                    Compartilhe este link com código para rastrear indicações de novos pacientes.
                  </p>
                  <div className="mt-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm text-slate-600">
                    {clinicReferralLoading
                      ? 'Gerando link de indicação...'
                      : clinicReferralLink || 'Link de indicação indisponível'}
                  </div>
                  <p className="mt-2 text-xs text-slate-600">
                    Código: <strong>{clinicReferralCode || '-'}</strong>
                  </p>
                  <div className="mt-2 flex flex-wrap gap-2">
                    <Button
                      type="button"
                      size="sm"
                      variant="secondary"
                      onClick={handleCopyReferralLink}
                      disabled={!clinicReferralLink || clinicReferralLoading}
                    >
                      <Copy className="h-3.5 w-3.5" />
                      Copiar link
                    </Button>
                    <Button
                      type="button"
                      size="sm"
                      variant="secondary"
                      onClick={handleCopyReferralCode}
                      disabled={!clinicReferralCode || clinicReferralLoading}
                    >
                      <Copy className="h-3.5 w-3.5" />
                      Copiar código
                    </Button>
                    <Button
                      type="button"
                      size="sm"
                      variant="secondary"
                      onClick={handleDownloadReferralQr}
                      disabled={!clinicReferralLink || clinicReferralLoading}
                    >
                      <QrCode className="h-3.5 w-3.5" />
                      Baixar QR Code
                    </Button>
                  </div>
                </div>
              ) : null}
            </Card>
          )
        })}
      </div>
    </div>
  )
}
